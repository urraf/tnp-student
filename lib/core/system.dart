import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge to `MainActivity.kt` ("tnp/system"). Every call is safe to make on
/// non-Android platforms or in a background isolate: failures return a
/// harmless default instead of throwing.
class SystemBridge {
  SystemBridge._();

  static const _ch = MethodChannel('tnp/system');
  static bool get _android => defaultTargetPlatform == TargetPlatform.android;

  static Future<T> _call<T>(String method, T fallback, [Map<String, Object?>? args]) async {
    if (!_android) return fallback;
    try {
      return (await _ch.invokeMethod<T>(method, args)) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// True when Android won't throttle the app in the background.
  static Future<bool> isIgnoringBatteryOptimizations() => _call('isIgnoringBatteryOptimizations', true);

  /// Shows the system "Allow app to run in background?" prompt.
  static Future<bool> requestIgnoreBatteryOptimizations() => _call('requestIgnoreBatteryOptimizations', false);

  /// Opens the OEM "Autostart" screen (Xiaomi, Oppo, Vivo…) or app settings.
  static Future<bool> openAutostartSettings() => _call('openAutostartSettings', false);

  static Future<bool> canScheduleExactAlarms() => _call('canScheduleExactAlarms', true);

  static Future<String> manufacturer() => _call('manufacturer', '');

  static Future<bool> canInstallPackages() => _call('canInstallPackages', true);

  static Future<bool> openInstallPermissionSettings() => _call('openInstallPermissionSettings', false);

  /// Hands a downloaded APK (in cache/updates) to the system installer.
  static Future<bool> installApk(String path) => _call('installApk', false, {'path': path});

  /// Brands known to kill background work unless "Autostart" is enabled.
  static bool isAggressiveOem(String manufacturer) {
    final m = manufacturer.toLowerCase();
    return const [
      'xiaomi',
      'redmi',
      'poco',
      'oppo',
      'realme',
      'vivo',
      'iqoo',
      'oneplus',
      'huawei',
      'honor',
      'tecno',
      'infinix',
    ].any(m.contains);
  }
}
