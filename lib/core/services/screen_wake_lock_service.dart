import 'package:wakelock_plus/wakelock_plus.dart';

abstract interface class ScreenWakeLockService {
  Future<void> setEnabled(bool enabled);
}

final class WakelockScreenWakeLockService implements ScreenWakeLockService {
  @override
  Future<void> setEnabled(bool enabled) {
    return WakelockPlus.toggle(enable: enabled);
  }
}
