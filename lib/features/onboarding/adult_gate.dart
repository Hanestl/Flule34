import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AdultConfirmationStore {
  Future<bool?> readConfirmed();

  Future<void> writeConfirmed(bool value);
}

final class SharedPreferencesAdultConfirmationStore
    implements AdultConfirmationStore {
  SharedPreferencesAdultConfirmationStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _confirmedKey = 'flule34.onboarding.adult_confirmed';

  final SharedPreferencesAsync _preferences;

  @override
  Future<bool?> readConfirmed() => _preferences.getBool(_confirmedKey);

  @override
  Future<void> writeConfirmed(bool value) {
    return _preferences.setBool(_confirmedKey, value);
  }
}

class AdultGate extends StatefulWidget {
  const AdultGate({super.key, required this.child, this.store});

  final Widget child;
  final AdultConfirmationStore? store;

  @override
  State<AdultGate> createState() => _AdultGateState();
}

class _AdultGateState extends State<AdultGate> {
  late final AdultConfirmationStore _store;
  bool? _confirmed;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? SharedPreferencesAdultConfirmationStore();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final confirmed = await _store.readConfirmed() ?? false;
      if (mounted) {
        setState(() => _confirmed = confirmed);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _confirmed = false;
          _loadError = '无法读取年龄确认状态；你仍可继续，但下次启动可能需要再次确认。';
        });
      }
    }
  }

  void _confirm() {
    if (_saving || _confirmed == true) {
      return;
    }
    setState(() {
      _saving = true;
      _confirmed = true;
      _loadError = null;
    });
    unawaited(_persistConfirmation());
  }

  Future<void> _persistConfirmation() async {
    try {
      await _store.writeConfirmed(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('年龄确认未能保存；本次可继续使用，但下次启动需要重新确认。')),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_confirmed == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_confirmed == true) {
      return widget.child;
    }
    return _AgeConfirmation(
      onConfirm: _confirm,
      saving: _saving,
      errorMessage: _loadError,
    );
  }
}

class _AgeConfirmation extends StatelessWidget {
  const _AgeConfirmation({
    required this.onConfirm,
    required this.saving,
    this.errorMessage,
  });

  final VoidCallback onConfirm;
  final bool saving;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 52,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '仅限成年人',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '本应用包含仅适合成年人的内容。继续即表示你已达到所在地区法定成年年龄，并同意遵守当地法律。',
                    textAlign: TextAlign.center,
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: saving ? null : onConfirm,
                    child: saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('我已年满法定成年年龄'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: SystemNavigator.pop,
                    child: const Text('退出应用'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
