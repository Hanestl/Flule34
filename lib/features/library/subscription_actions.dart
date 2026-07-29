import 'package:flutter/material.dart';

import '../../core/models/video_models.dart';

Future<bool> confirmUnsubscribeSubscription(
  BuildContext context,
  SubscriptionItem subscription,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('取消订阅'),
          content: Text('确定取消订阅“${subscription.title}”吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确定'),
            ),
          ],
        ),
      ) ??
      false;
}
