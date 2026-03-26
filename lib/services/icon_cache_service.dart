import 'dart:typed_data';
import 'platform_channel_service.dart';

/// Simple in-memory cache for app icons to improve scrolling performance.
class IconCacheService {
  static final Map<String, Uint8List> _cache = {};
  static final Map<String, Future<Uint8List?>> _loading = {};

  /// Get the icon for a package, from cache if available, otherwise from platform channel.
  static Future<Uint8List?> getIcon(String packageName) async {
    // 1. Check cache
    if (_cache.containsKey(packageName)) {
      return _cache[packageName];
    }

    // 2. Check if already loading
    if (_loading.containsKey(packageName)) {
      return await _loading[packageName];
    }

    // 3. Load from platform channel
    final future = PlatformChannelService.getAppIcon(packageName);
    _loading[packageName] = future;

    final icon = await future;
    _loading.remove(packageName);

    if (icon != null) {
      _cache[packageName] = icon;
    }

    return icon;
  }

  /// Clear the cache to free memory.
  static void clear() {
    _cache.clear();
    _loading.clear();
  }
}
