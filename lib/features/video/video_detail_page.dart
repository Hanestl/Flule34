import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router/route_names.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../../core/services/share_service.dart';
import '../../shared/video_card.dart';
import '../auth/login_sheet.dart';
import '../downloads/data/download_repository.dart';
import '../settings/data/app_settings_repository.dart';
import '../settings/domain/quality_selection.dart';
import 'video_player_page.dart';

class VideoDetailPage extends ConsumerStatefulWidget {
  const VideoDetailPage({super.key, required this.api, required this.video});

  final Rule34VideoApi api;
  final VideoItem video;

  @override
  ConsumerState<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends ConsumerState<VideoDetailPage> {
  late Future<VideoDetails> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = widget.api.loadVideoDetails(widget.video);
  }

  @override
  void didUpdateWidget(covariant VideoDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api || oldWidget.video.id != widget.video.id) {
      _detailsFuture = widget.api.loadVideoDetails(widget.video);
    }
  }

  void _reload() {
    setState(() {
      _detailsFuture = widget.api.loadVideoDetails(widget.video);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('视频详情')),
      body: FutureBuilder<VideoDetails>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _DetailLoadError(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }
          return _VideoDetailsBody(
            api: widget.api,
            details: snapshot.requireData,
            downloads: ref.watch(downloadRepositoryProvider),
            settings: ref.watch(appSettingsRepositoryProvider),
            shareService: ref.watch(shareServiceProvider),
          );
        },
      ),
    );
  }
}

class _DetailLoadError extends StatelessWidget {
  const _DetailLoadError({required this.message, required this.onRetry});

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
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoDetailsBody extends StatefulWidget {
  const _VideoDetailsBody({
    required this.api,
    required this.details,
    required this.downloads,
    required this.settings,
    required this.shareService,
  });

  final Rule34VideoApi api;
  final VideoDetails details;
  final DownloadRepository downloads;
  final AppSettingsRepository settings;
  final ShareService shareService;

  @override
  State<_VideoDetailsBody> createState() => _VideoDetailsBodyState();
}

class _VideoDetailsBodyState extends State<_VideoDetailsBody> {
  final _commentController = TextEditingController();
  late VideoDetails _details;
  late bool _favorite;
  final Set<String> _subscriptionPaths = {};
  final Set<String> _updatingMetadata = {};
  final Set<String> _votingComments = {};
  var _updatingFavorite = false;
  var _updatingRating = false;
  var _addingPlaylist = false;
  var _addingDownload = false;
  var _postingComment = false;
  var _loadingSubscriptions = false;
  var _subscriptionsLoaded = false;

  @override
  void initState() {
    super.initState();
    _details = widget.details;
    _favorite = widget.details.isFavorite;
    if (widget.api.sessionStore.isLoggedIn) {
      _loadSubscriptions();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<bool> _ensureLogin() async {
    if (widget.api.sessionStore.isLoggedIn) {
      return true;
    }
    return showLoginSheet(context, widget.api);
  }

  Future<bool> _loadSubscriptions({bool showError = false}) async {
    if (!widget.api.sessionStore.isLoggedIn || _loadingSubscriptions) {
      return _subscriptionsLoaded;
    }
    setState(() => _loadingSubscriptions = true);
    try {
      final subscriptions = await widget.api.loadSubscriptions();
      if (!mounted) {
        return false;
      }
      setState(() {
        _subscriptionPaths
          ..clear()
          ..addAll(subscriptions.map((item) => item.path));
        _subscriptionsLoaded = true;
      });
      return true;
    } catch (error) {
      if (mounted && showError) {
        _showMessage(error.toString());
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _loadingSubscriptions = false);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_updatingFavorite) {
      return;
    }
    if (!await _ensureLogin() || !mounted) {
      return;
    }
    setState(() => _updatingFavorite = true);
    try {
      await widget.api.toggleFavorite(
        video: widget.details.video,
        add: !_favorite,
      );
      if (mounted) {
        setState(() => _favorite = !_favorite);
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _updatingFavorite = false);
      }
    }
  }

  Future<void> _download() async {
    if (_addingDownload) {
      return;
    }
    if (!await _ensureLogin() || !mounted) {
      return;
    }
    final preferences = widget.settings.settings;
    final source = preferences.askDownloadQuality
        ? await showModalBottomSheet<VideoSource>(
            context: context,
            useSafeArea: true,
            builder: (context) {
              return ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Text(
                      '选择下载清晰度',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  for (final item in _details.sources.reversed)
                    ListTile(
                      leading: Icon(item.isHd ? Icons.hd : Icons.sd),
                      title: Text(item.label),
                      onTap: () => Navigator.of(context).pop(item),
                    ),
                ],
              );
            },
          )
        : selectVideoSource(_details.sources, preferences.downloadQuality);
    if (source == null || !mounted) {
      return;
    }

    setState(() => _addingDownload = true);
    try {
      await widget.downloads.enqueueVideo(details: _details, source: source);
      if (mounted) {
        _showMessage('${source.label} 已加入下载队列。');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _addingDownload = false);
      }
    }
  }

  Future<void> _rate(bool like) async {
    if (_updatingRating || !await _ensureLogin() || !mounted) {
      return;
    }
    setState(() => _updatingRating = true);
    try {
      await widget.api.rateVideo(video: _details.video, like: like);
      if (mounted) {
        _showMessage(like ? '已提交喜欢。' : '已提交不喜欢。');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _updatingRating = false);
      }
    }
  }

  Future<void> _share() async {
    try {
      await widget.shareService.shareVideo(_details.video);
    } catch (error) {
      if (mounted) {
        _showMessage('无法打开分享面板：$error');
      }
    }
  }

  Future<void> _addToPlaylist() async {
    if (_addingPlaylist || !await _ensureLogin() || !mounted) {
      return;
    }
    setState(() => _addingPlaylist = true);
    try {
      final playlists = await widget.api.loadMyPlaylists();
      if (!mounted) {
        return;
      }
      if (playlists.isEmpty) {
        _showMessage('账号中还没有播放列表；新建播放列表功能将在接口确认后接入。');
        return;
      }
      final playlist = await showModalBottomSheet<PlaylistItem>(
        context: context,
        showDragHandle: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        builder: (context) => ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Text(
                '加入播放列表',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final item in playlists)
              ListTile(
                leading: const Icon(Icons.playlist_play),
                title: Text(item.title),
                subtitle: item.videoCount == null
                    ? null
                    : Text('${item.videoCount} 个视频'),
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      );
      if (playlist == null || !mounted) {
        return;
      }
      await widget.api.addVideoToPlaylist(
        video: _details.video,
        playlistId: playlist.id,
      );
      if (mounted) {
        _showMessage('已加入“${playlist.title}”。');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _addingPlaylist = false);
      }
    }
  }

  Future<void> _postComment() async {
    if (_postingComment || !await _ensureLogin() || !mounted) {
      return;
    }
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      _showMessage('请输入评论内容。');
      return;
    }
    setState(() => _postingComment = true);
    try {
      await widget.api.postComment(video: _details.video, comment: text);
      final refreshed = await widget.api.loadVideoDetails(_details.video);
      if (!mounted) {
        return;
      }
      _commentController.clear();
      setState(() {
        _details = refreshed;
        _favorite = refreshed.isFavorite;
      });
      _showMessage('评论已发布。');
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _postingComment = false);
      }
    }
  }

  Future<void> _voteComment(VideoComment comment, bool upvote) async {
    if (_votingComments.contains(comment.id) ||
        !await _ensureLogin() ||
        !mounted) {
      return;
    }
    setState(() => _votingComments.add(comment.id));
    try {
      await widget.api.voteComment(
        video: _details.video,
        comment: comment,
        upvote: upvote,
      );
      if (mounted) {
        _showMessage(upvote ? '已赞同这条评论。' : '已反对这条评论。');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _votingComments.remove(comment.id));
      }
    }
  }

  Future<void> _openMetadataActions(VideoMetadataItem item) async {
    final subscribed = _subscriptionPaths.contains(item.path);
    final action = await showModalBottomSheet<_MetadataAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text('打开${item.kind.label}集合'),
              onTap: () => Navigator.pop(context, _MetadataAction.open),
            ),
            if (item.canSubscribe)
              ListTile(
                leading: Icon(
                  subscribed
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_active_outlined,
                ),
                title: Text(subscribed ? '取消订阅' : '订阅'),
                onTap: () =>
                    Navigator.pop(context, _MetadataAction.subscription),
              ),
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: const Text('赞成此关联'),
              onTap: () => Navigator.pop(context, _MetadataAction.upvote),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward),
              title: const Text('反对此关联'),
              onTap: () => Navigator.pop(context, _MetadataAction.downvote),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _MetadataAction.open:
        final collection = item.collection;
        context.pushNamed(
          AppRouteNames.collection,
          pathParameters: {'kind': collection.kind.name, 'id': collection.id},
          extra: collection,
        );
      case _MetadataAction.subscription:
        await _toggleSubscription(item);
      case _MetadataAction.upvote:
        await _voteMetadata(item, true);
      case _MetadataAction.downvote:
        await _voteMetadata(item, false);
    }
  }

  Future<void> _toggleSubscription(VideoMetadataItem item) async {
    if (!await _ensureLogin() || !mounted) {
      return;
    }
    if (!_subscriptionsLoaded && !await _loadSubscriptions(showError: true)) {
      return;
    }
    final key = 'subscribe:${item.kind.name}:${item.id}';
    if (_updatingMetadata.contains(key)) {
      return;
    }
    final subscribed = _subscriptionPaths.contains(item.path);
    setState(() => _updatingMetadata.add(key));
    try {
      await widget.api.toggleSubscription(
        video: _details.video,
        item: item,
        subscribe: !subscribed,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        if (subscribed) {
          _subscriptionPaths.remove(item.path);
        } else {
          _subscriptionPaths.add(item.path);
        }
      });
      _showMessage(subscribed ? '已取消订阅。' : '已订阅。');
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _updatingMetadata.remove(key));
      }
    }
  }

  Future<void> _voteMetadata(VideoMetadataItem item, bool upvote) async {
    if (!await _ensureLogin() || !mounted) {
      return;
    }
    final key = 'vote:${item.kind.name}:${item.id}';
    if (_updatingMetadata.contains(key)) {
      return;
    }
    setState(() => _updatingMetadata.add(key));
    try {
      await widget.api.voteMetadata(
        video: _details.video,
        item: item,
        upvote: upvote,
      );
      if (mounted) {
        _showMessage('投票已提交。');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _updatingMetadata.remove(key));
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    final metadata = details.metadataItems;
    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        if (details.sources.isNotEmpty)
          VideoPlayerPage(
            api: widget.api,
            video: details.video,
            sources: details.sources,
            embedded: true,
            autoplay: true,
          )
        else
          const AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: Text(
                  '此视频未提供可直接播放的 MP4 源。',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                details.video.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (details.video.duration != null)
                    _StatChip(
                      icon: Icons.schedule,
                      label: details.video.duration!,
                    ),
                  if (details.video.views != null)
                    _StatChip(
                      icon: Icons.visibility_outlined,
                      label: '${details.video.views} 次观看',
                    ),
                  if (details.video.rating != null)
                    _StatChip(
                      icon: Icons.thumb_up_alt_outlined,
                      label: details.ratingVotes == null
                          ? '${details.video.rating}%'
                          : '${details.video.rating}% · ${details.ratingVotes} 票',
                    ),
                  if (details.video.publishedLabel != null)
                    _StatChip(
                      icon: Icons.calendar_today_outlined,
                      label: details.video.publishedLabel!,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionButton(
                    icon: _favorite ? Icons.favorite : Icons.favorite_border,
                    label: _favorite ? '已收藏' : '收藏',
                    busy: _updatingFavorite,
                    onPressed: _toggleFavorite,
                  ),
                  _ActionButton(
                    icon: Icons.thumb_up_alt_outlined,
                    label: '喜欢',
                    busy: _updatingRating,
                    onPressed: () => _rate(true),
                  ),
                  _ActionButton(
                    icon: Icons.thumb_down_alt_outlined,
                    label: '不喜欢',
                    busy: _updatingRating,
                    onPressed: () => _rate(false),
                  ),
                  _ActionButton(
                    icon: Icons.playlist_add,
                    label: '播放列表',
                    busy: _addingPlaylist,
                    onPressed: _addToPlaylist,
                  ),
                  _ActionButton(
                    icon: Icons.download,
                    label: '下载',
                    busy: _addingDownload,
                    onPressed: details.sources.isEmpty ? null : _download,
                  ),
                  _ActionButton(
                    icon: Icons.share_outlined,
                    label: '分享',
                    busy: false,
                    onPressed: _share,
                  ),
                ],
              ),
              if (details.description != null) ...[
                const SizedBox(height: 24),
                Text('简介', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SelectableText(details.description!),
              ],
              _MetadataSection(
                title: '分类',
                items: metadata
                    .where((item) => item.kind == DiscoveryKind.category)
                    .toList(growable: false),
                fallbackValues: details.categories,
                subscribedPaths: _subscriptionPaths,
                updatingKeys: _updatingMetadata,
                onTap: _openMetadataActions,
              ),
              _MetadataSection(
                title: '标签',
                items: metadata
                    .where((item) => item.kind == DiscoveryKind.tag)
                    .toList(growable: false),
                fallbackValues: details.tags,
                subscribedPaths: _subscriptionPaths,
                updatingKeys: _updatingMetadata,
                onTap: _openMetadataActions,
              ),
              _MetadataSection(
                title: '艺术家',
                items: metadata
                    .where((item) => item.kind == DiscoveryKind.model)
                    .toList(growable: false),
                fallbackValues: details.models,
                subscribedPaths: _subscriptionPaths,
                updatingKeys: _updatingMetadata,
                onTap: _openMetadataActions,
              ),
              _CommentsSection(
                comments: details.comments,
                total: details.commentCount,
                loggedIn: widget.api.sessionStore.isLoggedIn,
                controller: _commentController,
                posting: _postingComment,
                onLogin: () async {
                  if (await _ensureLogin() && mounted) {
                    setState(() {});
                    await _loadSubscriptions();
                  }
                },
                onSubmit: _postComment,
                votingCommentIds: _votingComments,
                onVote: _voteComment,
              ),
              if (details.relatedVideos.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text('相关视频', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final video in details.relatedVideos)
                  VideoCard(
                    video: video,
                    onTap: () => context.pushNamed(
                      AppRouteNames.video,
                      pathParameters: {'id': video.id, 'slug': video.slug},
                      extra: video,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

enum _MetadataAction { open, subscription, upvote, downvote }

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 16), label: Text(label));
  }
}

class _MetadataSection extends StatelessWidget {
  const _MetadataSection({
    required this.title,
    required this.items,
    required this.fallbackValues,
    required this.subscribedPaths,
    required this.updatingKeys,
    required this.onTap,
  });

  final String title;
  final List<VideoMetadataItem> items;
  final List<String> fallbackValues;
  final Set<String> subscribedPaths;
  final Set<String> updatingKeys;
  final ValueChanged<VideoMetadataItem> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && fallbackValues.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.isEmpty
                ? fallbackValues
                      .take(40)
                      .map((value) => Chip(label: Text(value)))
                      .toList(growable: false)
                : items
                      .take(40)
                      .map((item) {
                        final subscribed = subscribedPaths.contains(item.path);
                        final busy = updatingKeys.any(
                          (key) => key.endsWith('${item.kind.name}:${item.id}'),
                        );
                        return ActionChip(
                          avatar: busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  subscribed
                                      ? Icons.notifications_active
                                      : _kindIcon(item.kind),
                                  size: 18,
                                ),
                          label: Text(item.title),
                          onPressed: busy ? null : () => onTap(item),
                        );
                      })
                      .toList(growable: false),
          ),
        ],
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

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({
    required this.comments,
    required this.total,
    required this.loggedIn,
    required this.controller,
    required this.posting,
    required this.onLogin,
    required this.onSubmit,
    required this.votingCommentIds,
    required this.onVote,
  });

  final List<VideoComment> comments;
  final int total;
  final bool loggedIn;
  final TextEditingController controller;
  final bool posting;
  final Future<void> Function() onLogin;
  final VoidCallback onSubmit;
  final Set<String> votingCommentIds;
  final void Function(VideoComment comment, bool upvote) onVote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('评论（$total）', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (loggedIn) ...[
            TextField(
              controller: controller,
              enabled: !posting,
              minLines: 2,
              maxLines: 5,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: '写下评论',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: posting ? null : onSubmit,
                icon: posting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('发表评论'),
              ),
            ),
          ] else
            OutlinedButton.icon(
              onPressed: onLogin,
              icon: const Icon(Icons.login),
              label: const Text('登录后评论'),
            ),
          const SizedBox(height: 12),
          if (comments.isEmpty)
            const Text('还没有评论。')
          else ...[
            for (final comment in comments)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundImage: comment.avatarUrl == null
                            ? null
                            : CachedNetworkImageProvider(comment.avatarUrl!),
                        child: comment.avatarUrl == null
                            ? const Icon(Icons.person_outline)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    comment.author,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
                                  ),
                                ),
                                if (comment.dateLabel != null)
                                  Text(
                                    comment.dateLabel!,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SelectableText(comment.text),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (votingCommentIds.contains(comment.id))
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                else ...[
                                  IconButton(
                                    tooltip: '赞同评论',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => onVote(comment, true),
                                    icon: const Icon(
                                      Icons.thumb_up_alt_outlined,
                                      size: 18,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '反对评论',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => onVote(comment, false),
                                    icon: const Icon(
                                      Icons.thumb_down_alt_outlined,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (total > comments.length)
              Text(
                '当前显示页面内的 ${comments.length} 条评论。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ],
      ),
    );
  }
}
