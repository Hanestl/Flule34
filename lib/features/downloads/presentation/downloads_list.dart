import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../data/download_repository.dart';

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
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: records.length,
          itemBuilder: (context, index) {
            return _DownloadCard(
              record: records[index],
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

class _DownloadCardState extends State<_DownloadCard> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final totalBytes = record.totalBytes ?? 0;
    final progress = totalBytes > 0
        ? (record.bytesDownloaded / totalBytes).clamp(0.0, 1.0)
        : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text('${record.quality} · ${_stateLabel(record.state)}'),
            const SizedBox(height: 8),
            if (progress != null) ...[
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 6),
              Text(
                '${_formatBytes(record.bytesDownloaded)} / ${_formatBytes(totalBytes)}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ] else if (_isActive(record.state))
              const LinearProgressIndicator(),
            if (record.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                record.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: _busy
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Wrap(
                      children: [
                        if (record.state == 'running')
                          IconButton(
                            tooltip: '暂停',
                            onPressed: () =>
                                _run(() => widget.repository.pause(record.id)),
                            icon: const Icon(Icons.pause),
                          ),
                        if (record.state == 'paused')
                          IconButton(
                            tooltip: '继续',
                            onPressed: () =>
                                _run(() => widget.repository.resume(record.id)),
                            icon: const Icon(Icons.play_arrow),
                          ),
                        if (_isActive(record.state))
                          IconButton(
                            tooltip: '取消',
                            onPressed: () =>
                                _run(() => widget.repository.cancel(record.id)),
                            icon: const Icon(Icons.close),
                          ),
                        if (record.state == 'complete' &&
                            record.filePath != null)
                          IconButton(
                            tooltip: '打开',
                            onPressed: () =>
                                _run(() => widget.repository.open(record)),
                            icon: const Icon(Icons.open_in_new),
                          ),
                        if (record.state == 'complete')
                          IconButton(
                            tooltip: '导出到下载目录',
                            onPressed: _export,
                            icon: const Icon(Icons.save_alt),
                          ),
                        IconButton(
                          tooltip: '删除',
                          onPressed: _confirmDelete,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final active = _isActive(widget.record.state);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除下载？'),
        content: Text(
          active ? '当前任务会被取消，临时文件、已下载文件和记录都会删除。' : '已下载文件和任务记录都会删除，此操作无法撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(
        () => widget.repository.delete(widget.record),
        successMessage: '下载文件和记录已删除。',
      );
    }
  }

  Future<void> _export() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final path = await widget.repository.export(widget.record);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            path == null ? '导出失败，请检查存储权限。' : '已导出到公共下载目录的 Flule34 文件夹。',
          ),
        ),
      );
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

  static bool _isActive(String state) {
    return const {
      'queued',
      'running',
      'waiting_to_retry',
      'paused',
    }.contains(state);
  }

  static String _stateLabel(String state) => switch (state) {
    'queued' => '等待下载',
    'running' => '正在下载',
    'complete' => '已完成',
    'not_found' => '文件不存在',
    'failed' => '下载失败',
    'canceled' => '已取消',
    'waiting_to_retry' => '等待重试',
    'paused' => '已暂停',
    _ => state,
  };

  static String _formatBytes(int bytes) {
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
}
