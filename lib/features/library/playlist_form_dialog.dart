import 'package:flutter/material.dart';

import '../../core/models/video_models.dart';

Future<PlaylistFormData?> showPlaylistEditor(
  BuildContext context, {
  required String title,
  required PlaylistFormData initial,
}) async {
  final titleController = TextEditingController(text: initial.title);
  final descriptionController = TextEditingController(
    text: initial.description,
  );
  var isPrivate = initial.isPrivate;
  final result = await showDialog<PlaylistFormData>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                maxLength: 100,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              TextField(
                controller: descriptionController,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(labelText: '描述（可选）'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('设为私密'),
                value: isPrivate,
                onChanged: (value) => setDialogState(() => isPrivate = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = titleController.text.trim();
              if (value.isEmpty) {
                return;
              }
              Navigator.pop(
                context,
                PlaylistFormData(
                  title: value,
                  description: descriptionController.text.trim(),
                  isPrivate: isPrivate,
                ),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
  titleController.dispose();
  descriptionController.dispose();
  return result;
}
