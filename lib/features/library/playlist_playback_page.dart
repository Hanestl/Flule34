import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../video/video_player_page.dart';

enum PlaylistPlaybackMode {
  sequence('顺序播放'),
  repeatOne('单集循环'),
  repeatAll('列表循环');

  const PlaylistPlaybackMode(this.label);

  final String label;
}

class PlaylistPlaybackRequest {
  const PlaylistPlaybackRequest({
    required this.playlist,
    required this.videos,
    required this.initialIndex,
    required this.nextPage,
    required this.hasMore,
  });

  final PlaylistItem playlist;
  final List<VideoItem> videos;
  final int initialIndex;
  final int nextPage;
  final bool hasMore;
}

class PlaylistPlaybackPage extends StatefulWidget {
  const PlaylistPlaybackPage({
    super.key,
    required this.api,
    required this.request,
  });

  final Rule34VideoApi api;
  final PlaylistPlaybackRequest request;

  @override
  State<PlaylistPlaybackPage> createState() => _PlaylistPlaybackPageState();
}

class _PlaylistPlaybackPageState extends State<PlaylistPlaybackPage> {
  late final List<VideoItem> _videos;
  late int _index;
  late int _nextPage;
  late bool _hasMore;
  var _loadingMore = false;
  var _mode = PlaylistPlaybackMode.sequence;
  final Map<String, VideoDetails> _detailsCache = {};
  VideoDetails? _details;
  Object? _detailsError;
  var _loadingInitial = true;
  var _switchingVideo = false;
  final VideoPlayerHandle _playerHandle = VideoPlayerHandle();
  var _preloadOperation = 0;
  var _switchOperation = 0;

  VideoItem get _video => _videos[_index];

  @override
  void initState() {
    super.initState();
    _videos = List.of(widget.request.videos);
    _index = widget.request.initialIndex.clamp(0, _videos.length - 1);
    _nextPage = widget.request.nextPage;
    _hasMore = widget.request.hasMore;
    unawaited(_loadInitial());
  }

  Future<void> _loadInitial() async {
    try {
      final details = await widget.api.loadVideoDetails(_video);
      if (!mounted) {
        return;
      }
      _detailsCache[_video.id] = details;
      setState(() {
        _details = details;
        _detailsError = null;
        _loadingInitial = false;
      });
      unawaited(_preloadNext());
    } catch (error) {
      if (mounted) {
        setState(() {
          _detailsError = error;
          _loadingInitial = false;
        });
      }
    }
  }

  Future<void> _preloadNext() async {
    final operation = ++_preloadOperation;
    try {
      var next = _index + 1;
      if (next >= _videos.length && await _ensureNextLoaded()) {
        next = _index + 1;
      }
      if (next >= _videos.length &&
          _mode != PlaylistPlaybackMode.sequence &&
          _videos.length > 1) {
        next = 0;
      }
      if (next >= _videos.length || next == _index) {
        await _playerHandle.stopPreCache();
        return;
      }
      final details = await widget.api.loadVideoDetails(_videos[next]);
      if (!mounted || operation != _preloadOperation) {
        return;
      }
      _detailsCache[_videos[next].id] = details;
      unawaited(_preloadLookAheadDetails(next, operation));
      await _playerHandle.preCache(details, aggressive: true);
    } on Object {
      // 预加载失败不影响当前视频，切换时仍会正常重试。
    }
  }

  Future<void> _preloadLookAheadDetails(int current, int operation) async {
    var lookAhead = current + 1;
    if (lookAhead >= _videos.length &&
        _mode != PlaylistPlaybackMode.sequence &&
        _videos.length > 2) {
      lookAhead = 0;
    }
    if (lookAhead >= _videos.length ||
        lookAhead == _index ||
        _detailsCache.containsKey(_videos[lookAhead].id)) {
      return;
    }
    try {
      final details = await widget.api.loadVideoDetails(_videos[lookAhead]);
      if (mounted && operation == _preloadOperation) {
        _detailsCache[_videos[lookAhead].id] = details;
      }
    } on Object {
      // 再下一条只预取详情，失败不影响播放。
    }
  }

  @override
  void dispose() {
    _preloadOperation += 1;
    unawaited(_playerHandle.stopPreCache());
    super.dispose();
  }

  Future<bool> _ensureNextLoaded() async {
    if (_index + 1 < _videos.length) {
      return true;
    }
    if (!_hasMore || _loadingMore) {
      return false;
    }
    _loadingMore = true;
    try {
      final page = await widget.api.loadPlaylistVideos(
        widget.request.playlist,
        _nextPage,
      );
      final newItems = page
          .where((item) => !_videos.any((saved) => saved.id == item.id))
          .toList(growable: false);
      if (!mounted) {
        return false;
      }
      setState(() {
        _videos.addAll(newItems);
        _nextPage += 1;
        _hasMore = page.isNotEmpty && newItems.isNotEmpty;
      });
      return _index + 1 < _videos.length;
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _next({bool automatic = false}) async {
    if (await _ensureNextLoaded()) {
      await _setIndex(_index + 1);
      return;
    }
    if (_mode == PlaylistPlaybackMode.repeatAll && _videos.isNotEmpty) {
      await _setIndex(0);
      return;
    }
    if (!automatic && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已经是播放列表最后一个视频。')));
    }
  }

  void _previous() {
    if (_index > 0) {
      unawaited(_setIndex(_index - 1));
    }
  }

  Future<void> _setIndex(int value) async {
    if (value == _index || _switchingVideo) {
      return;
    }
    final operation = ++_switchOperation;
    _preloadOperation += 1;
    unawaited(_playerHandle.stopPreCache());
    setState(() => _switchingVideo = true);
    try {
      final target = _videos[value];
      final details =
          _detailsCache[target.id] ?? await widget.api.loadVideoDetails(target);
      if (!mounted || operation != _switchOperation) {
        return;
      }
      _detailsCache[target.id] = details;
      setState(() {
        _index = value;
        _details = details;
        _switchingVideo = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && operation == _switchOperation) {
          unawaited(_preloadNext());
        }
      });
    } catch (error) {
      if (mounted && operation == _switchOperation) {
        setState(() => _switchingVideo = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载下一视频失败：$error')));
      }
    }
  }

  void _onFinished() {
    if (_mode != PlaylistPlaybackMode.repeatOne) {
      unawaited(_next(automatic: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    return Scaffold(
      appBar: AppBar(title: Text(widget.request.playlist.title)),
      body: details == null
          ? _InitialPlaylistPlayerState(
              loading: _loadingInitial,
              error: _detailsError,
              onRetry: () {
                setState(() {
                  _loadingInitial = true;
                  _detailsError = null;
                });
                unawaited(_loadInitial());
              },
            )
          : Column(
              children: [
                Stack(
                  children: [
                    VideoPlayerPage(
                      api: widget.api,
                      video: details.video,
                      sources: details.sources,
                      embedded: true,
                      autoplay: true,
                      looping: _mode == PlaylistPlaybackMode.repeatOne,
                      resumePlayback: false,
                      onFinished: _onFinished,
                      handle: _playerHandle,
                    ),
                    if (_switchingVideo)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black26,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          details.video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('${_index + 1}/${_videos.length}'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<PlaylistPlaybackMode>(
                    segments: PlaylistPlaybackMode.values
                        .map(
                          (mode) => ButtonSegment(
                            value: mode,
                            label: Text(mode.label),
                          ),
                        )
                        .toList(growable: false),
                    selected: {_mode},
                    onSelectionChanged: (selection) {
                      setState(() => _mode = selection.single);
                      unawaited(_preloadNext());
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      tooltip: '上一个',
                      onPressed: _index > 0 ? _previous : null,
                      icon: const Icon(Icons.skip_previous),
                    ),
                    const SizedBox(width: 24),
                    IconButton.filledTonal(
                      tooltip: '下一个',
                      onPressed: _next,
                      icon: const Icon(Icons.skip_next),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _InitialPlaylistPlayerState extends StatelessWidget {
  const _InitialPlaylistPlayerState({
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final bool loading;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error?.toString() ?? '加载视频失败。', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
