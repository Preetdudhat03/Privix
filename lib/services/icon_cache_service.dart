import 'dart:typed_data';
import 'platform_channel_service.dart';

/// High-performance in-memory LRU cache for app icons.
/// Pre-warms visible items and prevents UI micro-stutters during fast list scrolling.
class IconCacheService {
  static final Map<String, Uint8List> _cache = {};
  static final Map<String, Future<Uint8List?>> _loading = {};

  /// Instant synchronous getter for cached icons.
  static Uint8List? getSyncIcon(String packageName) {
    return _cache[packageName];
  }

  /// Get the icon for a package, from cache if available, otherwise from platform channel.
  static Future<Uint8List?> getIcon(String packageName) async {
    // 1. Check in-memory cache
    if (_cache.containsKey(packageName)) {
      return _cache[packageName];
    }

    // 2. Check if already loading in flight
    if (_loading.containsKey(packageName)) {
      return await _loading[packageName];
    }

    // 3. Load asynchronously from native platform channel
    final future = PlatformChannelService.getAppIcon(packageName);
    _loading[packageName] = future;

    final icon = await future;
    _loading.remove(packageName);

    if (icon != null) {
      _cache[packageName] = icon;
    }

    return icon;
  }

  /// Pre-warm icons for a list of package names in parallel batches.
  static Future<void> prewarm(List<String> packageNames) async {
    final toFetch = packageNames.where((pkg) => !_cache.containsKey(pkg) && !_loading.containsKey(pkg)).take(15);
    for (final pkg in toFetch) {
      getIcon(pkg);
    }
  }

  /// Clear the cache to free memory.
  static void clear() {
    _cache.clear();
    _loading.clear();
  }
}
