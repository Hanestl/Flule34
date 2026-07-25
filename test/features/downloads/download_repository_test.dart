import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/features/downloads/data/download_repository.dart';
import 'package:flule34/features/downloads/domain/download_models.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  test('下载任务按账号入队并将平台进度写入数据库', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');

    final platform = _FakeDownloadPlatformService();
    final api = _FakeRule34VideoApi(harness.sessionStore);
    final settings = await _createSettings(wifiOnlyDownloads: true);
    addTearDown(settings.dispose);
    final repository = DownloadRepository(
      harness.database,
      harness.sessionStore,
      api,
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    await repository.initialize();

    final id = await repository.enqueueVideo(
      details: _details,
      source: _details.sources.single,
    );

    expect(platform.requests, hasLength(1));
    expect(platform.requests.single.directory, 'downloads/2421071');
    expect(platform.requests.single.requiresWiFi, isTrue);
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
    final settings = await _createSettings();
    addTearDown(settings.dispose);
    final repository = DownloadRepository(
      harness.database,
      harness.sessionStore,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
      settings,
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
    final settings = await _createSettings();
    addTearDown(settings.dispose);
    final repository = DownloadRepository(
      harness.database,
      harness.sessionStore,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
      settings,
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

  test('删除下载会先清理平台文件再删除数据库记录', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');
    final platform = _FakeDownloadPlatformService();
    final settings = await _createSettings();
    addTearDown(settings.dispose);
    final repository = DownloadRepository(
      harness.database,
      harness.sessionStore,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    await repository.initialize();
    final id = await repository.enqueueVideo(
      details: _details,
      source: _details.sources.single,
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

    final record = (await harness.database.findDownloadRecord(id))!;
    expect(await repository.delete(record), isTrue);

    expect(platform.deletedIds, contains(id));
    expect(platform.deletedDirectories[id], 'downloads/2421071');
    expect(platform.deletedPaths[id], 'downloads/2421071/video.mp4');
    expect(await harness.database.findDownloadRecord(id), isNull);
  });

  test('已完成下载可以导出到公共下载目录', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');
    final platform = _FakeDownloadPlatformService();
    final settings = await _createSettings();
    addTearDown(settings.dispose);
    final repository = DownloadRepository(
      harness.database,
      harness.sessionStore,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    await repository.initialize();
    final id = await repository.enqueueVideo(
      details: _details,
      source: _details.sources.single,
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

    final record = (await harness.database.findDownloadRecord(id))!;
    final exportedPath = await repository.export(record);
    expect(exportedPath, 'Downloads/Flule34/video.mp4');
    expect(await repository.openExported(exportedPath!), isTrue);
    expect(platform.openedPaths, ['Downloads/Flule34/video.mp4']);
    expect(
      (await harness.database.findDownloadRecord(id))?.filePath,
      'downloads/2421071/video.mp4',
    );
  });

  test('清理当前账号本地数据会删除下载和播放进度但保留账号', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');
    final platform = _FakeDownloadPlatformService();
    final settings = await _createSettings();
    addTearDown(settings.dispose);
    final repository = DownloadRepository(
      harness.database,
      harness.sessionStore,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    await repository.initialize();
    final id = await repository.enqueueVideo(
      details: _details,
      source: _details.sources.single,
    );
    await harness.database.savePlaybackPosition(
      userId: '2421071',
      videoId: _details.video.id,
      positionMs: 12000,
    );

    final result = await repository.clearCurrentUserData();

    expect(result.deletedDownloads, 1);
    expect(result.failedDownloads, 0);
    expect(await harness.database.findDownloadRecord(id), isNull);
    expect(
      await harness.database.findPlaybackPosition(
        userId: '2421071',
        videoId: _details.video.id,
      ),
      isNull,
    );
    expect(await harness.database.findAccount('2421071'), isNotNull);
  });

  test('令牌失效失败会刷新详情并自动重建下载任务', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');
    final platform = _FakeDownloadPlatformService();
    final api = _FakeRule34VideoApi(harness.sessionStore);
    final settings = await _createSettings();
    addTearDown(settings.dispose);
    final repository = DownloadRepository(
      harness.database,
      harness.sessionStore,
      api,
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    await repository.initialize();
    final id = await repository.enqueueVideo(
      details: _details,
      source: _details.sources.single,
    );

    platform.emit(
      DownloadStatusEvent(
        taskId: id,
        state: DownloadTaskState.failed,
        errorMessage: 'HTTP response 403 Forbidden',
      ),
    );
    await _waitFor(() async => platform.requests.length == 2);

    expect(api.detailLoads, 2);
    expect(platform.deletedIds, contains(id));
    expect(platform.requests.last.url, contains('token=2'));
    final record = await harness.database.findDownloadRecord(id);
    expect(record?.state, 'queued');
    expect(record?.errorMessage, isNull);
  });

  test('下载并发设置会同步到后台队列', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('2421071');
    final platform = _FakeDownloadPlatformService();
    final settings = await _createSettings();
    addTearDown(settings.dispose);
    final repository = DownloadRepository(
      harness.database,
      harness.sessionStore,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    await repository.initialize();

    await settings.setDownloadConcurrentTasks(3);
    await _waitFor(() async => platform.maxConcurrentValues.contains(3));

    expect(platform.maxConcurrentValues, containsAllInOrder([2, 3]));
  });

  test('刷新下载地址期间切换账号不会把任务串到其他账号', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    await harness.sessionStore.authenticate('1001');
    final platform = _FakeDownloadPlatformService();
    final api = _BlockingRule34VideoApi(harness.sessionStore);
    final settings = await _createSettings();
    addTearDown(settings.dispose);
    final repository = DownloadRepository(
      harness.database,
      harness.sessionStore,
      api,
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    await repository.initialize();

    final enqueue = repository.enqueueVideo(
      details: _details,
      source: _details.sources.single,
    );
    await api.requestStarted.future;
    await harness.sessionStore.authenticate('2002');
    api.details.complete(_details);

    await expectLater(enqueue, throwsA(isA<DownloadException>()));
    expect(platform.requests, isEmpty);
    expect(
      await harness.database.findVideoDownload(
        userId: '1001',
        videoId: _details.video.id,
        quality: _details.sources.single.label,
      ),
      isNull,
    );
    expect(
      await harness.database.findVideoDownload(
        userId: '2002',
        videoId: _details.video.id,
        quality: _details.sources.single.label,
      ),
      isNull,
    );
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

Future<AppSettingsRepository> _createSettings({
  bool wifiOnlyDownloads = false,
}) async {
  final repository = AppSettingsRepository(_MemorySettingsStore());
  await repository.load();
  if (wifiOnlyDownloads) {
    await repository.setWifiOnlyDownloads(true);
  }
  return repository;
}

final class _MemorySettingsStore implements AppSettingsStore {
  final Map<String, Object> _values = {};

  @override
  Future<bool?> readBool(String key) async => _values[key] as bool?;

  @override
  Future<String?> readString(String key) async => _values[key] as String?;

  @override
  Future<void> writeBool(String key, bool value) async {
    _values[key] = value;
  }

  @override
  Future<void> writeString(String key, String value) async {
    _values[key] = value;
  }
}

final class _FakeRule34VideoApi extends Rule34VideoApi {
  _FakeRule34VideoApi(SessionStore sessionStore)
    : super(sessionStore: sessionStore);

  @override
  Future<String?> sessionCookieHeader() async => 'PHPSESSID=test-cookie';

  int detailLoads = 0;

  @override
  Future<VideoDetails> loadVideoDetails(VideoItem video) async {
    detailLoads += 1;
    return VideoDetails(
      video: _details.video,
      sources: [
        VideoSource(
          label: '720p',
          url: 'https://rule34video.com/get_file/video.mp4?token=$detailLoads',
          isHd: true,
        ),
      ],
      categories: const [],
      tags: const [],
      models: const [],
      isFavorite: false,
    );
  }

  @override
  void close() {}
}

final class _BlockingRule34VideoApi extends Rule34VideoApi {
  _BlockingRule34VideoApi(SessionStore sessionStore)
    : super(sessionStore: sessionStore);

  final Completer<void> requestStarted = Completer<void>();
  final Completer<VideoDetails> details = Completer<VideoDetails>();

  @override
  Future<VideoDetails> loadVideoDetails(VideoItem video) {
    if (!requestStarted.isCompleted) {
      requestStarted.complete();
    }
    return details.future;
  }

  @override
  void close() {}
}

final class _FakeDownloadPlatformService implements DownloadPlatformService {
  final StreamController<DownloadPlatformEvent> _events =
      StreamController<DownloadPlatformEvent>.broadcast();

  final List<DownloadRequest> requests = [];
  final Set<String> canceledIds = {};
  final Set<String> deletedIds = {};
  final Map<String, String> deletedDirectories = {};
  final Map<String, String?> deletedPaths = {};
  final List<int> maxConcurrentValues = [];
  final List<String> openedPaths = [];
  bool permissionGranted = true;
  String? exportedPath = 'Downloads/Flule34/video.mp4';

  @override
  Stream<DownloadPlatformEvent> get events => _events.stream;

  void emit(DownloadPlatformEvent event) => _events.add(event);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> setMaxConcurrent(int value) async {
    maxConcurrentValues.add(value);
  }

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
  Future<bool> openFile(String filePath) async {
    openedPaths.add(filePath);
    return true;
  }

  @override
  Future<String?> exportToDownloads(String taskId) async => exportedPath;

  @override
  Future<bool> delete({
    required String taskId,
    required String directory,
    String? filePath,
  }) async {
    deletedIds.add(taskId);
    deletedDirectories[taskId] = directory;
    deletedPaths[taskId] = filePath;
    return true;
  }

  @override
  void dispose() {
    unawaited(_events.close());
  }
}
