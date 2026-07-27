import 'package:flutter/material.dart';

Future<String?> showLocalLibraryNameDialog(
  BuildContext context, {
  required String title,
  String initialValue = '',
  String? hintText,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _LocalLibraryNameDialog(
      title: title,
      initialValue: initialValue,
      hintText: hintText,
    ),
  );
}

class _LocalLibraryNameDialog extends StatefulWidget {
  const _LocalLibraryNameDialog({
    required this.title,
    required this.initialValue,
    this.hintText,
  });

  final String title;
  final String initialValue;
  final String? hintText;

  @override
  State<_LocalLibraryNameDialog> createState() =>
      _LocalLibraryNameDialogState();
}

class _LocalLibraryNameDialogState extends State<_LocalLibraryNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        decoration: InputDecoration(
          labelText: '库名称',
          hintText: widget.hintText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('确定')),
      ],
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) {
      Navigator.of(context).pop(value);
    }
  }
}
