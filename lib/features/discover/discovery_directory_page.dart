import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../../core/services/translation_service.dart';
import '../../shared/editable_translation.dart';
import '../../shared/localized_translation_text.dart';
import '../../shared/site_avatar.dart';

class DiscoveryDirectoryPage extends StatefulWidget {
  const DiscoveryDirectoryPage({
    super.key,
    required this.api,
    required this.spec,
    required this.translationService,
  });

  final Rule34VideoApi api;
  final DiscoveryDirectorySpec spec;
  final TranslationService translationService;

  @override
  State<DiscoveryDirectoryPage> createState() => _DiscoveryDirectoryPageState();
}

class _DiscoveryDirectoryPageState extends State<DiscoveryDirectoryPage> {
  final ScrollController _scrollController = ScrollController();
  final List<ContentCollectionItem> _items = [];
  Timer? _searchDebounce;
  var _query = '';
  var _page = 1;
  var _loading = false;
  var _hasMore = true;
  var _searching = false;
  var _searchOperation = 0;
  List<ContentCollectionItem>? _searchResults;
  String? _error;
  String? _searchError;
  Completer<void>? _loadCompleter;

  SearchSuggestionKind? get _searchKind => switch (widget.spec.kind) {
    DiscoveryKind.tag => SearchSuggestionKind.tag,
    DiscoveryKind.category => SearchSuggestionKind.category,
    DiscoveryKind.model => SearchSuggestionKind.model,
    DiscoveryKind.channel => null,
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    widget.translationService.addListener(_onTranslationChanged);
    unawaited(_load(reset: true));
  }

  @override
  void didUpdateWidget(covariant DiscoveryDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.translationService != widget.translationService) {
      oldWidget.translationService.removeListener(_onTranslationChanged);
      widget.translationService.addListener(_onTranslationChanged);
    }
  }

  void _onTranslationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    widget.translationService.removeListener(_onTranslationChanged);
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_query.isEmpty && _scrollController.position.extentAfter < 600) {
      unawaited(_load(reset: false));
    }
  }

  void _onQueryChanged(String value) {
    final query = value.trim();
    _searchDebounce?.cancel();
    final searchKind = _searchKind;
    setState(() {
      _query = query;
      _searchError = null;
      if (query.isEmpty) {
        _searchResults = null;
        _searching = false;
      } else if (searchKind != null) {
        _searchResults = const [];
        _searching = query.length >= 2;
      }
    });
    if (searchKind == null || query.isEmpty || query.length < 2) {
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_search(query, searchKind)),
    );
  }

  Future<void> _search(String query, SearchSuggestionKind kind) async {
    final operation = ++_searchOperation;
    try {
      final suggestions = await widget.api.searchSuggestions(query, kind);
      if (!mounted || operation != _searchOperation || _query != query) {
        return;
      }
      setState(() {
        _searchResults = suggestions
            .map((suggestion) => suggestion.collection)
            .toList(growable: false);
        _searching = false;
      });
    } catch (error) {
      if (!mounted || operation != _searchOperation || _query != query) {
        return;
      }
      setState(() {
        _searching = false;
        _searchError = error.toString();
      });
    }
  }

  Future<void> _load({required bool reset}) async {
    if (_loading) {
      if (reset) {
        await _loadCompleter?.future;
        if (mounted) {
          return _load(reset: true);
        }
      }
      return;
    }
    if (!reset && !_hasMore) {
      return;
    }
    final completer = Completer<void>();
    _loadCompleter = completer;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _page = 1;
        _hasMore = true;
      }
    });
    try {
      final page = await widget.api.loadDiscoveryDirectory(
        widget.spec,
        page: _page,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final newItems = page
            .where(
              (item) => !_items.any(
                (saved) =>
                    saved.kind == item.kind &&
                    (saved.id == item.id || saved.path == item.path),
              ),
            )
            .toList(growable: false);
        _items.addAll(newItems);
        _page += 1;
        _hasMore = page.isNotEmpty && newItems.isNotEmpty;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
      if (identical(_loadCompleter, completer)) {
        _loadCompleter = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.spec.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              leading: const Icon(Icons.search),
              hintText: _searchKind == null
                  ? '筛选已加载的${widget.spec.title}'
                  : '搜索全部${widget.spec.title}',
              onChanged: _onQueryChanged,
            ),
          ),
          Expanded(child: _buildDirectory()),
        ],
      ),
    );
  }

  Widget _buildDirectory() {
    if (_query.isNotEmpty && _searchKind != null) {
      return _buildSearchResults();
    }
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty && _error != null) {
      return _DirectoryMessage(
        message: _error!,
        onRetry: () => unawaited(_load(reset: true)),
      );
    }
    final normalized = _query.toLowerCase();
    final visibleItems = _items
        .where(
          (item) =>
              normalized.isEmpty ||
              item.title.toLowerCase().contains(normalized),
        )
        .toList(growable: false);
    if (visibleItems.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Center(child: Text('没有匹配的已加载内容。')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: visibleItems.length + 1,
        itemBuilder: (context, index) {
          if (index == visibleItems.length) {
            return _buildFooter();
          }
          return _DirectoryItem(
            item: visibleItems[index],
            translationService: widget.translationService,
          );
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_query.length < 2) {
      return const _DirectoryHint(message: '请至少输入 2 个字符。');
    }
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchError != null) {
      return _DirectoryMessage(
        message: _searchError!,
        onRetry: () {
          final kind = _searchKind;
          if (kind != null) {
            setState(() => _searching = true);
            unawaited(_search(_query, kind));
          }
        },
      );
    }
    final results = _searchResults ?? const <ContentCollectionItem>[];
    if (results.isEmpty) {
      return _DirectoryHint(message: '没有找到与“$_query”匹配的${widget.spec.title}。');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: results.length,
      itemBuilder: (context, index) => _DirectoryItem(
        item: results[index],
        translationService: widget.translationService,
      ),
    );
  }

  Widget _buildFooter() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => unawaited(_load(reset: false)),
              icon: const Icon(Icons.refresh),
              label: const Text('重试加载下一页'),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(child: Text(_hasMore ? '继续向下滚动以加载更多' : '已经到底了')),
    );
  }
}

class _DirectoryItem extends StatelessWidget {
  const _DirectoryItem({required this.item, required this.translationService});

  final ContentCollectionItem item;
  final TranslationService translationService;

  @override
  Widget build(BuildContext context) {
    return EditableTranslationRegion(
      translationService: translationService,
      kind: item.kind,
      english: item.title,
      child: Card(
        child: ListTile(
          leading: SiteAvatar(
            imageUrl: item.thumbnailUrl,
            radius: 20,
            fallbackIcon: _kindIcon(item.kind),
          ),
          title: TranslatedMetadataText(
            translationService: translationService,
            kind: item.kind,
            original: item.title,
          ),
          subtitle: item.total == null
              ? Text(item.kind.label)
              : Text('${item.total} 个视频'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushNamed(
            AppRouteNames.collection,
            pathParameters: {'kind': item.kind.name, 'id': item.id},
            extra: item,
          ),
        ),
      ),
    );
  }

  IconData _kindIcon(DiscoveryKind kind) => switch (kind) {
    DiscoveryKind.tag => Icons.tag,
    DiscoveryKind.category => Icons.category_outlined,
    DiscoveryKind.model => Icons.brush_outlined,
    DiscoveryKind.channel => Icons.live_tv_outlined,
  };
}

class _DirectoryHint extends StatelessWidget {
  const _DirectoryHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class _DirectoryMessage extends StatelessWidget {
  const _DirectoryMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
