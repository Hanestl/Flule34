import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router/app_router.dart';
import '../../app/router/route_names.dart';
import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../../core/services/share_service.dart';
import '../../core/services/predictive_prefetch_service.dart';
import '../../shared/video_card.dart';
import '../../shared/video_collection_layout.dart';
import '../../shared/site_avatar.dart';
import '../auth/login_sheet.dart';
import '../downloads/data/download_repository.dart';
import '../library/data/local_library_repository.dart';
import '../library/local_library_picker.dart';
import '../library/playlist_picker.dart';
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

class _VideoDetailPageState extends ConsumerState<VideoDetailPage>
    with RouteAware {
  late Future<VideoDetails> _detailsFuture;
  final VideoPlayerHandle _playerHandle = VideoPlayerHandle();
  PageRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _loadDetails();
  }

  @override
  void didUpdateWidget(covariant VideoDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api || oldWidget.video.id != widget.video.id) {
      _detailsFuture = _loadDetails();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _route) {
      if (_route != null) {
        appRouteObserver.unsubscribe(this);
      }
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    if (shouldPauseVideoForRoutePush(_playerHandle.isFullScreen)) {
      _playerHandle.pause();
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  void _reload() {
    setState(() {
      _detailsFuture = _loadDetails(force: true);
    });
  }

  Future<VideoDetails> _loadDetails({bool force = false}) async {
    try {
      final details = await ref
          .read(predictivePrefetchServiceProvider)
          .runForeground(
            PredictivePrefetchKey.video(widget.video.id),
            () => force
                ? widget.api.refreshVideoDetails(widget.video)
                : widget.api.loadVideoDetails(widget.video),
            resumeDelay: const Duration(seconds: 3),
          );
      return details;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('视频详情')),
      body: FutureBuilder<VideoDetails>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _DetailLoading(video: widget.video);
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
            playerHandle: _playerHandle,
            localLibraryRepository: ref.watch(localLibraryRepositoryProvider),
          );
        },
      ),
    );
  }
}

class _DetailLoading extends StatelessWidget {
  const _DetailLoading({required this.video});

  static const _headers = <String, String>{
    'Referer': 'https://rule34video.com/',
    'User-Agent': 'Flule34 Android/1.4.5',
  };

  final VideoItem video;

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = video.thumbnailUrl;
    return Align(
      alignment: Alignment.topCenter,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbnailUrl != null)
                CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  httpHeaders: _headers,
                  fit: BoxFit.cover,
                  errorWidget: (context, _, _) => const SizedBox.shrink(),
                ),
              const ColoredBox(color: Colors.black38),
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool shouldPauseVideoForRoutePush(bool isFullScreen) => !isFullScreen;

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
    required this.playerHandle,
    required this.localLibraryRepository,
  });

  final Rule34VideoApi api;
  final VideoDetails details;
  final DownloadRepository downloads;
  final AppSettingsRepository settings;
  final ShareService shareService;
  final VideoPlayerHandle playerHandle;
  final LocalLibraryRepository localLibraryRepository;

  @override
  State<_VideoDetailsBody> createState() => _VideoDetailsBodyState();
}

class _VideoDetailsBodyState extends State<_VideoDetailsBody> {
  late VideoDetails _details;
  late bool _favorite;
  final Set<String> _subscriptionPaths = {};
  final Set<String> _updatingMetadata = {};
  var _updatingFavorite = false;
  var _addingDownload = false;
  var _addingPlaylist = false;
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

  Future<void> _share() async {
    try {
      await widget.shareService.shareVideo(_details.video);
    } catch (error) {
      if (mounted) {
        _showMessage('无法打开分享面板：$error');
      }
    }
  }

  Future<void> _addToLocalLibrary() async {
    try {
      final message = await manageVideoLocalLibraries(
        context: context,
        repository: widget.localLibraryRepository,
        video: _details.video,
      );
      if (message != null && mounted) {
        _showMessage(message);
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    }
  }

  Future<void> _addToPlaylist() async {
    if (_addingPlaylist || !await _ensureLogin() || !mounted) {
      return;
    }
    setState(() => _addingPlaylist = true);
    try {
      final message = await manageVideoAccountPlaylists(
        context: context,
        api: widget.api,
        video: _details.video,
      );
      if (message != null && mounted) {
        _showMessage(message);
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    final metadata = details.metadataItems;
    final player = details.sources.isNotEmpty
        ? VideoPlayerPage(
            api: widget.api,
            video: details.video,
            sources: details.sources,
            embedded: true,
            autoplay: true,
            handle: widget.playerHandle,
          )
        : const AspectRatio(
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
          );
    return Column(
      children: [
        player,
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
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
                          icon: _favorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          label: _favorite ? '已收藏' : '收藏',
                          busy: _updatingFavorite,
                          onPressed: _toggleFavorite,
                        ),
                        _ActionButton(
                          icon: Icons.download,
                          label: '下载',
                          busy: _addingDownload,
                          onPressed: details.sources.isEmpty ? null : _download,
                        ),
                        _ActionButton(
                          icon: Icons.library_add_outlined,
                          label: '本地分类库',
                          busy: false,
                          onPressed: _addToLocalLibrary,
                        ),
                        _ActionButton(
                          icon: Icons.playlist_add,
                          label: '播放列表',
                          busy: _addingPlaylist,
                          onPressed: _addToPlaylist,
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
                      Text(
                        '简介',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
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
                    if (details.uploader case final uploader?) ...[
                      const SizedBox(height: 24),
                      Text(
                        '上传者',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: SiteAvatar(
                            imageUrl: uploader.avatarUrl,
                            fallbackIcon: Icons.person_outline,
                          ),
                          title: Row(
                            children: [
                              Flexible(child: Text(uploader.name)),
                              if (uploader.verified) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.verified,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.pushNamed(
                            AppRouteNames.uploader,
                            pathParameters: {'id': uploader.id},
                            queryParameters: {'name': uploader.name},
                            extra: uploader,
                          ),
                        ),
                      ),
                    ],
                    if (details.relatedVideos.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Text(
                        '相关视频',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ListenableBuilder(
                        listenable: widget.settings,
                        builder: (context, _) => VideoCollectionBox(
                          layout: widget.settings.settings.videoLayout,
                          itemCount: details.relatedVideos.length,
                          itemBuilder: (context, index, compact) {
                            final video = details.relatedVideos[index];
                            return VideoCard(
                              video: video,
                              compact: compact,
                              onTap: () async {
                                await widget.playerHandle.pause();
                                if (!context.mounted) {
                                  return;
                                }
                                context.pushNamed(
                                  AppRouteNames.video,
                                  pathParameters: {
                                    'id': video.id,
                                    'slug': video.slug,
                                  },
                                  extra: video,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _MetadataAction { open, subscription }

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
                          avatar: _metadataAvatar(
                            context,
                            item: item,
                            subscribed: subscribed,
                            busy: busy,
                          ),
                          label: Text(_metadataLabel(item)),
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

  Widget _metadataAvatar(
    BuildContext context, {
    required VideoMetadataItem item,
    required bool subscribed,
    required bool busy,
  }) {
    if (busy) {
      return const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final avatar = item.thumbnailUrl == null
        ? Icon(_kindIcon(item.kind), size: 18)
        : SiteAvatar(
            imageUrl: item.thumbnailUrl,
            radius: 9,
            fallbackIcon: _kindIcon(item.kind),
          );
    if (!subscribed) {
      return avatar;
    }
    return SizedBox.square(
      dimension: 20,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: avatar),
          Positioned(
            right: -3,
            bottom: -3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.notifications, size: 8, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _metadataLabel(VideoMetadataItem item) {
    if (item.upScore == 0 && item.downScore == 0) {
      return item.title;
    }
    return '${item.title} · ↑${item.upScore} ↓${item.downScore}';
  }
}
