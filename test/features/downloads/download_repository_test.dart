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
  test('未登录也可将视频直接加入公共目录下载', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final platform = _FakeDownloadPlatformService();
    final settings = await _createSettings(wifiOnlyDownloads: true);
    final repository = DownloadRepository(
      harness.database,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    addTearDown(settings.dispose);
    await repository.initialize();

    final id = await repository.enqueueVideo(
      details: _details,
      source: _details.sources.single,
    );

    expect(id, 'flule34_4505897_720p');
    expect(platform.defaultDirectoryPicks, 1);
    expect(platform.requests, hasLength(1));
    expect(
      platform.requests.single.directoryUri,
      Uri.parse('content://downloads/Flule34'),
    );
    expect(platform.requests.single.requiresWiFi, isTrue);
    expect(platform.requests.single.headers['Cookie'], 'PHPSESSID=test-cookie');
    expect(settings.settings.downloadDirectoryLabel, 'Downloads/Flule34');
  });

  test('已保存目录会先恢复授权再下载', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final platform = _FakeDownloadPlatformService();
    final settings = await _createSettings();
    await settings.setDownloadDirectory(
      uri: 'content://custom/videos',
      label: 'Movies / Flule34',
    );
    final repository = DownloadRepository(
      harness.database,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    addTearDown(settings.dispose);
    await repository.initialize();

    await repository.enqueueVideo(
      details: _details,
      source: _details.sources.single,
    );

    expect(platform.activatedDirectories, [
      Uri.parse('content://custom/videos'),
    ]);
    expect(platform.defaultDirectoryPicks, 0);
    expect(
      platform.requests.single.directoryUri,
      Uri.parse('content://custom/videos'),
    );
  });

  test('平台进度和完成文件 URI 会写入数据库', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final platform = _FakeDownloadPlatformService();
    final settings = await _createSettings();
    final repository = DownloadRepository(
      harness.database,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    addTearDown(settings.dispose);
    await repository.initialize();
    final id = await repository.enqueueVideo(
      details: _details,
      source: _details.sources.single,
    );

    platform.emit(
      DownloadProgressEvent(taskId: id, bytesDownloaded: 512, totalBytes: 1024),
    );
    platform.emit(
      DownloadStatusEvent(
        taskId: id,
        state: DownloadTaskState.complete,
        filePath: 'content://downloads/Flule34/video.mp4',
      ),
    );
    await _waitFor(() async {
      return (await harness.database.findDownloadRecord(id))?.state ==
          'complete';
    });

    final record = await harness.database.findDownloadRecord(id);
    expect(record?.bytesDownloaded, 512);
    expect(record?.totalBytes, 1024);
    expect(record?.filePath, 'content://downloads/Flule34/video.mp4');
    expect(record?.completedAt, isNotNull);
  });

  test('通知权限被拒绝或目录授权失效时不会入队', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final platform = _FakeDownloadPlatformService()..permissionGranted = false;
    final settings = await _createSettings();
    final repository = DownloadRepository(
      harness.database,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    addTearDown(settings.dispose);
    await repository.initialize();

    await expectLater(
      repository.enqueueVideo(
        details: _details,
        source: _details.sources.single,
      ),
      throwsA(isA<DownloadException>()),
    );
    expect(platform.requests, isEmpty);

    platform.permissionGranted = true;
    await settings.setDownloadDirectory(
      uri: 'content://expired/path',
      label: '失效目录',
    );
    platform.activationSucceeds = false;
    await expectLater(
      repository.enqueueVideo(
        details: _details,
        source: _details.sources.single,
      ),
      throwsA(isA<DownloadException>()),
    );
    expect(platform.requests, isEmpty);
  });

  test('完成文件可以播放并从公共目录删除', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final platform = _FakeDownloadPlatformService();
    final settings = await _createSettings();
    final repository = DownloadRepository(
      harness.database,
      _FakeRule34VideoApi(harness.sessionStore),
      platform,
      settings,
    );
    addTearDown(repository.dispose);
    addTearDown(settings.dispose);
    await repository.initialize();
    final id = await repository.enqueueVideo(
      details: _details,
      source: _details.sources.single,
    );
    platform.emit(
      DownloadStatusEvent(
        taskId: id,
        state: DownloadTaskState.complete,
        filePath: 'content://downloads/Flule34/video.mp4',
      ),
    );
    await _waitFor(() async {
      return (await harness.database.findDownloadRecord(id))?.state ==
          'complete';
    });
    final record = (await harness.database.findDownloadRecord(id))!;

    expect(await repository.open(record), isTrue);
    expect(platform.openedUris, ['content://downloads/Flule34/video.mp4']);
    expect(await repository.delete(record), isTrue);
    expect(platform.deletedUris[id], 'content://downloads/Flule34/video.mp4');
    expect(await harness.database.findDownloadRecord(id), isNull);
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

  var detailLoads = 0;

  @override
  Future<String?> sessionCookieHeader() async => 'PHPSESSID=test-cookie';

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

final class _FakeDownloadPlatformService implements DownloadPlatformService {
  final StreamController<DownloadPlatformEvent> _events =
      StreamController<DownloadPlatformEvent>.broadcast();
  final List<DownloadRequest> requests = [];
  final List<Uri> activatedDirectories = [];
  final List<String> openedUris = [];
  final Map<String, String?> deletedUris = {};
  final List<int> maxConcurrentValues = [];
  var defaultDirectoryPicks = 0;
  var permissionGranted = true;
  var activationSucceeds = true;

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
  Future<DownloadDirectorySelection?> pickDefaultDirectory() async {
    defaultDirectoryPicks += 1;
    return DownloadDirectorySelection(
      uri: Uri.parse('content://downloads/Flule34'),
      label: 'Downloads/Flule34',
    );
  }

  @override
  Future<DownloadDirectorySelection?> pickCustomDirectory() async {
    return DownloadDirectorySelection(
      uri: Uri.parse('content://custom/videos'),
      label: '自定义目录',
    );
  }

  @override
  Future<Uri?> activateDirectory(Uri uri) async {
    activatedDirectories.add(uri);
    return activationSucceeds ? uri : null;
  }

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
  Future<bool> cancel(String taskId) async => true;

  @override
  Future<bool> openFile(String fileUri) async {
    openedUris.add(fileUri);
    return true;
  }

  @override
  Future<bool> delete({required String taskId, String? fileUri}) async {
    deletedUris[taskId] = fileUri;
    return true;
  }

  @override
  void dispose() {
    unawaited(_events.close());
  }
}
