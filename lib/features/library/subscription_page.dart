import 'package:flutter/material.dart';

import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../../shared/video_feed.dart';
import 'subscription_actions.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({
    super.key,
    required this.api,
    required this.subscription,
  });

  final Rule34VideoApi api;
  final SubscriptionItem subscription;

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  var _unsubscribing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subscription.title),
        actions: [
          if (widget.api.canUnsubscribeSubscription(widget.subscription))
            _unsubscribing
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: '取消订阅',
                    onPressed: _unsubscribe,
                    icon: const Icon(Icons.notifications_off_outlined),
                  ),
        ],
      ),
      body: VideoFeed(
        loadPage: (page) =>
            widget.api.loadSubscriptionVideos(widget.subscription, page),
        emptyMessage: '这个订阅目前没有可显示的视频。',
        showSearchAndFilters: true,
        searchHint: '搜索此订阅中的视频',
      ),
    );
  }

  Future<void> _unsubscribe() async {
    if (_unsubscribing ||
        !await confirmUnsubscribeSubscription(context, widget.subscription) ||
        !mounted) {
      return;
    }
    setState(() => _unsubscribing = true);
    try {
      await widget.api.unsubscribeSubscription(widget.subscription);
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(const SnackBar(content: Text('已取消订阅。')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _unsubscribing = false);
      }
    }
  }
}
