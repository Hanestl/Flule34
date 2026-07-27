import 'package:flutter/material.dart';

import '../../core/api/rule34video_api.dart';
import '../../core/models/account_models.dart';
import '../../core/models/video_models.dart';
import '../../shared/site_avatar.dart';
import '../../shared/video_feed.dart';
import '../auth/login_sheet.dart';

class UploaderPage extends StatefulWidget {
  const UploaderPage({super.key, required this.api, required this.uploader});

  final Rule34VideoApi api;
  final UploaderSummary uploader;

  @override
  State<UploaderPage> createState() => _UploaderPageState();
}

class _UploaderPageState extends State<UploaderPage> {
  late Future<MemberProfile> _profile;
  bool? _subscribed;
  var _subscriptionBusy = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.api.loadMemberProfile(widget.uploader.id);
    if (widget.api.sessionStore.isLoggedIn) {
      _loadSubscriptionStatus();
    }
  }

  Future<void> _loadSubscriptionStatus() async {
    try {
      final value = await widget.api.isUploaderSubscribed(widget.uploader);
      if (mounted) {
        setState(() => _subscribed = value);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _subscribed = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.uploader.name)),
      body: Column(
        children: [
          FutureBuilder<MemberProfile>(
            future: _profile,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return _ProfileError(
                  message: snapshot.error.toString(),
                  onRetry: () => setState(
                    () => _profile = widget.api.loadMemberProfile(
                      widget.uploader.id,
                    ),
                  ),
                );
              }
              return _buildProfile(snapshot.requireData);
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: VideoFeed(
              loadPage: (page) =>
                  widget.api.loadUploaderVideos(widget.uploader, page),
              emptyMessage: '这个上传者还没有公开视频。',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile(MemberProfile profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SiteAvatar(
                radius: 32,
                imageUrl: profile.avatarUrl ?? widget.uploader.avatarUrl,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (profile.verified) ...[
                          const SizedBox(width: 5),
                          Icon(
                            Icons.verified,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                    if (profile.subscribersLabel != null)
                      Text(profile.subscribersLabel!),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _subscriptionButton(),
            ],
          ),
          if (profile.details.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: profile.details.entries
                  .take(6)
                  .map(
                    (entry) => Chip(label: Text('${entry.key}：${entry.value}')),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _subscriptionButton() {
    if (_subscriptionBusy) {
      return const SizedBox.square(
        dimension: 28,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final subscribed = _subscribed == true;
    return subscribed
        ? OutlinedButton(
            onPressed: _toggleSubscription,
            child: const Text('已订阅'),
          )
        : FilledButton(onPressed: _toggleSubscription, child: const Text('订阅'));
  }

  Future<void> _toggleSubscription() async {
    if (_subscriptionBusy) {
      return;
    }
    if (!widget.api.sessionStore.isLoggedIn) {
      final loggedIn = await showLoginSheet(context, widget.api);
      if (!loggedIn || !mounted) {
        return;
      }
      await _loadSubscriptionStatus();
    }
    setState(() => _subscriptionBusy = true);
    final subscribed = _subscribed == true;
    try {
      await widget.api.toggleUploaderSubscription(
        uploader: widget.uploader,
        subscribe: !subscribed,
      );
      if (mounted) {
        setState(() => _subscribed = !subscribed);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(subscribed ? '已取消订阅。' : '已订阅上传者。')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _subscriptionBusy = false);
      }
    }
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: Text('上传者资料加载失败：$message')),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
