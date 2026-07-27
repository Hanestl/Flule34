import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../core/database/app_database.dart';
import '../../core/models/video_models.dart';
import '../../shared/video_card.dart';
import 'data/local_library_repository.dart';
import 'local_library_name_dialog.dart';

class LocalLibraryOverview extends StatelessWidget {
  const LocalLibraryOverview({super.key, required this.repository});

  final LocalLibraryRepository repository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LocalLibrarySummary>>(
      stream: repository.watchLibrarySummaries(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final libraries = snapshot.requireData;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _create(context),
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('新建本地库'),
            ),
            const SizedBox(height: 12),
            if (libraries.isEmpty)
              const _EmptyLibraries()
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
        );
      },
    );
  }

  Future<void> _create(BuildContext context) async {
    final name = await showLocalLibraryNameDialog(context, title: '新建本地库');
    if (name == null || !context.mounted) {
      return;
    }
    try {
      await repository.createLibrary(name);
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
      await repository.renameLibrary(library.id, name);
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
      await repository.deleteLibrary(library.id);
    }
  }
}

class LocalLibraryPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<List<VideoItem>>(
        stream: repository.watchVideos(libraryId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final videos = snapshot.requireData;
          if (videos.isEmpty) {
            return const Center(child: Text('这个本地库里还没有视频。'));
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 28),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return Column(
                children: [
                  VideoCard(
                    video: video,
                    onTap: () => context.pushNamed(
                      AppRouteNames.video,
                      pathParameters: {'id': video.id, 'slug': video.slug},
                      extra: video,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => repository.removeVideo(
                        libraryId: libraryId,
                        videoId: video.id,
                      ),
                      icon: const Icon(Icons.remove_circle_outline),
                      label: const Text('移出此库'),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
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
            '创建自定义分类后，可以从任意视频的“入库”按钮保存到这里。',
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
