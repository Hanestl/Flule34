import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/database/app_database.dart';
import '../../core/models/video_models.dart';
import '../../shared/video_card.dart';
import '../../shared/video_list_filters.dart';
import 'data/local_library_repository.dart';
import 'local_library_name_dialog.dart';

enum LocalLibraryOverviewSort {
  modified('最近修改'),
  created('最新创建'),
  name('按名字');

  const LocalLibraryOverviewSort(this.label);

  final String label;
}

class LocalLibraryOverview extends StatefulWidget {
  const LocalLibraryOverview({super.key, required this.repository});

  final LocalLibraryRepository repository;

  @override
  State<LocalLibraryOverview> createState() => _LocalLibraryOverviewState();
}

class _LocalLibraryOverviewState extends State<LocalLibraryOverview> {
  final TextEditingController _searchController = TextEditingController();
  var _query = '';
  var _sort = LocalLibraryOverviewSort.modified;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LocalLibrarySummary>>(
      stream: widget.repository.watchLibrarySummaries(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final libraries = _visibleLibraries(snapshot.requireData);
        return Material(
          type: MaterialType.transparency,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _create(context),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('新建本地库'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SearchBar(
                      controller: _searchController,
                      leading: const Icon(Icons.search),
                      hintText: '搜索本地库',
                      trailing: [
                        if (_query.isNotEmpty)
                          IconButton(
                            tooltip: '清除',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _query = value.trim()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<LocalLibraryOverviewSort>(
                    tooltip: '排序',
                    initialValue: _sort,
                    onSelected: (value) => setState(() => _sort = value),
                    itemBuilder: (context) => LocalLibraryOverviewSort.values
                        .map(
                          (item) => PopupMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(growable: false),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.sort),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (libraries.isEmpty)
                _query.isEmpty
                    ? const _EmptyLibraries()
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: Text('没有符合条件的本地库。')),
                      )
              else
                for (final summary in libraries)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const Icon(Icons.video_library_outlined),
                      title: Text(summary.library.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${summary.videoCount}',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          PopupMenuButton<_LibraryAction>(
                            onSelected: (action) {
                              switch (action) {
                                case _LibraryAction.rename:
                                  _rename(context, summary.library);
                                case _LibraryAction.delete:
                                  _delete(context, summary.library);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: _LibraryAction.rename,
                                child: Text('重命名'),
                              ),
                              PopupMenuItem(
                                value: _LibraryAction.delete,
                                child: Text('删除'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => context.pushNamed(
                        AppRouteNames.localLibrary,
                        pathParameters: {'id': '${summary.library.id}'},
                        extra: summary.library,
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  List<LocalLibrarySummary> _visibleLibraries(
    List<LocalLibrarySummary> source,
  ) {
    final normalized = _query.trim().toLowerCase();
    final result = source
        .where(
          (item) =>
              normalized.isEmpty ||
              item.library.name.toLowerCase().contains(normalized),
        )
        .toList(growable: true);
    switch (_sort) {
      case LocalLibraryOverviewSort.modified:
        result.sort(
          (left, right) =>
              right.library.updatedAt.compareTo(left.library.updatedAt),
        );
      case LocalLibraryOverviewSort.created:
        result.sort(
          (left, right) =>
              right.library.createdAt.compareTo(left.library.createdAt),
        );
      case LocalLibraryOverviewSort.name:
        result.sort(
          (left, right) => left.library.name.toLowerCase().compareTo(
            right.library.name.toLowerCase(),
          ),
        );
    }
    return result;
  }

  Future<void> _create(BuildContext context) async {
    final name = await showLocalLibraryNameDialog(context, title: '新建本地库');
    if (name == null || !context.mounted) {
      return;
    }
    try {
      await widget.repository.createLibrary(name);
    } catch (error) {
      if (context.mounted) {
        _message(context, error.toString());
      }
    }
  }

  Future<void> _rename(BuildContext context, LocalLibrary library) async {
    final name = await showLocalLibraryNameDialog(
      context,
      title: '重命名本地库',
      initialValue: library.name,
    );
    if (name == null || !context.mounted) {
      return;
    }
    try {
      await widget.repository.renameLibrary(library.id, name);
    } catch (error) {
      if (context.mounted) {
        _message(context, error.toString());
      }
    }
  }

  Future<void> _delete(BuildContext context, LocalLibrary library) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除“${library.name}”？'),
        content: const Text('只删除本地分类记录，不会删除网站收藏、历史或已下载的视频。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repository.deleteLibrary(library.id);
    }
  }
}

class LocalLibraryPage extends StatefulWidget {
  const LocalLibraryPage({
    super.key,
    required this.repository,
    required this.libraryId,
    required this.title,
  });

  final LocalLibraryRepository repository;
  final int libraryId;
  final String title;

  @override
  State<LocalLibraryPage> createState() => _LocalLibraryPageState();
}

class _LocalLibraryPageState extends State<LocalLibraryPage> {
  final TextEditingController _searchController = TextEditingController();
  var _query = '';
  var _filters = const VideoListFilters();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: '筛选',
            onPressed: _showFilters,
            icon: Badge(
              isLabelVisible: _filters.activeCount > 0,
              label: Text('${_filters.activeCount}'),
              child: const Icon(Icons.tune),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: SearchBar(
              controller: _searchController,
              leading: const Icon(Icons.search),
              hintText: '搜索此库中的视频',
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    tooltip: '清除',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close),
                  ),
              ],
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<VideoItem>>(
              stream: widget.repository.watchVideos(widget.libraryId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final sourceVideos = snapshot.requireData;
                if (sourceVideos.isEmpty) {
                  return const Center(child: Text('这个本地库里还没有视频。'));
                }
                final videos = _filteredVideos(sourceVideos);
                if (videos.isEmpty) {
                  return const Center(child: Text('没有符合搜索和筛选条件的视频。'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 28),
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    return VideoCard(
                      video: video,
                      contextActionLabel: '移出此库',
                      onContextAction: () => _removeVideo(video),
                      onTap: () => context.pushNamed(
                        AppRouteNames.video,
                        pathParameters: {'id': video.id, 'slug': video.slug},
                        extra: video,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<VideoItem> _filteredVideos(List<VideoItem> source) {
    return filterAndSortVideos(source, query: _query, filters: _filters);
  }

  Future<void> _removeVideo(VideoItem video) async {
    try {
      await widget.repository.removeVideo(
        libraryId: widget.libraryId,
        videoId: video.id,
      );
      if (mounted) {
        _message(context, '已从本地库移出。');
      }
    } catch (error) {
      if (mounted) {
        _message(context, error.toString());
      }
    }
  }

  Future<void> _showFilters() async {
    final selected = await showVideoListFilters(
      context,
      initialValue: _filters,
      title: '筛选此库',
      defaultSortLabel: '最近添加',
    );
    if (selected != null && mounted) {
      setState(() => _filters = selected);
    }
  }
}

enum _LibraryAction { rename, delete }

class _EmptyLibraries extends StatelessWidget {
  const _EmptyLibraries();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          const Icon(Icons.video_library_outlined, size: 56),
          const SizedBox(height: 16),
          Text('还没有本地库', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            '创建自定义分类后，可以从任意视频的“本地分类库”按钮保存到这里。',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

void _message(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
