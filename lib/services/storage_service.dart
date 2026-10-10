import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'platform_channel_service.dart';
import '../models/app_info.dart';

/// Centralized storage service for all app data.
/// 
/// Uses flutter_secure_storage for sensitive data (PIN)
/// and shared_preferences for non-sensitive data.
/// Also syncs locked apps to native SharedPreferences via platform channel.
class StorageService {
  static const _storage = FlutterSecureStorage();
  static const _keyPin = 'user_pin';
  static const _keyPinSet = 'pin_set';
  static const _keyBiometricEnabled = 'biometric_enabled';
  static const _keyAppCache = 'cached_app_list';

  // ─── PIN ─────────────────────────────────────────────

  /// Save PIN securely (Flutter side) and as hash (native side).
  static Future<void> savePin(String pin) async {
    // Store encrypted PIN in Flutter secure storage
    await _storage.write(key: _keyPin, value: pin);
    await _storage.write(key: _keyPinSet, value: 'true');
    
    // Also store hash on native side for overlay verification
    await PlatformChannelService.savePinHash(pin);
  }

  /// Verify PIN against Flutter secure storage.
  static Future<bool> verifyPin(String pin) async {
    final storedPin = await _storage.read(key: _keyPin);
    return storedPin == pin;
  }

  /// Check if a PIN has been configured.
  static Future<bool> isPinSet() async {
    final value = await _storage.read(key: _keyPinSet);
    return value == 'true';
  }

  // ─── Locked Apps ─────────────────────────────────────

  /// Get the list of locked app package names.
  static Future<List<String>> getLockedApps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('locked_apps') ?? [];
  }

  /// Save locked app package names (both Flutter and native side).
  static Future<void> saveLockedApps(List<String> packageNames) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('locked_apps', packageNames);
    
    // Sync to native side so AccessibilityService can read them
    await PlatformChannelService.saveLockedApps(packageNames);
  }

  // ─── Biometric ───────────────────────────────────────

  static Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _keyBiometricEnabled, value: enabled.toString());
    await PlatformChannelService.setBiometricEnabled(enabled);
  }

  static Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _keyBiometricEnabled);
    return value == 'true';
  }

  // ─── Relock Timeout ──────────────────────────────────

  static Future<void> setRelockTimeout(int timeoutMs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('relock_timeout', timeoutMs);
    await PlatformChannelService.setRelockTimeout(timeoutMs);
  }

  static Future<int> getRelockTimeout() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('relock_timeout') ?? 0; // Default: immediately
  }

  // ─── Engine Mode ─────────────────────────────────────

  static Future<String> getEngineMode() async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getString('engine_mode');
    if (local != null) return local;
    return await PlatformChannelService.getEngineMode();
  }

  static Future<void> setEngineMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('engine_mode', mode);
    await PlatformChannelService.setEngineMode(mode);
  }

  // ─── App List Caching ────────────────────────────────

  /// Get cached app list from local storage.
  static Future<List<AppInfo>> getCachedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyAppCache);
    if (jsonStr == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((item) => AppInfo.fromMap(Map<String, dynamic>.from(item))).toList();
    } catch (_) {
      return [];
    }
  }

  /// Save app list to local storage to speed up next launch.
  static Future<void> saveCachedApps(List<AppInfo> apps) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(apps.map((a) => a.toMap()).toList());
    await prefs.setString(_keyAppCache, jsonStr);
  }

  /// Clear the app cache (used for refresh).
  static Future<void> clearAppCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAppCache);
  }
}
