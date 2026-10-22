import 'package:flutter/services.dart';
import '../models/app_info.dart';

/// Bridge to native Kotlin layer via MethodChannel.
/// 
/// WHY platform channels: Flutter cannot access Android Accessibility APIs,
/// system overlay windows, or installed app lists directly. We must call
/// through to Kotlin for all OS-level operations.
class PlatformChannelService {
  static const _channel = MethodChannel('com.privix.applock/channel');

  // ─── App Self-Lock Authentication ───────────────────

  /// Authenticate user via Biometric or Device PIN/Password (App Self-Lock)
  static Future<bool> authenticateUser() async {
    try {
      final bool? result = await _channel.invokeMethod('authenticateUser');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  // ─── App Discovery ───────────────────────────────────

  /// Get all user-installed apps from the device.
  static Future<List<AppInfo>> getInstalledApps() async {
    final List<dynamic> rawApps = await _channel.invokeMethod('getInstalledApps');
    return rawApps.map((app) {
      final map = Map<String, dynamic>.from(app as Map);
      return AppInfo.fromMap(map);
    }).toList();
  }

  /// Get the icon bytes for a specific app package.
  static Future<Uint8List?> getAppIcon(String packageName) async {
    try {
      final dynamic result = await _channel.invokeMethod('getAppIcon', {'packageName': packageName});
      if (result != null) {
        return result as Uint8List;
      }
    } catch (_) {
      // Return null on icon loading failure
    }
    return null;
  }

  // ─── Locked Apps ─────────────────────────────────────

  /// Save the list of locked app package names to native SharedPreferences.
  static Future<bool> saveLockedApps(List<String> packageNames) async {
    return await _channel.invokeMethod('saveLockedApps', {'apps': packageNames});
  }

  /// Get the current list of locked app package names.
  static Future<List<String>> getLockedApps() async {
    final List<dynamic> apps = await _channel.invokeMethod('getLockedApps');
    return apps.cast<String>();
  }

  // ─── PIN Management ──────────────────────────────────

  /// Hash and store a PIN on the native side.
  static Future<bool> savePinHash(String pin) async {
    return await _channel.invokeMethod('savePinHash', {'pin': pin});
  }

  /// Verify a PIN against the stored hash.
  static Future<bool> verifyPin(String pin) async {
    return await _channel.invokeMethod('verifyPin', {'pin': pin});
  }

  /// Check if a PIN has been set.
  static Future<bool> isPinSet() async {
    return await _channel.invokeMethod('isPinSet');
  }

  // ─── Biometric ───────────────────────────────────────

  /// Enable or disable biometric unlock.
  static Future<bool> setBiometricEnabled(bool enabled) async {
    return await _channel.invokeMethod('setBiometricEnabled', {'enabled': enabled});
  }

  /// Check if biometric unlock is enabled.
  static Future<bool> isBiometricEnabled() async {
    return await _channel.invokeMethod('isBiometricEnabled');
  }

  // ─── Relock Timeout ──────────────────────────────────

  /// Set the relock timeout in milliseconds.
  /// Use 0 for immediately, -1 for never.
  static Future<bool> setRelockTimeout(int timeoutMs) async {
    return await _channel.invokeMethod('setRelockTimeout', {'timeout': timeoutMs});
  }

  /// Get the current relock timeout in milliseconds.
  static Future<int> getRelockTimeout() async {
    final result = await _channel.invokeMethod('getRelockTimeout');
    return (result as num).toInt();
  }

  // ─── Permission Checks ───────────────────────────────

  /// Check if our AccessibilityService is enabled.
  static Future<bool> checkAccessibilityPermission() async {
    return (await _channel.invokeMethod('checkAccessibilityPermission')) ?? false;
  }

  /// Check if Usage Stats Access is granted (Gov & Banking safe).
  static Future<bool> checkUsageStatsPermission() async {
    return (await _channel.invokeMethod('checkUsageStatsPermission')) ?? false;
  }

  /// Check if we have draw-over-other-apps permission.
  static Future<bool> checkOverlayPermission() async {
    return (await _channel.invokeMethod('checkOverlayPermission')) ?? false;
  }

  /// Check if battery optimization is disabled for us.
  static Future<bool> checkBatteryOptimization() async {
    return (await _channel.invokeMethod('checkBatteryOptimization')) ?? false;
  }

  // ─── Open Settings ───────────────────────────────────

  /// Open Android Accessibility Settings.
  static Future<void> openAccessibilitySettings() async {
    await _channel.invokeMethod('openAccessibilitySettings');
  }

  /// Open Android Usage Access Settings.
  static Future<void> openUsageStatsSettings() async {
    await _channel.invokeMethod('openUsageStatsSettings');
  }

  /// Open Draw Over Other Apps settings for our app.
  static Future<void> openOverlaySettings() async {
    await _channel.invokeMethod('openOverlaySettings');
  }

  /// Open Battery Optimization settings.
  static Future<void> openBatteryOptimizationSettings() async {
    await _channel.invokeMethod('openBatteryOptimizationSettings');
  }

  // ─── Engine Mode & Pause Controls ─────────────────────

  /// Get current detection engine ('usage_stats' or 'accessibility').
  static Future<String> getEngineMode() async {
    final mode = await _channel.invokeMethod('getEngineMode');
    return mode as String? ?? 'usage_stats';
  }

  /// Set detection engine ('usage_stats' or 'accessibility').
  static Future<bool> setEngineMode(String mode) async {
    return (await _channel.invokeMethod('setEngineMode', {'mode': mode})) ?? true;
  }

  /// Temporarily pause protection for specified minutes.
  static Future<bool> pauseProtection({int minutes = 15}) async {
    return (await _channel.invokeMethod('pauseProtection', {'minutes': minutes})) ?? true;
  }

  /// Resume protection immediately.
  static Future<bool> resumeProtection() async {
    return (await _channel.invokeMethod('resumeProtection')) ?? true;
  }

  /// Check if protection is currently paused.
  static Future<bool> isProtectionPaused() async {
    return (await _channel.invokeMethod('isProtectionPaused')) ?? false;
  }

  /// Get remaining paused seconds.
  static Future<int> getPausedRemainingSeconds() async {
    final sec = await _channel.invokeMethod('getPausedRemainingSeconds');
    return (sec as num?)?.toInt() ?? 0;
  }

  // ─── Service Status ──────────────────────────────────

  /// Check if active lock service is running.
  static Future<bool> isServiceRunning() async {
    return (await _channel.invokeMethod('isServiceRunning')) ?? false;
  }
}
