import 'package:flutter/material.dart';

import '../../core/models/video_models.dart';
import 'data/local_library_repository.dart';
import 'local_library_name_dialog.dart';

Future<String?> addVideoToLocalLibrary({
  required BuildContext context,
  required LocalLibraryRepository repository,
  required VideoItem video,
}) async {
  var libraries = await repository.watchLibraries().first;
  if (!context.mounted) {
    return null;
  }
  if (libraries.isEmpty) {
    final name = await showLocalLibraryNameDialog(
      context,
      title: '新建本地库',
      hintText: '例如：喜欢的动画、待整理',
    );
    if (name == null || !context.mounted) {
      return null;
    }
    final id = await repository.createLibrary(name);
    libraries = await repository.watchLibraries().first;
    final library = libraries.firstWhere((item) => item.id == id);
    await repository.addVideo(libraryId: id, video: video);
    return library.name;
  }

  final containedIds = await repository.libraryIdsForVideo(video.id);
  if (!context.mounted) {
    return null;
  }
  final selected = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text('选择本地库', style: Theme.of(context).textTheme.titleLarge),
          ),
          for (final library in libraries)
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: Text(library.name),
              trailing: containedIds.contains(library.id)
                  ? const Icon(Icons.check_circle)
                  : null,
              onTap: () => Navigator.of(context).pop(library.id),
            ),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('新建本地库'),
            onTap: () => Navigator.of(context).pop(-1),
          ),
        ],
      ),
    ),
  );
  if (selected == null || !context.mounted) {
    return null;
  }
  if (selected == -1) {
    final name = await showLocalLibraryNameDialog(
      context,
      title: '新建本地库',
      hintText: '例如：喜欢的动画、待整理',
    );
    if (name == null || !context.mounted) {
      return null;
    }
    final id = await repository.createLibrary(name);
    await repository.addVideo(libraryId: id, video: video);
    return name.trim();
  }
  final library = libraries.firstWhere((item) => item.id == selected);
  await repository.addVideo(libraryId: library.id, video: video);
  return library.name;
}
