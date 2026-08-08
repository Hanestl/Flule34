import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../../core/services/translation_service.dart';
import '../../shared/editable_translation.dart';
import '../../shared/localized_translation_text.dart';

Future<SearchFilters?> showVideoFilterSheet({
  required BuildContext context,
  required Rule34VideoApi api,
  required SearchFilters initialFilters,
  required TranslationService translationService,
}) {
  return showModalBottomSheet<SearchFilters>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.94,
    ),
    builder: (context) => _VideoFilterSheet(
      api: api,
      initialFilters: initialFilters,
      translationService: translationService,
    ),
  );
}

class _VideoFilterSheet extends StatefulWidget {
  const _VideoFilterSheet({
    required this.api,
    required this.initialFilters,
    required this.translationService,
  });

  final Rule34VideoApi api;
  final SearchFilters initialFilters;
  final TranslationService translationService;

  @override
  State<_VideoFilterSheet> createState() => _VideoFilterSheetState();
}

class _VideoFilterSheetState extends State<_VideoFilterSheet> {
  late SearchFilters _draft = widget.initialFilters;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '筛选与排序',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _draft = const SearchFilters()),
                  child: const Text('全部清除'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                _title(context, '排序'),
                DropdownButtonFormField<VideoSort>(
                  initialValue: _draft.sort,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: VideoSort.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _draft = _draft.copyWith(sort: value));
                    }
                  },
                ),
                const SizedBox(height: 24),
                _title(context, '必须同时包含'),
                const Text('同类条件和不同类型条件均取交集，每类最多选择 5 项。'),
                const SizedBox(height: 10),
                _entitySection(SearchSuggestionKind.tag, excluded: false),
                _entitySection(SearchSuggestionKind.model, excluded: false),
                _entitySection(SearchSuggestionKind.category, excluded: false),
                const SizedBox(height: 18),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Text('排除内容'),
                  subtitle: const Text('命中任一排除条件的视频不会显示'),
                  children: [
                    _entitySection(SearchSuggestionKind.tag, excluded: true),
                    _entitySection(SearchSuggestionKind.model, excluded: true),
                    _entitySection(
                      SearchSuggestionKind.category,
                      excluded: true,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _title(context, '基础条件'),
                _dropdownTile<ContentOrientation>(
                  title: '内容取向',
                  value: _draft.orientation,
                  values: ContentOrientation.values,
                  label: (value) => value.label,
                  onChanged: (value) =>
                      _draft = _draft.copyWith(orientation: value),
                ),
                _dropdownTile<UploadPeriod>(
                  title: '发布时间',
                  value: _draft.uploadPeriod,
                  values: UploadPeriod.values,
                  label: (value) => value.label,
                  onChanged: (value) =>
                      _draft = _draft.copyWith(uploadPeriod: value),
                ),
                _dropdownTile<VideoDurationPreset>(
                  title: '视频时长',
                  value: _draft.duration,
                  values: VideoDurationPreset.values,
                  label: (value) => value.label,
                  onChanged: (value) =>
                      _draft = _draft.copyWith(duration: value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('仅显示已验证上传者'),
                  value: _draft.verifiedOnly,
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(verifiedOnly: value),
                  ),
                ),
                const SizedBox(height: 18),
                _title(context, '质量条件'),
                const Text('点赞率必须配合投票数判断，避免少量投票造成虚高。'),
                const SizedBox(height: 8),
                _nullableIntDropdown(
                  title: '最低点赞率',
                  value: _draft.minRating,
                  values: const [70, 80, 85, 90, 95],
                  suffix: '%',
                  onChanged: (value) =>
                      _draft = _draft.copyWith(minRating: value),
                ),
                _nullableIntDropdown(
                  title: '最低投票数',
                  value: _draft.minRatingVotes,
                  values: const [5, 10, 25, 50, 100],
                  suffix: '票',
                  onChanged: (value) =>
                      _draft = _draft.copyWith(minRatingVotes: value),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_draft),
                child: Text(
                  _draft.activeCount == 0
                      ? '应用（不限）'
                      : '应用 ${_draft.activeCount} 个条件',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _title(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  Widget _entitySection(SearchSuggestionKind kind, {required bool excluded}) {
    final items = _items(kind, excluded: excluded);
    final prefix = excluded ? '排除' : '添加';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(kind.label)),
              TextButton.icon(
                onPressed: items.length >= 5
                    ? null
                    : () => _addEntity(kind, excluded: excluded),
                icon: const Icon(Icons.add),
                label: Text('$prefix${kind.label}'),
              ),
            ],
          ),
          if (items.isEmpty)
            Text(
              excluded ? '未排除任何${kind.label}' : '尚未选择${kind.label}',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: items
                  .map(
                    (item) => EditableTranslationRegion(
                      translationService: widget.translationService,
                      kind: kind.discoveryKind,
                      english: item.title,
                      child: InputChip(
                        avatar: Icon(_kindIcon(kind), size: 18),
                        label: TranslatedMetadataText(
                          translationService: widget.translationService,
                          kind: kind.discoveryKind,
                          original: item.title,
                          constrainToScreen: true,
                        ),
                        onDeleted: () =>
                            _removeEntity(item, excluded: excluded),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  Widget _dropdownTile<T>({
    required String title,
    required T value,
    required List<T> values,
    required String Function(T value) label,
    required ValueChanged<T> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      trailing: DropdownButton<T>(
        value: value,
        items: values
            .map(
              (item) => DropdownMenuItem(value: item, child: Text(label(item))),
            )
            .toList(growable: false),
        onChanged: (next) {
          if (next != null) {
            setState(() => onChanged(next));
          }
        },
      ),
    );
  }

  Widget _nullableIntDropdown({
    required String title,
    required int? value,
    required List<int> values,
    required String suffix,
    required ValueChanged<int?> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      trailing: DropdownButton<int>(
        value: value ?? 0,
        items: [
          const DropdownMenuItem(value: 0, child: Text('不限')),
          ...values.map(
            (item) =>
                DropdownMenuItem(value: item, child: Text('$item$suffix')),
          ),
        ],
        onChanged: (next) {
          setState(() => onChanged(next == 0 ? null : next));
        },
      ),
    );
  }

  List<SearchSuggestion> _items(
    SearchSuggestionKind kind, {
    required bool excluded,
  }) {
    return switch ((kind, excluded)) {
      (SearchSuggestionKind.tag, false) => _draft.tags,
      (SearchSuggestionKind.category, false) => _draft.categories,
      (SearchSuggestionKind.model, false) => _draft.models,
      (SearchSuggestionKind.tag, true) => _draft.excludedTags,
      (SearchSuggestionKind.category, true) => _draft.excludedCategories,
      (SearchSuggestionKind.model, true) => _draft.excludedModels,
    };
  }

  Future<void> _addEntity(
    SearchSuggestionKind kind, {
    required bool excluded,
  }) async {
    final selected = await showSearch<SearchSuggestion?>(
      context: context,
      delegate: _SuggestionSearchDelegate(
        api: widget.api,
        kind: kind,
        translationService: widget.translationService,
      ),
    );
    if (selected == null || !mounted) {
      return;
    }
    final current = _items(kind, excluded: excluded);
    if (current.any((item) => item.id == selected.id)) {
      return;
    }
    final updated = [...current, selected];
    setState(() {
      _draft = _replaceItems(_draft, kind, updated, excluded: excluded);
    });
  }

  void _removeEntity(SearchSuggestion item, {required bool excluded}) {
    final current = _items(item.kind, excluded: excluded);
    setState(() {
      _draft = _replaceItems(
        _draft,
        item.kind,
        current.where((saved) => saved.id != item.id).toList(growable: false),
        excluded: excluded,
      );
    });
  }

  SearchFilters _replaceItems(
    SearchFilters filters,
    SearchSuggestionKind kind,
    List<SearchSuggestion> items, {
    required bool excluded,
  }) {
    return switch ((kind, excluded)) {
      (SearchSuggestionKind.tag, false) => filters.copyWith(tags: items),
      (SearchSuggestionKind.category, false) => filters.copyWith(
        categories: items,
      ),
      (SearchSuggestionKind.model, false) => filters.copyWith(models: items),
      (SearchSuggestionKind.tag, true) => filters.copyWith(excludedTags: items),
      (SearchSuggestionKind.category, true) => filters.copyWith(
        excludedCategories: items,
      ),
      (SearchSuggestionKind.model, true) => filters.copyWith(
        excludedModels: items,
      ),
    };
  }

  IconData _kindIcon(SearchSuggestionKind kind) => switch (kind) {
    SearchSuggestionKind.tag => Icons.tag,
    SearchSuggestionKind.category => Icons.category_outlined,
    SearchSuggestionKind.model => Icons.brush_outlined,
  };
}

class _SuggestionSearchDelegate extends SearchDelegate<SearchSuggestion?> {
  _SuggestionSearchDelegate({
    required this.api,
    required this.kind,
    required this.translationService,
  });

  final Rule34VideoApi api;
  final SearchSuggestionKind kind;
  final TranslationService translationService;

  @override
  String get searchFieldLabel => '搜索${kind.label}';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          tooltip: '清空',
          onPressed: () => query = '',
          icon: const Icon(Icons.clear),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      tooltip: '返回',
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSuggestions(context);
  }

  Widget _buildSuggestions(BuildContext context) {
    final normalized = query.trim();
    if (normalized.length < 2) {
      return const Center(child: Text('请至少输入 2 个字符。'));
    }
    return _DebouncedSuggestionResults(
      api: api,
      kind: kind,
      query: normalized,
      translationService: translationService,
      onSelected: (item) => close(context, item),
    );
  }
}

class _DebouncedSuggestionResults extends StatefulWidget {
  const _DebouncedSuggestionResults({
    required this.api,
    required this.kind,
    required this.query,
    required this.translationService,
    required this.onSelected,
  });

  final Rule34VideoApi api;
  final SearchSuggestionKind kind;
  final String query;
  final TranslationService translationService;
  final ValueChanged<SearchSuggestion> onSelected;

  @override
  State<_DebouncedSuggestionResults> createState() =>
      _DebouncedSuggestionResultsState();
}

class _DebouncedSuggestionResultsState
    extends State<_DebouncedSuggestionResults> {
  Timer? _debounce;
  Future<List<SearchSuggestion>>? _future;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant _DebouncedSuggestionResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query || oldWidget.kind != widget.kind) {
      _schedule();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _schedule() {
    _debounce?.cancel();
    setStateIfMounted(() => _future = null);
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(
          () =>
              _future = widget.api.searchSuggestions(widget.query, widget.kind),
        );
      }
    });
  }

  void setStateIfMounted(VoidCallback action) {
    if (mounted) {
      setState(action);
    } else {
      action();
    }
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<List<SearchSuggestion>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final items = snapshot.data ?? const <SearchSuggestion>[];
        if (items.isEmpty) {
          return Center(child: Text('没有找到匹配的${widget.kind.label}。'));
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return EditableTranslationRegion(
              translationService: widget.translationService,
              kind: widget.kind.discoveryKind,
              english: item.title,
              child: ListTile(
                title: TranslatedMetadataText(
                  translationService: widget.translationService,
                  kind: widget.kind.discoveryKind,
                  original: item.title,
                ),
                subtitle: Text('${item.total} 个视频'),
                onTap: () => widget.onSelected(item),
              ),
            );
          },
        );
      },
    );
  }
}
