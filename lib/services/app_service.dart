import '../models/app_info.dart';
import 'platform_channel_service.dart';
import 'storage_service.dart';
import 'icon_cache_service.dart';
import 'icon_cache_service.dart';

/// Global service to pre-fetch and cache the app list.
class AppService {
  static final AppService _instance = AppService._internal();
  factory AppService() => _instance;
  AppService._internal();

  List<AppInfo> _apps = [];
  bool _isInitialized = false;
  bool _isLoading = false;

  List<AppInfo> get apps => _apps;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;

  /// Fetch the app list and sync lock status in the background.
  Future<void> initialize() async {
    if (_isInitialized || _isLoading) return;
    
    _isLoading = true;
    try {
      final apps = await PlatformChannelService.getInstalledApps();
      final lockedApps = await StorageService.getLockedApps();
      final lockedSet = lockedApps.toSet();

      for (final app in apps) {
        app.isLocked = lockedSet.contains(app.packageName);
      }

      // Initial sort: alphabet
      apps.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));

      _apps = apps;
      _isInitialized = true;
      
      // Start loading icons in the background (don't await)
      _loadIconsInBackground();
    } catch (e) {
      // Log error or retry
    } finally {
      _isLoading = false;
    }
  }

  /// Load all icons into the IconCacheService in the background.
  Future<void> _loadIconsInBackground() async {
    // Import IconCacheService here or at top level
    // Wait for a second to let the UI settle
    await Future.delayed(const Duration(seconds: 1));
    
    for (final app in _apps) {
      // If we've been de-initialized, stop loading
      if (!_isInitialized) break;
      
      try {
        await IconCacheService.getIcon(app.packageName);
        // Small delay to prevent blocking the platform channel
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (_) {
        // Skip failed icons
      }
    }
  }

  /// Force a refresh of the app list.
  Future<void> refresh() async {
    _isInitialized = false;
    await initialize();
  }

  /// Sync the lock status for all cached apps.
  Future<void> syncLockStatus() async {
    final lockedApps = await StorageService.getLockedApps();
    final lockedSet = lockedApps.toSet();
    for (final app in _apps) {
      app.isLocked = lockedSet.contains(app.packageName);
    }
  }
}
