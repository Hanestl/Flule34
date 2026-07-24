import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/features/downloads/data/download_repository.dart';
import 'package:flule34/features/downloads/domain/download_models.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  test('下载任务按账号入队并将平台进度写入数据库', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');

    final platform = _FakeDownloadPlatformService();
    final api = _FakeRule34VideoApi(harness.sessionStore);
    final repository = DownloadRepository(
      harness.database,
      harness.sessionStore,
      api,
      platform,
    );
    addTearDown(repository.dispose);
    await repository.initialize();

    final id = await repository.enqueueVideo(
      details: _details,
      source: _details.sources.single,
    );

    expect(platform.requests, hasLength(1));
    expect(platform.requests.single.directory, 'downloads/2421071');
    expect(platform.requests.single.headers['Cookie'], 'PHPSESSID=test-cookie');
    expect(
      platform.requests.single.headers['Referer'],
      'https://rule34video.com/',
    );

    platform.emit(
      DownloadProgressEvent(taskId: id, bytesDownloaded: 512, totalBytes: 1024),
    );
    platform.emit(
      DownloadStatusEvent(
        taskId: id,
        state: DownloadTaskState.complete,
        filePath: 'downloads/2421071/video.mp4',
      ),
    );
    await _waitFor(() async {
      final record = await harness.database.findDownloadRecord(id);
      return record?.state == 'complete';
    });

    final record = await harness.database.findDownloadRecord(id);
    expect(record?.bytesDownloaded, 512);
    expect(record?.totalBytes, 1024);
    expect(record?.filePath, 'downloads/2421071/video.mp4');
    expect(record?.completedAt, isNotNull);
  });

  test('退出登录会取消原账号的活动下载', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');

    final platform = _FakeDownloadPlatformService();
    final repository = DownloadRepository(
      harness.database,
      harness.sessionStore,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
    );
    addTearDown(repository.dispose);
    await repository.initialize();
    final id = await repository.enqueueVideo(
      details: _details,
      source: _details.sources.single,
    );

    await harness.sessionStore.clear();
    await _waitFor(() async => platform.canceledIds.contains(id));

    expect(platform.canceledIds, contains(id));
  });

  test('未登录或通知权限被拒绝时不会入队', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final platform = _FakeDownloadPlatformService();
    final repository = DownloadRepository(
      harness.database,
      harness.sessionStore,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
    );
    addTearDown(repository.dispose);
    await repository.initialize();

    await expectLater(
      repository.enqueueVideo(
        details: _details,
        source: _details.sources.single,
      ),
      throwsA(isA<DownloadException>()),
    );
    expect(platform.requests, isEmpty);

    await harness.sessionStore.authenticate('2421071');
    platform.permissionGranted = false;
    await expectLater(
      repository.enqueueVideo(
        details: _details,
        source: _details.sources.single,
      ),
      throwsA(isA<DownloadException>()),
    );
    expect(platform.requests, isEmpty);
  });
}

const _details = VideoDetails(
  video: VideoItem(id: '4505897', title: '测试视频', slug: 'test-video'),
  sources: [
    VideoSource(
      label: '720p',
      url: 'https://rule34video.com/get_file/video_720p.mp4?token=test',
      isHd: true,
    ),
  ],
  categories: [],
  tags: [],
  models: [],
  isFavorite: false,
);

Future<void> _waitFor(Future<bool> Function() condition) async {
  for (var attempt = 0; attempt < 50; attempt += 1) {
    if (await condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('等待异步状态更新超时。');
}

final class _FakeRule34VideoApi extends Rule34VideoApi {
  _FakeRule34VideoApi(SessionStore sessionStore)
    : super(sessionStore: sessionStore);

  @override
  Future<String?> sessionCookieHeader() async => 'PHPSESSID=test-cookie';

  @override
  void close() {}
}

final class _FakeDownloadPlatformService implements DownloadPlatformService {
  final StreamController<DownloadPlatformEvent> _events =
      StreamController<DownloadPlatformEvent>.broadcast();

  final List<DownloadRequest> requests = [];
  final Set<String> canceledIds = {};
  bool permissionGranted = true;

  @override
  Stream<DownloadPlatformEvent> get events => _events.stream;

  void emit(DownloadPlatformEvent event) => _events.add(event);

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> ensureNotificationPermission() async => permissionGranted;

  @override
  Future<bool> enqueue(DownloadRequest request) async {
    requests.add(request);
    return true;
  }

  @override
  Future<bool> pause(String taskId) async => true;

  @override
  Future<bool> resume(String taskId) async => true;

  @override
  Future<bool> cancel(String taskId) async {
    canceledIds.add(taskId);
    return true;
  }

  @override
  Future<bool> openFile(String filePath) async => true;

  @override
  void dispose() {
    unawaited(_events.close());
  }
}
