import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/database/app_database.dart';
import '../../core/models/video_models.dart';
import '../../shared/video_card.dart' show formatCount;
import '../../shared/video_feed.dart';
import 'data/search_history_repository.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.api,
    required this.historyRepository,
  });

  final Rule34VideoApi api;
  final SearchHistoryRepository historyRepository;

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
  SearchFilters _filters = const SearchFilters();
  SearchResultScope _scope = SearchResultScope.overview;
  String _activeQuery = '';
  String? _suggestionError;
  var _suggestionLoading = false;
  var _showAutocomplete = false;
  var _searchRevision = 0;
  var _suggestionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _syncHistoryStream();
    _popularTags = _loadPopularTags();
    widget.api.sessionStore.addListener(_onSessionChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  Future<List<ContentCollectionItem>> _loadPopularTags() {
    return widget.api
        .loadDiscoveryDirectory(
          const DiscoveryDirectorySpec(
            title: '热门标签',
            path: '/tags/',
            kind: DiscoveryKind.tag,
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
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
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
    if (query.length < 2) {
      _suggestionGeneration += 1;
      setState(() {
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
        _suggestionLoading = true;
        _suggestionError = null;
      });
    }
    var failed = false;
    final values = await Future.wait(
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
    if (text.isEmpty) {
      return;
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
    });
    unawaited(_recordHistory(text));
    unawaited(_loadSuggestions(text));
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
      if (_activeQuery.isNotEmpty) {
        _searchRevision += 1;
      }
    });
  }

  void _addSuggestion(SearchSuggestion suggestion) {
    final current = switch (suggestion.kind) {
      SearchSuggestionKind.tag => _filters.tags,
      SearchSuggestionKind.category => _filters.categories,
      SearchSuggestionKind.model => _filters.models,
    };
    if (current.any((item) => item.id == suggestion.id)) {
      return;
    }
    if (current.length >= 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('同类筛选最多选择 5 项。')));
      return;
    }
    final updated = [...current, suggestion];
    _applyFilters(switch (suggestion.kind) {
      SearchSuggestionKind.tag => _filters.copyWith(tags: updated),
      SearchSuggestionKind.category => _filters.copyWith(categories: updated),
      SearchSuggestionKind.model => _filters.copyWith(models: updated),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
        actions: [
          PopupMenuButton<VideoSort>(
            tooltip: '排序',
            initialValue: _filters.sort,
            onSelected: (sort) => _applyFilters(_filters.copyWith(sort: sort)),
            itemBuilder: (context) => VideoSort.values
                .map(
                  (sort) => PopupMenuItem(value: sort, child: Text(sort.label)),
                )
                .toList(growable: false),
          ),
          IconButton(
            tooltip: '筛选',
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
          if (_showAutocomplete && _controller.text.trim().length >= 2)
            _buildAutocomplete(),
          if (_activeQuery.isNotEmpty) ...[
            _buildFilterChips(),
            _buildScopeSelector(),
          ],
          Expanded(
            child: _activeQuery.isEmpty ? _buildLanding() : _buildResults(),
          ),
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
    if (_suggestionLoading && _suggestions.isEmpty) {
      return const LinearProgressIndicator();
    }
    final hasItems = _suggestions.values.any((items) => items.isNotEmpty);
    if (!hasItems && _suggestionError == null) {
      return const SizedBox.shrink();
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 196),
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
            for (final kind in SearchSuggestionKind.values)
              if ((_suggestions[kind] ?? const []).isNotEmpty)
                _SuggestionRow(
                  kind: kind,
                  suggestions: _suggestions[kind]!.take(6).toList(),
                  onSelected: _addSuggestion,
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
        InputChip(
          avatar: Icon(_suggestionIcon(suggestion.kind), size: 18),
          label: Text(suggestion.title),
          onDeleted: () => _removeSuggestion(suggestion),
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
                    (item) => ActionChip(
                      label: Text(item.title),
                      onPressed: () => _search(item.title),
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
      loadPage: (page) =>
          widget.api.searchVideos(_activeQuery, page, filters: _filters),
      emptyMessage: '没有找到符合条件的视频。',
    );
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
        return Card(
          child: ListTile(
            leading: Icon(_suggestionIcon(kind)),
            title: Text(item.title),
            subtitle: Text('${formatCount(item.total)} 个视频'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSuggestionCollection(item),
          ),
        );
      },
    );
  }

  Future<void> _openFilterSheet() async {
    var draft = _filters;
    final selected = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('筛选', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),
                  const Text('内容取向'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ContentOrientation.values
                        .map(
                          (value) => ChoiceChip(
                            label: Text(value.label),
                            selected: draft.orientation == value,
                            onSelected: (_) => setSheetState(
                              () => draft = draft.copyWith(orientation: value),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 20),
                  const Text('上传时间'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: UploadPeriod.values
                        .map(
                          (value) => ChoiceChip(
                            label: Text(value.label),
                            selected: draft.uploadPeriod == value,
                            onSelected: (_) => setSheetState(
                              () => draft = draft.copyWith(uploadPeriod: value),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 20),
                  const Text('视频时长'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: VideoDurationPreset.values
                        .map(
                          (value) => ChoiceChip(
                            label: Text(value.label),
                            selected: draft.duration == value,
                            onSelected: (_) => setSheetState(
                              () => draft = draft.copyWith(duration: value),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('仅显示已验证上传者'),
                    value: draft.verifiedOnly,
                    onChanged: (value) => setSheetState(
                      () => draft = draft.copyWith(verifiedOnly: value),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setSheetState(
                            () => draft = const SearchFilters(),
                          ),
                          child: const Text('重置全部'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, draft),
                          child: const Text('应用'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
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

  void _removeSuggestion(SearchSuggestion suggestion) {
    _applyFilters(switch (suggestion.kind) {
      SearchSuggestionKind.tag => _filters.copyWith(
        tags: _filters.tags
            .where((item) => item.id != suggestion.id)
            .toList(growable: false),
      ),
      SearchSuggestionKind.category => _filters.copyWith(
        categories: _filters.categories
            .where((item) => item.id != suggestion.id)
            .toList(growable: false),
      ),
      SearchSuggestionKind.model => _filters.copyWith(
        models: _filters.models
            .where((item) => item.id != suggestion.id)
            .toList(growable: false),
      ),
    });
  }

  void _openSuggestionCollection(SearchSuggestion suggestion) {
    final collection = suggestion.collection;
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

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.kind,
    required this.suggestions,
    required this.onSelected,
  });

  final SearchSuggestionKind kind;
  final List<SearchSuggestion> suggestions;
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
                        child: ActionChip(
                          label: Text(
                            '${item.title} · ${formatCount(item.total)}',
                          ),
                          onPressed: () => onSelected(item),
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
