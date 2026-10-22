import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_info.dart';
import '../services/platform_channel_service.dart';
import '../services/storage_service.dart';
import '../services/icon_cache_service.dart';
import '../widgets/app_tile.dart';

/// Filter tabs for Samsung One UI 9 App Selection
enum AppFilterCategory { all, locked, sensitive, user }

/// Screen to select which apps to lock, designed with Samsung One UI 9 aesthetics.
class AppSelectionScreen extends StatefulWidget {
  const AppSelectionScreen({super.key});

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  List<AppInfo> _apps = [];
  List<AppInfo> _filteredApps = [];
  Set<String> _lockedPackages = {};
  bool _isLoading = true;
  String _searchQuery = '';
  AppFilterCategory _selectedCategory = AppFilterCategory.all;
  final _searchController = TextEditingController();

  static const Color oneUiBlue = Color(0xFF1E6FFE);

  // Known sensitive apps to suggest for locking
  static const _sensitiveKeywords = [
    'whatsapp', 'instagram', 'facebook', 'messenger', 'telegram', 'snapchat',
    'paytm', 'gpay', 'phonepe', 'bank', 'gallery', 'photos', 'drive', 'files',
    'gmail', 'outlook', 'notes', 'vault', 'crypto', 'binance', 'coinbase',
    'aadhaar', 'digilocker', 'yono', 'bhim', 'message', 'sms'
  ];

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApps({bool forceRefresh = false}) async {
    try {
      // 1. If cache is available, show it immediately for zero-delay rendering
      if (!forceRefresh) {
        final cached = await StorageService.getCachedApps();
        if (cached.isNotEmpty && mounted) {
          final lockedApps = await StorageService.getLockedApps();
          final lockedSet = lockedApps.toSet();
          for (final app in cached) {
            app.isLocked = lockedSet.contains(app.packageName);
          }
          _updateAppState(cached, lockedSet);
        }
      }

      // 2. Fetch fresh app list from native (stale-while-revalidate)
      final apps = await PlatformChannelService.getInstalledApps();
      final lockedApps = await StorageService.getLockedApps();
      final lockedSet = lockedApps.toSet();

      for (final app in apps) {
        app.isLocked = lockedSet.contains(app.packageName);
      }

      await StorageService.saveCachedApps(apps);
      if (mounted) {
        _updateAppState(apps, lockedSet);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load apps: $e')),
        );
      }
    }
  }

  void _updateAppState(List<AppInfo> apps, Set<String> lockedSet) {
    apps.sort((a, b) {
      if (a.isLocked && !b.isLocked) return -1;
      if (!a.isLocked && b.isLocked) return 1;
      return a.appName.toLowerCase().compareTo(b.appName.toLowerCase());
    });

    _apps = apps;
    _lockedPackages = lockedSet;
    _isLoading = false;
    _applyFilters();

    // Pre-warm top 15 icons in background for instant scroll
    IconCacheService.prewarm(_filteredApps.map((a) => a.packageName).toList());
  }

  void _applyFilters() {
    setState(() {
      final q = _searchQuery.trim().toLowerCase();
      final isSearchingGallery = q == 'galary' || q == 'gallary' || q == 'galery';

      _filteredApps = _apps.where((app) {
        // Search query filter (with common typo alias for gallery)
        final name = app.appName.toLowerCase();
        final pkg = app.packageName.toLowerCase();
        final matchesQuery = q.isEmpty ||
            name.contains(q) ||
            pkg.contains(q) ||
            (isSearchingGallery && (name.contains('gallery') || pkg.contains('gallery') || name.contains('photo') || pkg.contains('photo')));

        if (!matchesQuery) return false;

        // Category filter
        switch (_selectedCategory) {
          case AppFilterCategory.locked:
            return app.isLocked;
          case AppFilterCategory.sensitive:
            return _isSensitiveApp(app);
          case AppFilterCategory.user:
            return !app.packageName.startsWith('com.android.') &&
                   !app.packageName.startsWith('com.google.android.') &&
                   !app.packageName.startsWith('com.sec.android.');
          case AppFilterCategory.all:
            return true;
        }
      }).toList();
    });
  }

  bool _isSensitiveApp(AppInfo app) {
    final name = app.appName.toLowerCase();
    final pkg = app.packageName.toLowerCase();
    return _sensitiveKeywords.any((keyword) => name.contains(keyword) || pkg.contains(keyword));
  }

  Future<void> _refreshApps() async {
    setState(() => _isLoading = true);
    await StorageService.clearAppCache();
    await _loadApps(forceRefresh: true);
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void _onCategorySelected(AppFilterCategory category) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategory = category;
    });
    _applyFilters();
  }

  Future<void> _onToggle(AppInfo app, bool isLocked) async {
    setState(() {
      app.isLocked = isLocked;
      if (isLocked) {
        _lockedPackages.add(app.packageName);
      } else {
        _lockedPackages.remove(app.packageName);
      }
    });

    await StorageService.saveLockedApps(_lockedPackages.toList());
  }

  Future<void> _lockSensitiveAppsPreset() async {
    HapticFeedback.mediumImpact();
    final newLocked = Set<String>.from(_lockedPackages);

    for (final app in _apps) {
      if (_isSensitiveApp(app)) {
        app.isLocked = true;
        newLocked.add(app.packageName);
      }
    }

    _updateAppState(_apps, newLocked);
    await StorageService.saveLockedApps(newLocked.toList());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Sensitive apps (Social, Messaging, Finance) locked!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _unlockAllPreset() async {
    HapticFeedback.mediumImpact();
    for (final app in _apps) {
      app.isLocked = false;
    }
    _updateAppState(_apps, {});
    await StorageService.saveLockedApps([]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final lockedCount = _lockedPackages.length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: oneUiBlue))
          : Scrollbar(
              interactive: true,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // One UI 9 Expansive Collapsible Header
                  SliverAppBar(
                    backgroundColor: theme.scaffoldBackgroundColor,
                    expandedHeight: 180,
                    collapsedHeight: 70,
                    pinned: true,
                    elevation: 0,
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
                      centerTitle: false,
                      title: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Protected Apps',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Inter',
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            '$lockedCount of ${_apps.length} locked',
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      background: Container(color: theme.scaffoldBackgroundColor),
                    ),
                    leading: IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: colorScheme.onSurface,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    actions: [
                      IconButton(
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                        onPressed: _refreshApps,
                        tooltip: 'Refresh list',
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),

                  // One UI 9 Squircle Search Pill
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: isDark ? const Color(0xFF262832) : const Color(0xFFE4E7EE),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: TextStyle(color: colorScheme.onSurface, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Search installed applications',
                            hintStyle: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.35),
                              fontSize: 14,
                            ),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 14, right: 8),
                              child: Icon(
                                Icons.search_rounded,
                                color: colorScheme.onSurface.withValues(alpha: 0.5),
                                size: 22,
                              ),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // One UI 9 Segmented Pill Capsule Filter Bar
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          _buildFilterPill('All (${_apps.length})', AppFilterCategory.all),
                          const SizedBox(width: 8),
                          _buildFilterPill('Locked ($lockedCount)', AppFilterCategory.locked),
                          const SizedBox(width: 8),
                          _buildFilterPill('Sensitive', AppFilterCategory.sensitive),
                          const SizedBox(width: 8),
                          _buildFilterPill('User Apps', AppFilterCategory.user),
                        ],
                      ),
                    ),
                  ),

                  // One UI 9 1-Tap Sensitive Apps Recommendation Banner
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161922) : const Color(0xFFEFF4FC),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: oneUiBlue.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: oneUiBlue.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.bolt_rounded, color: oneUiBlue, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '1-Tap Sensitive App Lock',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Auto-secures WhatsApp, Photos, Finance',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _lockSensitiveAppsPreset,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: oneUiBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Lock All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              onPressed: _unlockAllPreset,
                              tooltip: 'Unlock All',
                              icon: Icon(
                                Icons.lock_open_rounded,
                                color: colorScheme.onSurface.withValues(alpha: 0.5),
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // App List
                  _filteredApps.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 48,
                                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No apps match "$_searchQuery"'
                                      : 'No apps in this category',
                                  style: TextStyle(
                                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final app = _filteredApps[index];
                              return AppTile(
                                key: ValueKey(app.packageName),
                                appName: app.appName,
                                packageName: app.packageName,
                                isLocked: app.isLocked,
                                onToggle: (value) => _onToggle(app, value),
                              );
                            },
                            childCount: _filteredApps.length,
                            addAutomaticKeepAlives: false,
                            addRepaintBoundaries: true,
                          ),
                        ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterPill(String label, AppFilterCategory category) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _selectedCategory == category;

    return GestureDetector(
      onTap: () => _onCategorySelected(category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? oneUiBlue
              : (isDark ? const Color(0xFF1A1C23) : const Color(0xFFE9ECF2)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? oneUiBlue
                : (isDark ? const Color(0xFF262832) : const Color(0xFFDCE1EB)),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
