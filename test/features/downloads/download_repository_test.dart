import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flule34/core/api/rule34video_api.dart';
import 'package:flule34/core/database/app_database.dart';
import 'package:flule34/core/models/video_models.dart';
import 'package:flule34/core/session/session_store.dart';
import 'package:flule34/features/downloads/data/download_repository.dart';
import 'package:flule34/features/downloads/domain/download_models.dart';
import 'package:flule34/features/settings/data/app_settings_repository.dart';
import 'package:flule34/features/settings/data/app_settings_store.dart';

import '../../helpers/test_session_harness.dart';

void main() {
  test('未登录也可将视频加入固定公共下载目录', () async {
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
    expect(platform.sharedStoragePermissionChecks, 1);
    expect(platform.requests, hasLength(1));
    expect(platform.requests.single.requiresWiFi, isTrue);
    expect(platform.requests.single.headers['Cookie'], 'PHPSESSID=test-cookie');
    expect(platform.requests.single.filename, '测试视频_4505897_720p.mp4');
    final record = await harness.database.findDownloadRecord(id);
    expect(record?.thumbnailUrl, 'https://example.com/preview.jpg');
    expect(record?.fileName, '测试视频_4505897_720p.mp4');
  });

  test('通知权限或公共目录权限被拒绝时不会入队', () async {
    final harness = TestSessionHarness.create();
    addTearDown(harness.dispose);
    await harness.sessionStore.load();
    final platform = _FakeDownloadPlatformService()
      ..notificationPermissionGranted = false;
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
    expect(platform.sharedStoragePermissionChecks, 0);

    platform.notificationPermissionGranted = true;
    platform.sharedStoragePermissionGranted = false;
    await expectLater(
      repository.enqueueVideo(
        details: _details,
        source: _details.sources.single,
      ),
      throwsA(isA<DownloadException>()),
    );
    expect(platform.requests, isEmpty);
    expect(platform.sharedStoragePermissionChecks, 1);
  });

  test('完成事件使用实际文件大小并保存公共文件 URI', () async {
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
        filePath: _fileUri,
        actualBytes: 2048,
      ),
    );
    await _waitFor(() async {
      return (await harness.database.findDownloadRecord(id))?.state ==
          DownloadTaskState.complete.storageValue;
    });

    final record = await harness.database.findDownloadRecord(id);
    expect(record?.bytesDownloaded, 2048);
    expect(record?.totalBytes, 2048);
    expect(record?.filePath, _fileUri);
    expect(record?.completedAt, isNotNull);
  });

  test('完成文件必须同时满足存在、可读、文件名和体积一致', () async {
    final context = await _completedDownload();
    addTearDown(context.dispose);
    final record = context.record;
    final platform = context.platform;

    platform.inspections[_fileUri] = DownloadFileInspection(
      exists: true,
      readable: true,
      name: record.fileName,
      size: record.totalBytes,
    );
    expect((await context.repository.validateFile(record)).valid, isTrue);

    platform.inspections[_fileUri] = const DownloadFileInspection(
      exists: false,
      readable: false,
    );
    var validation = await context.repository.validateFile(record);
    expect(validation.valid, isFalse);
    expect(validation.reason, '外部文件已不存在。');

    platform.inspections[_fileUri] = DownloadFileInspection(
      exists: true,
      readable: true,
      name: '${record.fileName}.renamed',
      size: record.totalBytes,
    );
    validation = await context.repository.validateFile(record);
    expect(validation.valid, isFalse);
    expect(validation.reason, '外部文件已被改名。');

    platform.inspections[_fileUri] = DownloadFileInspection(
      exists: true,
      readable: true,
      name: record.fileName,
      size: record.totalBytes! + 1,
    );
    validation = await context.repository.validateFile(record);
    expect(validation.valid, isFalse);
    expect(validation.reason, '外部文件大小已发生变化。');
  });

  test('失效文件不能播放，删除记录时不触碰外部文件', () async {
    final context = await _completedDownload();
    addTearDown(context.dispose);
    final record = context.record;
    context.platform.inspections[_fileUri] = const DownloadFileInspection(
      exists: false,
      readable: false,
    );

    expect(await context.repository.open(record), isFalse);
    expect(context.platform.openedUris, isEmpty);
    expect(await context.repository.delete(record), isTrue);
    expect(context.platform.deleteExternalFlags[record.id], isFalse);
    expect(
      await context.harness.database.findDownloadRecord(record.id),
      isNull,
    );
  });

  test('有效完成文件可以播放并从公共目录删除', () async {
    final context = await _completedDownload();
    addTearDown(context.dispose);
    final record = context.record;
    context.platform.inspections[_fileUri] = DownloadFileInspection(
      exists: true,
      readable: true,
      name: record.fileName,
      size: record.totalBytes,
    );

    expect(await context.repository.open(record), isTrue);
    expect(context.platform.openedUris, [_fileUri]);
    expect(await context.repository.delete(record), isTrue);
    expect(context.platform.deletedUris[record.id], _fileUri);
    expect(context.platform.deleteExternalFlags[record.id], isTrue);
  });

  test('批量仅删除记录会保留公共目录视频', () async {
    final context = await _completedDownload();
    addTearDown(context.dispose);

    final result = await context.repository.deleteAll(
      DownloadBulkDeleteMode.recordsOnly,
    );

    expect(result.matched, 1);
    expect(result.deleted, 1);
    expect(result.failed, 0);
    expect(context.platform.deleteExternalFlags[context.record.id], isFalse);
  });

  test('批量删除失效记录只匹配校验失败的完成任务', () async {
    final context = await _completedDownload();
    addTearDown(context.dispose);
    context.platform.inspections[_fileUri] = const DownloadFileInspection(
      exists: false,
      readable: false,
    );

    final result = await context.repository.deleteAll(
      DownloadBulkDeleteMode.invalidRecords,
    );

    expect(result.matched, 1);
    expect(result.deleted, 1);
    expect(context.platform.deleteExternalFlags[context.record.id], isFalse);
  });

  test('批量删除记录及视频会请求删除公共文件', () async {
    final context = await _completedDownload();
    addTearDown(context.dispose);

    final result = await context.repository.deleteAll(
      DownloadBulkDeleteMode.filesAndRecords,
    );

    expect(result.deleted, 1);
    expect(context.platform.deletedUris[context.record.id], _fileUri);
    expect(context.platform.deleteExternalFlags[context.record.id], isTrue);
  });
}

const _fileUri = 'content://media/external/downloads/flule34_4505897_720p.mp4';

const _details = VideoDetails(
  video: VideoItem(
    id: '4505897',
    title: '测试视频',
    slug: 'test-video',
    thumbnailUrl: 'https://example.com/320x180/4505897.jpg',
  ),
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

Future<_CompletedDownloadContext> _completedDownload() async {
  final harness = TestSessionHarness.create();
  await harness.sessionStore.load();
  final platform = _FakeDownloadPlatformService();
  final settings = await _createSettings();
  final repository = DownloadRepository(
    harness.database,
    _FakeRule34VideoApi(harness.sessionStore),
    platform,
    settings,
  );
  await repository.initialize();
  final id = await repository.enqueueVideo(
    details: _details,
    source: _details.sources.single,
  );
  platform.emit(
    DownloadStatusEvent(
      taskId: id,
      state: DownloadTaskState.complete,
      filePath: _fileUri,
      actualBytes: 2048,
    ),
  );
  await _waitFor(() async {
    return (await harness.database.findDownloadRecord(id))?.state ==
        DownloadTaskState.complete.storageValue;
  });
  return _CompletedDownloadContext(
    harness: harness,
    settings: settings,
    platform: platform,
    repository: repository,
    record: (await harness.database.findDownloadRecord(id))!,
  );
}

final class _CompletedDownloadContext {
  const _CompletedDownloadContext({
    required this.harness,
    required this.settings,
    required this.platform,
    required this.repository,
    required this.record,
  });

  final TestSessionHarness harness;
  final AppSettingsRepository settings;
  final _FakeDownloadPlatformService platform;
  final DownloadRepository repository;
  final DownloadRecord record;

  void dispose() {
    repository.dispose();
    settings.dispose();
    harness.dispose();
  }
}

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
  final List<String> openedUris = [];
  final Map<String, String?> deletedUris = {};
  final Map<String, bool> deleteExternalFlags = {};
  final Map<String, DownloadFileInspection> inspections = {};
  final List<int> maxConcurrentValues = [];
  var notificationPermissionGranted = true;
  var sharedStoragePermissionGranted = true;
  var sharedStoragePermissionChecks = 0;

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
  Future<bool> ensureNotificationPermission() async =>
      notificationPermissionGranted;

  @override
  Future<bool> ensureSharedStoragePermission() async {
    sharedStoragePermissionChecks += 1;
    return sharedStoragePermissionGranted;
  }

  @override
  Future<bool> enqueue(DownloadRequest request) async {
    requests.add(request);
    return true;
  }

  @override
  Future<bool> cancel(String taskId) async => true;

  @override
  Future<bool> openFile(String fileUri) async {
    openedUris.add(fileUri);
    return true;
  }

  @override
  Future<DownloadFileInspection> inspectFile(String fileUri) async {
    return inspections[fileUri] ??
        const DownloadFileInspection(exists: false, readable: false);
  }

  @override
  Future<bool> delete({
    required String taskId,
    String? fileUri,
    bool deleteExternalFile = true,
  }) async {
    deletedUris[taskId] = fileUri;
    deleteExternalFlags[taskId] = deleteExternalFile;
    return true;
  }

  @override
  void dispose() {
    unawaited(_events.close());
  }
}
