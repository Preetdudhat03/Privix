import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../models/app_info.dart';

/// Bridge to native Kotlin layer via MethodChannel.
/// 
/// WHY platform channels: Flutter cannot access Android Accessibility APIs,
/// system overlay windows, or installed app lists directly. We must call
/// through to Kotlin for all OS-level operations.
class PlatformChannelService {
  static const _channel = MethodChannel('com.privix.applock/channel');

  // ─── App Discovery ───────────────────────────────────

  /// Get all user-installed apps from the device (without icons).
  static Future<List<AppInfo>> getInstalledApps() async {
    final List<dynamic> rawApps = await _channel.invokeMethod('getInstalledApps');
    return rawApps.map((app) {
      final map = Map<String, dynamic>.from(app as Map);
      return AppInfo.fromMap(map);
    }).toList();
  }

  /// Get the icon for a specific app as Base64.
  static Future<Uint8List?> getAppIcon(String packageName) async {
    final String? iconBase64 = await _channel.invokeMethod('getAppIcon', {'packageName': packageName});
    if (iconBase64 == null) return null;
    return base64Decode(iconBase64);
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
    return await _channel.invokeMethod('checkAccessibilityPermission');
  }

  /// Check if we have draw-over-other-apps permission.
  static Future<bool> checkOverlayPermission() async {
    return await _channel.invokeMethod('checkOverlayPermission');
  }

  /// Check if battery optimization is disabled for us.
  static Future<bool> checkBatteryOptimization() async {
    return await _channel.invokeMethod('checkBatteryOptimization');
  }

  // ─── Open Settings ───────────────────────────────────

  /// Open Android Accessibility Settings.
  static Future<void> openAccessibilitySettings() async {
    await _channel.invokeMethod('openAccessibilitySettings');
  }

  /// Open Draw Over Other Apps settings for our app.
  static Future<void> openOverlaySettings() async {
    await _channel.invokeMethod('openOverlaySettings');
  }

  /// Open Battery Optimization settings.
  static Future<void> openBatteryOptimizationSettings() async {
    await _channel.invokeMethod('openBatteryOptimizationSettings');
  }

  // ─── Service Status ──────────────────────────────────

  /// Check if the accessibility service is currently running.
  static Future<bool> isServiceRunning() async {
    return await _channel.invokeMethod('isServiceRunning');
  }
}
