import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/database/app_database.dart';
import '../data/download_repository.dart';
import '../domain/download_models.dart';

class DownloadManagementPage extends StatefulWidget {
  const DownloadManagementPage({super.key, required this.repository});

  final DownloadRepository repository;

  @override
  State<DownloadManagementPage> createState() => _DownloadManagementPageState();
}

class _DownloadManagementPageState extends State<DownloadManagementPage> {
  var _bulkDeleting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('下载'),
        actions: [
          if (_bulkDeleting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: '批量删除',
              onPressed: _showBulkDelete,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          IconButton(
            tooltip: '下载设置',
            onPressed: () => context.pushNamed(AppRouteNames.downloadSettings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: DownloadsList(repository: widget.repository),
    );
  }

  Future<void> _showBulkDelete() async {
    final mode = await showModalBottomSheet<DownloadBulkDeleteMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.list_alt_outlined),
              title: const Text('删除全部下载记录'),
              subtitle: const Text('保留已经下载到公共目录的视频'),
              onTap: () =>
                  Navigator.pop(context, DownloadBulkDeleteMode.recordsOnly),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除全部失效下载记录'),
              subtitle: const Text('只移除已经找不到对应文件的记录'),
              onTap: () =>
                  Navigator.pop(context, DownloadBulkDeleteMode.invalidRecords),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              title: const Text('删除全部下载记录及对应视频'),
              subtitle: const Text('同时删除公共目录中仍能对应上的视频'),
              onTap: () => Navigator.pop(
                context,
                DownloadBulkDeleteMode.filesAndRecords,
              ),
            ),
          ],
        ),
      ),
    );
    if (mode == null || !mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认批量删除？'),
        content: Text(_bulkDeleteDescription(mode)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _bulkDeleting = true);
    try {
      final result = await widget.repository.deleteAll(mode);
      if (!mounted) {
        return;
      }
      final message = result.matched == 0
          ? '没有符合条件的下载记录。'
          : result.failed > 0
          ? '已删除 ${result.deleted} 条，${result.failed} 条未能删除。'
          : '已删除 ${result.deleted} 条下载记录。';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _bulkDeleting = false);
      }
    }
  }

  String _bulkDeleteDescription(DownloadBulkDeleteMode mode) {
    return switch (mode) {
      DownloadBulkDeleteMode.recordsOnly =>
        '只删除 App 中的全部下载记录，已经保存到 Download/Flule34 的视频会保留。进行中的任务会先取消。',
      DownloadBulkDeleteMode.invalidRecords => '删除全部已经找不到严格对应文件的下载记录，不会触碰外部文件。',
      DownloadBulkDeleteMode.filesAndRecords =>
        '删除全部下载记录，并删除公共目录中仍能对应上的视频。无法删除文件的记录会保留。',
    };
  }
}

class DownloadsList extends StatelessWidget {
  const DownloadsList({super.key, required this.repository});

  final DownloadRepository repository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DownloadRecord>>(
      stream: repository.watchCurrentUserDownloads(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final records = snapshot.requireData;
        if (records.isEmpty) {
          return const Center(child: Text('还没有下载任务。'));
        }
        final completed = records.where((item) => item.state == 'complete');
        final storedBytes = completed.fold<int>(
          0,
          (total, item) => total + (item.totalBytes ?? item.bytesDownloaded),
        );
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: records.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: Text(
                  '共 ${records.length} 个任务 · 已完成 ${completed.length} 个 · 约占用 ${_formatBytes(storedBytes)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }
            return _DownloadCard(
              record: records[index - 1],
              repository: repository,
            );
          },
        );
      },
    );
  }
}

class _DownloadCard extends StatefulWidget {
  const _DownloadCard({required this.record, required this.repository});

  final DownloadRecord record;
  final DownloadRepository repository;

  @override
  State<_DownloadCard> createState() => _DownloadCardState();
}

class _DownloadCardState extends State<_DownloadCard>
    with WidgetsBindingObserver {
  var _busy = false;
  late Future<DownloadFileValidation> _validation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _validation = widget.repository.validateFile(widget.record);
  }

  @override
  void didUpdateWidget(covariant _DownloadCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.updatedAt != widget.record.updatedAt ||
        oldWidget.record.filePath != widget.record.filePath) {
      _reloadValidation();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadValidation();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _reloadValidation() {
    if (mounted) {
      setState(() {
        _validation = widget.repository.validateFile(widget.record);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DownloadFileValidation>(
      future: _validation,
      builder: (context, snapshot) {
        final validation = snapshot.data;
        final validating =
            widget.record.state == 'complete' &&
            snapshot.connectionState != ConnectionState.done;
        final invalid =
            widget.record.state == 'complete' && validation?.valid == false;
        return _buildCard(
          validation: validation,
          validating: validating,
          invalid: invalid,
        );
      },
    );
  }

  Widget _buildCard({
    required DownloadFileValidation? validation,
    required bool validating,
    required bool invalid,
  }) {
    final record = widget.record;
    final totalBytes = record.totalBytes ?? 0;
    final progress = switch (record.state) {
      'complete' => 1.0,
      _ when totalBytes > 0 => (record.bytesDownloaded / totalBytes).clamp(
        0.0,
        1.0,
      ),
      _ => null,
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DownloadCover(record: record),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                if (progress != null)
                  LinearProgressIndicator(
                    value: invalid ? 0 : progress,
                    color: invalid ? Theme.of(context).colorScheme.error : null,
                  )
                else if (_isActive(record.state))
                  const LinearProgressIndicator(),
                const SizedBox(height: 7),
                Text(
                  _statusText(
                    record,
                    validation: validation,
                    validating: validating,
                    invalid: invalid,
                  ),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: invalid ? Theme.of(context).colorScheme.error : null,
                  ),
                ),
                if (invalid && validation?.reason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    validation!.reason!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (record.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    record.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildActions(
                    validation: validation,
                    validating: validating,
                    invalid: invalid,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions({
    required DownloadFileValidation? validation,
    required bool validating,
    required bool invalid,
  }) {
    final record = widget.record;
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Wrap(
      children: [
        if (record.state == 'failed' || record.state == 'not_found')
          IconButton(
            tooltip: '刷新地址并重试',
            onPressed: () => _run(
              () => widget.repository.retry(record),
              successMessage: '已刷新视频地址并重新加入下载队列。',
            ),
            icon: const Icon(Icons.refresh),
          ),
        if (_isActive(record.state))
          IconButton(
            tooltip: '取消',
            onPressed: () => _run(() => widget.repository.cancel(record.id)),
            icon: const Icon(Icons.close),
          ),
        if (record.state == 'complete' && !invalid && !validating)
          IconButton(
            tooltip: '播放文件',
            onPressed: _open,
            icon: const Icon(Icons.play_circle_outline),
          ),
        IconButton(
          tooltip: invalid ? '移除失效记录' : '删除',
          onPressed: () => _confirmDelete(invalid: invalid),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }

  Future<void> _confirmDelete({required bool invalid}) async {
    final active = _isActive(widget.record.state);
    final choice = await showDialog<_DownloadDeleteChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(invalid ? '移除失效记录？' : '删除下载？'),
        content: Text(
          invalid
              ? '可以只移除 App 内记录，也可以尝试删除当前记录所指向的外部文件。'
              : active
              ? '当前任务会先被取消。你可以只删除记录，也可以同时清理未完成文件。'
              : '你可以只删除下载记录并保留视频，也可以同时删除公共目录中的视频。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_DownloadDeleteChoice.recordOnly),
            child: const Text('仅删除记录'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_DownloadDeleteChoice.fileAndRecord),
            child: const Text('删除文件和记录'),
          ),
        ],
      ),
    );
    if (choice != null) {
      final deleteFile = choice == _DownloadDeleteChoice.fileAndRecord;
      await _run(
        () => widget.repository.delete(
          widget.record,
          deleteExternalFile: deleteFile,
        ),
        successMessage: deleteFile ? '下载文件和记录已删除。' : '下载记录已删除。',
      );
    }
  }

  Future<void> _open() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final opened = await widget.repository.open(widget.record);
      if (!mounted) {
        return;
      }
      if (!opened) {
        _reloadValidation();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('下载文件已失效或没有可播放此 MP4 的应用。')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('打开下载失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _run(
    Future<bool> Function() action, {
    String? successMessage,
  }) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final success = await action();
      if (!mounted) {
        return;
      }
      final message = success ? successMessage : '操作未能完成，请稍后重试。';
      if (message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

enum _DownloadDeleteChoice { recordOnly, fileAndRecord }

class _DownloadCover extends StatelessWidget {
  const _DownloadCover({required this.record});

  final DownloadRecord record;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (record.thumbnailUrl case final url? when url.isNotEmpty)
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, _) => const ColoredBox(
                color: Color(0xff25252d),
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, _, _) => const _CoverPlaceholder(),
            )
          else
            const _CoverPlaceholder(),
          Positioned(
            left: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                child: Text(
                  record.quality,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xff25252d),
      child: Center(
        child: Icon(Icons.video_file_outlined, color: Colors.white54, size: 48),
      ),
    );
  }
}

String _statusText(
  DownloadRecord record, {
  required DownloadFileValidation? validation,
  required bool validating,
  required bool invalid,
}) {
  final total = record.totalBytes ?? validation?.actualBytes ?? 0;
  if (validating) {
    return '${_formatBytes(total)} · 正在校验';
  }
  if (invalid) {
    final size = validation?.actualBytes ?? total;
    return '${_formatBytes(size)} · 已失效';
  }
  if (record.state == 'complete') {
    return '${_formatBytes(total)} · 已下载';
  }
  if (_isActive(record.state) && total > 0) {
    return '${_formatBytes(record.bytesDownloaded)} / ${_formatBytes(total)}';
  }
  return _stateLabel(record.state);
}

bool _isActive(String state) {
  return const {
    'queued',
    'running',
    'waiting_to_retry',
    'paused',
  }.contains(state);
}

String _stateLabel(String state) => switch (state) {
  'queued' => '等待下载',
  'running' => '正在下载',
  'complete' => '已下载',
  'not_found' => '文件不存在',
  'failed' => '下载失败',
  'canceled' => '已取消',
  'waiting_to_retry' => '等待重试',
  'paused' => '已暂停',
  _ => state,
};

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}
