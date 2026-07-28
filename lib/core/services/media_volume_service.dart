import 'package:flutter/services.dart';

abstract interface class MediaVolumeService {
  Future<double?> current();

  Future<void> setNormalized(double value);
}

final class PlatformMediaVolumeService implements MediaVolumeService {
  const PlatformMediaVolumeService();

  static const _channel = MethodChannel('com.hanestl.flule34/media_volume');

  @override
  Future<double?> current() async {
    try {
      final value = await _channel.invokeMethod<double>('current');
      return value?.clamp(0.0, 1.0).toDouble();
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> setNormalized(double value) async {
    try {
      await _channel.invokeMethod<void>('setNormalized', <String, double>{
        'value': value.clamp(0.0, 1.0).toDouble(),
      });
    } on PlatformException {
      // 非 Android 平台或系统拒绝调节时，手势静默降级。
    } on MissingPluginException {
      // 单元测试和非 Android 平台没有原生实现。
    }
  }
}
