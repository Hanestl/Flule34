import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/database/app_database.dart';
import '../../core/models/translation_models.dart';
import '../../core/models/video_models.dart';
import '../../core/services/predictive_prefetch_service.dart';
import '../../core/services/translation_service.dart';
import '../../shared/editable_translation.dart';
import '../../shared/localized_translation_text.dart';
import '../../shared/video_card.dart' show formatCount;
import '../../shared/video_feed.dart';
import 'data/search_history_repository.dart';
import 'video_filter_sheet.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.api,
    required this.historyRepository,
    required this.prefetchService,
    required this.translationService,
  });

  final Rule34VideoApi api;
  final SearchHistoryRepository historyRepository;
  final PredictivePrefetchService prefetchService;
  final TranslationService translationService;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  late Stream<List<SearchHistory>> _historyStream;
  late Future<List<ContentCollectionItem>> _popularTags;
  String? _historyUserId;

  Map<SearchSuggestionKind, List<SearchSuggestion>> _suggestions = const {};
  List<TranslatedTagSuggestion> _localTagSuggestions = const [];
  List<TranslatedTitleSuggestion> _localTitleSuggestions = const [];
  SearchFilters _filters = const SearchFilters();
  SearchResultScope _scope = SearchResultScope.overview;
  String _activeQuery = '';
  String? _suggestionError;
  var _suggestionLoading = false;
  var _showAutocomplete = false;
  var _searchRevision = 0;
  var _suggestionGeneration = 0;
  var _showResults = false;

  @override
  void initState() {
    super.initState();
    _syncHistoryStream();
    _popularTags = _loadPopularTags();
    widget.api.sessionStore.addListener(_onSessionChanged);
    widget.translationService.addListener(_onTranslationChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.translationService != widget.translationService) {
      oldWidget.translationService.removeListener(_onTranslationChanged);
      widget.translationService.addListener(_onTranslationChanged);
    }
  }

  Future<List<ContentCollectionItem>> _loadPopularTags() {
    return widget.prefetchService
        .runForeground(
          PredictivePrefetchKey.feed('search-popular-tags', 1),
          () => widget.api.loadDiscoveryDirectory(
            const DiscoveryDirectorySpec(
              title: '热门标签',
              path: '/tags/',
              kind: DiscoveryKind.tag,
            ),
          ),
        )
        .then((items) => items.take(12).toList(growable: false));
  }

  void _syncHistoryStream() {
    _historyUserId = widget.api.sessionStore.currentUserId;
    _historyStream = widget.historyRepository.watch();
  }

  void _onSessionChanged() {
    final nextUserId = widget.api.sessionStore.currentUserId;
    if (!mounted || nextUserId == _historyUserId) {
      return;
    }
    setState(_syncHistoryStream);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.api.sessionStore.removeListener(_onSessionChanged);
    widget.translationService.removeListener(_onTranslationChanged);
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onTranslationChanged() {
    if (mounted) {
      final query = _controller.text.trim();
      setState(() {
        if (_containsCjk(query)) {
          _localTagSuggestions = widget.translationService.searchTagAliases(
            query,
          );
          _localTitleSuggestions = widget.translationService
              .searchTitleTranslations(query);
        }
      });
    }
  }

  void _onFocusChanged() {
    if (!mounted) {
      return;
    }
    setState(() => _showAutocomplete = _focusNode.hasFocus);
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (_containsCjk(query)) {
      _suggestionGeneration += 1;
      setState(() {
        _localTagSuggestions = widget.translationService.searchTagAliases(
          query,
        );
        _localTitleSuggestions = widget.translationService
            .searchTitleTranslations(query);
        _suggestions = const {};
        _suggestionError = null;
        _suggestionLoading = false;
      });
      return;
    }
    if (query.length < 2) {
      _suggestionGeneration += 1;
      setState(() {
        _localTagSuggestions = const [];
        _localTitleSuggestions = const [];
        _suggestions = const {};
        _suggestionError = null;
        _suggestionLoading = false;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadSuggestions(query),
    );
  }

  Future<void> _loadSuggestions(String query) async {
    final generation = ++_suggestionGeneration;
    if (mounted) {
      setState(() {
        _localTagSuggestions = const [];
        _localTitleSuggestions = const [];
        _suggestionLoading = true;
        _suggestionError = null;
      });
    }
    var failed = false;
    final values = await widget.prefetchService.runForeground(
      'search:suggestions:$query',
      () => Future.wait(
        SearchSuggestionKind.values.map((kind) async {
          try {
            return MapEntry(
              kind,
              await widget.api.searchSuggestions(query, kind),
            );
          } catch (_) {
            failed = true;
            return MapEntry(kind, const <SearchSuggestion>[]);
          }
        }),
      ),
    );
    if (!mounted || generation != _suggestionGeneration) {
      return;
    }
    setState(() {
      _suggestions = Map.fromEntries(values);
      _suggestionLoading = false;
      _suggestionError = failed ? '部分自动补全暂时不可用。' : null;
    });
  }

  Future<void> _search([String? query]) async {
    final text = (query ?? _controller.text).trim();
    if (text.isEmpty && _filters.isEmpty) {
      return;
    }
    if (_containsCjk(text)) {
      setState(() {
        _localTagSuggestions = widget.translationService.searchTagAliases(
          text,
          limit: 20,
        );
        _localTitleSuggestions = widget.translationService
            .searchTitleTranslations(text, limit: 20);
        _suggestions = const {};
        _suggestionError = null;
      });
    }
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _focusNode.unfocus();
    setState(() {
      _activeQuery = text;
      _scope = SearchResultScope.overview;
      _searchRevision += 1;
      _showResults = true;
    });
    if (text.isNotEmpty) {
      unawaited(_recordHistory(text));
      if (!_containsCjk(text)) unawaited(_loadSuggestions(text));
    }
  }

  Future<void> _recordHistory(String text) async {
    try {
      await widget.historyRepository.record(text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('搜索成功，但历史记录保存失败。')));
      }
    }
  }

  void _applyFilters(SearchFilters filters) {
    setState(() {
      _filters = filters;
      _showResults = _activeQuery.isNotEmpty || !filters.isEmpty;
      _searchRevision += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
        actions: [
          IconButton(
            tooltip: '筛选与排序',
            onPressed: _openFilterSheet,
            icon: Badge(
              isLabelVisible: !_filters.isEmpty,
              child: const Icon(Icons.tune),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchField(),
          if (_showAutocomplete &&
              _minimumSuggestionLengthMet(_controller.text.trim()))
            _buildAutocomplete(),
          if (_showResults) ...[_buildFilterChips(), _buildScopeSelector()],
          Expanded(child: _showResults ? _buildResults() : _buildLanding()),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        onChanged: _onChanged,
        onSubmitted: (_) => _search(),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: '搜索视频、标签、分类或艺术家',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_controller.text.isNotEmpty)
                IconButton(
                  tooltip: '清空',
                  onPressed: () {
                    _controller.clear();
                    _onChanged('');
                    _focusNode.requestFocus();
                    setState(() {});
                  },
                  icon: const Icon(Icons.clear),
                ),
              IconButton(
                tooltip: '搜索',
                onPressed: _search,
                icon: const Icon(Icons.arrow_forward),
              ),
            ],
          ),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildAutocomplete() {
    if (_suggestionLoading &&
        _suggestions.isEmpty &&
        _localTagSuggestions.isEmpty &&
        _localTitleSuggestions.isEmpty) {
      return const LinearProgressIndicator();
    }
    final hasItems =
        _localTagSuggestions.isNotEmpty ||
        _localTitleSuggestions.isNotEmpty ||
        _suggestions.values.any((items) => items.isNotEmpty);
    if (!hasItems && _suggestionError == null) {
      if (_containsCjk(_controller.text)) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('没有找到对应的中文标签或已学习标题。'),
        );
      }
      return const SizedBox.shrink();
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          children: [
            if (_suggestionError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _suggestionError!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (_localTagSuggestions.isNotEmpty)
              _LocalTagSuggestionList(
                suggestions: _localTagSuggestions,
                onSelected: _openLocalTagSuggestion,
              ),
            if (_localTitleSuggestions.isNotEmpty)
              _LocalTitleSuggestionList(
                suggestions: _localTitleSuggestions,
                onSelected: _openLocalTitleSuggestion,
              ),
            for (final kind in SearchSuggestionKind.values)
              if ((_suggestions[kind] ?? const []).isNotEmpty)
                _SuggestionRow(
                  kind: kind,
                  suggestions: _suggestions[kind]!.take(6).toList(),
                  translationService: widget.translationService,
                  onSelected: _openSuggestionCollection,
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final chips = <Widget>[];
    if (_filters.sort != VideoSort.relevance) {
      chips.add(
        InputChip(
          label: Text('排序：${_filters.sort.label}'),
          onDeleted: () =>
              _applyFilters(_filters.copyWith(sort: VideoSort.relevance)),
        ),
      );
    }
    if (_filters.orientation != ContentOrientation.all) {
      chips.add(
        InputChip(
          label: Text('取向：${_filters.orientation.label}'),
          onDeleted: () => _applyFilters(
            _filters.copyWith(orientation: ContentOrientation.all),
          ),
        ),
      );
    }
    if (_filters.uploadPeriod != UploadPeriod.anytime) {
      chips.add(
        InputChip(
          label: Text(_filters.uploadPeriod.label),
          onDeleted: () => _applyFilters(
            _filters.copyWith(uploadPeriod: UploadPeriod.anytime),
          ),
        ),
      );
    }
    if (_filters.duration != VideoDurationPreset.any) {
      chips.add(
        InputChip(
          label: Text(_filters.duration.label),
          onDeleted: () => _applyFilters(
            _filters.copyWith(duration: VideoDurationPreset.any),
          ),
        ),
      );
    }
    if (_filters.verifiedOnly) {
      chips.add(
        InputChip(
          label: const Text('已验证上传者'),
          onDeleted: () =>
              _applyFilters(_filters.copyWith(verifiedOnly: false)),
        ),
      );
    }
    for (final suggestion in [
      ..._filters.tags,
      ..._filters.categories,
      ..._filters.models,
    ]) {
      chips.add(
        EditableTranslationRegion(
          translationService: widget.translationService,
          kind: suggestion.kind.discoveryKind,
          english: suggestion.title,
          child: InputChip(
            avatar: Icon(_suggestionIcon(suggestion.kind), size: 18),
            label: TranslatedMetadataText(
              translationService: widget.translationService,
              kind: suggestion.kind.discoveryKind,
              original: suggestion.title,
              constrainToScreen: true,
            ),
            onDeleted: () => _removeSuggestion(suggestion),
          ),
        ),
      );
    }
    for (final suggestion in [
      ..._filters.excludedTags,
      ..._filters.excludedCategories,
      ..._filters.excludedModels,
    ]) {
      chips.add(
        EditableTranslationRegion(
          translationService: widget.translationService,
          kind: suggestion.kind.discoveryKind,
          english: suggestion.title,
          child: InputChip(
            avatar: Icon(_suggestionIcon(suggestion.kind), size: 18),
            label: TranslatedMetadataText(
              translationService: widget.translationService,
              kind: suggestion.kind.discoveryKind,
              original: suggestion.title,
              prefix: '排除：',
              constrainToScreen: true,
            ),
            onDeleted: () => _removeSuggestion(suggestion, excluded: true),
          ),
        ),
      );
    }
    if (_filters.minRating != null) {
      chips.add(
        InputChip(
          label: Text('点赞率 ≥ ${_filters.minRating}%'),
          onDeleted: () => _applyFilters(_filters.copyWith(minRating: null)),
        ),
      );
    }
    if (_filters.minRatingVotes != null) {
      chips.add(
        InputChip(
          label: Text('投票数 ≥ ${_filters.minRatingVotes}'),
          onDeleted: () =>
              _applyFilters(_filters.copyWith(minRatingVotes: null)),
        ),
      );
    }
    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => chips[index],
      ),
    );
  }

  Widget _buildScopeSelector() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: SearchResultScope.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final scope = SearchResultScope.values[index];
          return ChoiceChip(
            label: Text(scope.label),
            selected: scope == _scope,
            onSelected: (_) => setState(() => _scope = scope),
          );
        },
      ),
    );
  }

  Widget _buildLanding() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _buildHistory(),
        const SizedBox(height: 24),
        Text('热门标签', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        FutureBuilder<List<ContentCollectionItem>>(
          future: _popularTags,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return Row(
                children: [
                  const Expanded(child: Text('热门标签暂时不可用。')),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _popularTags = _loadPopularTags());
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                ],
              );
            }
            if (snapshot.data?.isEmpty ?? true) {
              return const Text('暂时没有可展示的热门标签。');
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: snapshot.requireData
                  .map(
                    (item) => EditableTranslationRegion(
                      translationService: widget.translationService,
                      kind: item.kind,
                      english: item.title,
                      child: ActionChip(
                        label: TranslatedMetadataText(
                          translationService: widget.translationService,
                          kind: item.kind,
                          original: item.title,
                          constrainToScreen: true,
                        ),
                        onPressed: () => _openCollectionItem(item),
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHistory() {
    final loggedIn = widget.api.sessionStore.isLoggedIn;
    return StreamBuilder<List<SearchHistory>>(
      stream: _historyStream,
      builder: (context, snapshot) {
        final history = snapshot.data ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '搜索历史',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (history.isNotEmpty)
                  TextButton(
                    onPressed: _confirmClearHistory,
                    child: const Text('清空'),
                  ),
              ],
            ),
            if (!loggedIn)
              const Text('登录后，搜索历史会按账号安全保存。')
            else if (snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator()
            else if (history.isEmpty)
              const Text('还没有搜索记录。')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: history
                    .map(
                      (item) => InputChip(
                        label: Text(item.displayQuery),
                        onPressed: () => _search(item.displayQuery),
                        onDeleted: () => unawaited(_deleteHistory(item)),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        );
      },
    );
  }

  Widget _buildResults() {
    return switch (_scope) {
      SearchResultScope.overview => Column(
        children: [
          if (_suggestions.values.any((items) => items.isNotEmpty))
            SizedBox(
              height: 108,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final kind in SearchSuggestionKind.values)
                    if ((_suggestions[kind] ?? const []).isNotEmpty)
                      _SuggestionRow(
                        kind: kind,
                        suggestions: _suggestions[kind]!.take(5).toList(),
                        translationService: widget.translationService,
                        onSelected: _openSuggestionCollection,
                      ),
                ],
              ),
            ),
          Expanded(child: _buildVideoResults()),
        ],
      ),
      SearchResultScope.videos => _buildVideoResults(),
      SearchResultScope.tags => _buildSuggestionResults(
        SearchSuggestionKind.tag,
      ),
      SearchResultScope.models => _buildSuggestionResults(
        SearchSuggestionKind.model,
      ),
      SearchResultScope.categories => _buildSuggestionResults(
        SearchSuggestionKind.category,
      ),
    };
  }

  Widget _buildVideoResults() {
    return VideoFeed(
      key: ValueKey('$_searchRevision:$_activeQuery'),
      loadPage: (page) => widget.prefetchService.runForeground(
        PredictivePrefetchKey.feed('search:$_searchRevision', page),
        () => _loadVideoSearchPage(page),
      ),
      prefetchService: widget.prefetchService,
      itemFilter: _filters.hasQualityFilters ? _filters.matchesQuality : null,
      emptyMessage: '没有找到符合条件的视频。',
    );
  }

  Future<List<VideoItem>> _loadVideoSearchPage(int page) async {
    if (!_containsCjk(_activeQuery)) {
      return widget.api.searchVideos(_activeQuery, page, filters: _filters);
    }

    final titleMatches = widget.translationService.searchTitleTranslations(
      _activeQuery,
      limit: 6,
    );
    List<VideoItem> direct = const [];
    try {
      direct = await widget.api.searchVideos(
        _activeQuery,
        page,
        filters: _filters,
      );
    } on Object {
      if (page > 1 || titleMatches.isEmpty) rethrow;
    }
    if (page > 1 || titleMatches.isEmpty) return direct;

    final reverseResults = await Future.wait(
      titleMatches.map((match) async {
        try {
          final items = await widget.api.searchVideos(
            match.english,
            1,
            filters: _filters,
          );
          return MapEntry(match.videoId, items);
        } on Object {
          return MapEntry(match.videoId, const <VideoItem>[]);
        }
      }),
    );

    final remoteById = <String, VideoItem>{
      for (final item in direct) item.id: item,
    };
    for (final entry in reverseResults) {
      for (final item in entry.value) {
        if (item.id == entry.key) {
          remoteById[entry.key] = item;
          break;
        }
      }
    }

    final merged = <VideoItem>[];
    for (final match in titleMatches) {
      final remote = remoteById.remove(match.videoId);
      if (remote != null) {
        merged.add(remote);
      } else if (_filters.isEmpty) {
        merged.add(
          VideoItem(id: match.videoId, title: match.english, slug: match.slug),
        );
      }
    }
    merged.addAll(remoteById.values);
    return merged;
  }

  Widget _buildSuggestionResults(SearchSuggestionKind kind) {
    if (_suggestionLoading && (_suggestions[kind] ?? const []).isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = _suggestions[kind] ?? const [];
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(_suggestionError ?? '没有找到相关${kind.label}。'),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return EditableTranslationRegion(
          translationService: widget.translationService,
          kind: kind.discoveryKind,
          english: item.title,
          child: Card(
            child: ListTile(
              leading: Icon(_suggestionIcon(kind)),
              title: TranslatedMetadataText(
                translationService: widget.translationService,
                kind: kind.discoveryKind,
                original: item.title,
              ),
              subtitle: Text('${formatCount(item.total)} 个视频'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openSuggestionCollection(item),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openFilterSheet() async {
    final selected = await showVideoFilterSheet(
      context: context,
      api: widget.api,
      initialFilters: _filters,
      translationService: widget.translationService,
    );
    if (selected != null) {
      _applyFilters(selected);
    }
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空搜索历史？'),
        content: const Text('只会清除当前账号在这台设备上的搜索记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await widget.historyRepository.clear();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('搜索历史清空失败，请稍后重试。')));
        }
      }
    }
  }

  Future<void> _deleteHistory(SearchHistory item) async {
    try {
      await widget.historyRepository.delete(item);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('搜索记录删除失败，请稍后重试。')));
      }
    }
  }

  void _removeSuggestion(SearchSuggestion suggestion, {bool excluded = false}) {
    _applyFilters(switch ((suggestion.kind, excluded)) {
      (SearchSuggestionKind.tag, false) => _filters.copyWith(
        tags: _filters.tags
            .where((item) => item.id != suggestion.id)
            .toList(growable: false),
      ),
      (SearchSuggestionKind.category, false) => _filters.copyWith(
        categories: _filters.categories
            .where((item) => item.id != suggestion.id)
            .toList(growable: false),
      ),
      (SearchSuggestionKind.model, false) => _filters.copyWith(
        models: _filters.models
            .where((item) => item.id != suggestion.id)
            .toList(growable: false),
      ),
      (SearchSuggestionKind.tag, true) => _filters.copyWith(
        excludedTags: _filters.excludedTags
            .where((item) => item.id != suggestion.id)
            .toList(growable: false),
      ),
      (SearchSuggestionKind.category, true) => _filters.copyWith(
        excludedCategories: _filters.excludedCategories
            .where((item) => item.id != suggestion.id)
            .toList(growable: false),
      ),
      (SearchSuggestionKind.model, true) => _filters.copyWith(
        excludedModels: _filters.excludedModels
            .where((item) => item.id != suggestion.id)
            .toList(growable: false),
      ),
    });
  }

  void _openSuggestionCollection(SearchSuggestion suggestion) {
    _openCollectionItem(suggestion.collection);
  }

  Future<void> _openLocalTagSuggestion(
    TranslatedTagSuggestion suggestion,
  ) async {
    _focusNode.unfocus();
    try {
      final remote = await widget.api.searchSuggestions(
        suggestion.english,
        SearchSuggestionKind.tag,
      );
      final canonical = _canonicalEnglish(suggestion.english);
      final exact = remote.where(
        (item) => _canonicalEnglish(item.title) == canonical,
      );
      if (exact.isNotEmpty) {
        _openSuggestionCollection(exact.first);
        return;
      }
    } on Object {
      // 标签端点暂时不可用时退化为英文自由文本搜索。
    }
    if (mounted) {
      await _search(suggestion.english);
    }
  }

  void _openLocalTitleSuggestion(TranslatedTitleSuggestion suggestion) {
    _focusNode.unfocus();
    context.pushNamed(
      AppRouteNames.video,
      pathParameters: {'id': suggestion.videoId, 'slug': suggestion.slug},
      extra: VideoItem(
        id: suggestion.videoId,
        title: suggestion.english,
        slug: suggestion.slug,
      ),
    );
  }

  void _openCollectionItem(ContentCollectionItem collection) {
    context.pushNamed(
      AppRouteNames.collection,
      pathParameters: {'kind': collection.kind.name, 'id': collection.id},
      extra: collection,
    );
  }

  IconData _suggestionIcon(SearchSuggestionKind kind) => switch (kind) {
    SearchSuggestionKind.tag => Icons.tag,
    SearchSuggestionKind.category => Icons.category_outlined,
    SearchSuggestionKind.model => Icons.brush_outlined,
  };
}

class _LocalTagSuggestionList extends StatelessWidget {
  const _LocalTagSuggestionList({
    required this.suggestions,
    required this.onSelected,
  });

  final List<TranslatedTagSuggestion> suggestions;
  final ValueChanged<TranslatedTagSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: suggestions
          .take(8)
          .map(
            (item) => ListTile(
              dense: true,
              leading: const Icon(Icons.tag),
              title: Text('${item.displayChinese} · ${item.english}'),
              subtitle: item.matchedAlternateAlias
                  ? Text('匹配译名：${item.matchedAlias}')
                  : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onSelected(item),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _LocalTitleSuggestionList extends StatelessWidget {
  const _LocalTitleSuggestionList({
    required this.suggestions,
    required this.onSelected,
  });

  final List<TranslatedTitleSuggestion> suggestions;
  final ValueChanged<TranslatedTitleSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: suggestions
          .take(8)
          .map(
            (item) => ListTile(
              dense: true,
              leading: const Icon(Icons.movie_outlined),
              title: Text(item.displayChinese),
              subtitle: Text('已学习标题 · ${item.english}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onSelected(item),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.kind,
    required this.suggestions,
    required this.translationService,
    required this.onSelected,
  });

  final SearchSuggestionKind kind;
  final List<SearchSuggestion> suggestions;
  final TranslationService translationService;
  final ValueChanged<SearchSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              kind.label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: suggestions
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: EditableTranslationRegion(
                          translationService: translationService,
                          kind: kind.discoveryKind,
                          english: item.title,
                          child: ActionChip(
                            label: TranslatedMetadataText(
                              translationService: translationService,
                              kind: kind.discoveryKind,
                              original: item.title,
                              suffix: ' · ${formatCount(item.total)}',
                              constrainToScreen: true,
                            ),
                            onPressed: () => onSelected(item),
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _containsCjk(String value) {
  return RegExp(r'[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]').hasMatch(value);
}

bool _minimumSuggestionLengthMet(String query) {
  return _containsCjk(query) ? query.isNotEmpty : query.length >= 2;
}

String _canonicalEnglish(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}
