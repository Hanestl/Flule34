import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/services/external_link_service.dart';
import '../data/app_update_service.dart';

class StartupUpdateGate extends ConsumerStatefulWidget {
  const StartupUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StartupUpdateGate> createState() => _StartupUpdateGateState();
}

class _StartupUpdateGateState extends ConsumerState<StartupUpdateGate> {
  late final AppUpdateService _service;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _service = AppUpdateService();
    unawaited(_check());
  }

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }

  Future<void> _check() async {
    AppUpdateResult? result;
    try {
      final channel = ref
          .read(appSettingsRepositoryProvider)
          .settings
          .updateChannel;
      result = await _service
          .check(channel)
          .timeout(const Duration(seconds: 6));
    } on Object {
      result = null;
    }
    if (!mounted) {
      return;
    }
    setState(() => _ready = true);
    if (result?.status == AppUpdateStatus.updateAvailable &&
        result?.release != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_showUpdate(result!.release!));
        }
      });
    }
  }

  Future<void> _showUpdate(AppRelease release) async {
    final updateNow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.system_update_alt),
        title: Text('发现新版本 ${release.version}'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(release.title),
                if (release.notes?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(release.notes!),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
    if (updateNow != true || !mounted) {
      return;
    }
    try {
      await ExternalLinkService.open(release.apkUri ?? release.pageUri);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法打开更新链接：$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return widget.child;
    }
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
