import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_info.dart';
import '../services/platform_channel_service.dart';
import '../services/storage_service.dart';
import '../services/icon_cache_service.dart';
import '../widgets/app_tile.dart';

/// Filter tabs for App Selection
enum AppFilterCategory { all, locked, sensitive, user }

/// Screen to select which apps to lock.
/// Includes preset quick actions, category filters, and debounced search.
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

  // Known sensitive apps to suggest for locking
  static const _sensitiveKeywords = [
    'whatsapp', 'instagram', 'facebook', 'messenger', 'telegram', 'snapchat',
    'paytm', 'gpay', 'phonepe', 'bank', 'gallery', 'photos', 'drive', 'files',
    'gmail', 'outlook', 'notes', 'vault', 'crypto', 'binance', 'coinbase'
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
      if (!forceRefresh) {
        final cached = await StorageService.getCachedApps();
        if (cached.isNotEmpty) {
          final lockedApps = await StorageService.getLockedApps();
          final lockedSet = lockedApps.toSet();
          
          for (final app in cached) {
            app.isLocked = lockedSet.contains(app.packageName);
          }
          
          _updateAppState(cached, lockedSet);
          return;
        }
      }

      final apps = await PlatformChannelService.getInstalledApps();
      final lockedApps = await StorageService.getLockedApps();
      final lockedSet = lockedApps.toSet();

      for (final app in apps) {
        app.isLocked = lockedSet.contains(app.packageName);
      }

      await StorageService.saveCachedApps(apps);
      _updateAppState(apps, lockedSet);
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
      _filteredApps = _apps.where((app) {
        // Search query filter
        final matchesQuery = _searchQuery.isEmpty ||
            app.appName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            app.packageName.toLowerCase().contains(_searchQuery.toLowerCase());

        if (!matchesQuery) return false;

        // Category filter
        switch (_selectedCategory) {
          case AppFilterCategory.locked:
            return app.isLocked;
          case AppFilterCategory.sensitive:
            return _isSensitiveApp(app);
          case AppFilterCategory.user:
            return !app.packageName.startsWith('com.android.') &&
                   !app.packageName.startsWith('com.google.android.');
          case AppFilterCategory.all:
          default:
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
    _selectedCategory = category;
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
          content: Text('🔒 Sensitive apps (Social, Finance, Photos) locked!'),
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
    final colorScheme = theme.colorScheme;
    final lockedCount = _lockedPackages.length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF007AFF)))
        : Scrollbar(
            interactive: true,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // Header
                SliverAppBar(
                  backgroundColor: theme.scaffoldBackgroundColor,
                  expandedHeight: 160,
                  collapsedHeight: 70,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
                    centerTitle: false,
                    title: Text(
                      'Select Apps',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                      ),
                    ),
                    background: Container(color: theme.scaffoldBackgroundColor),
                  ),
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: colorScheme.onSurface, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.refresh_rounded, color: colorScheme.onSurface.withValues(alpha: 0.7)),
                      onPressed: _refreshApps,
                      tooltip: 'Refresh app list',
                    ),
                    const SizedBox(width: 8),
                  ],
                ),

                // Search Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: colorScheme.onSurface.withValues(alpha: 0.06),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Search applications',
                          hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.3)),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Icon(
                              Icons.search_rounded,
                              color: colorScheme.onSurface.withValues(alpha: 0.4),
                              size: 22,
                            ),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close_rounded, color: colorScheme.onSurface.withValues(alpha: 0.5), size: 18),
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

                // Category Chips
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      children: [
                        _buildFilterChip('All (${_apps.length})', AppFilterCategory.all),
                        const SizedBox(width: 8),
                        _buildFilterChip('Locked ($lockedCount)', AppFilterCategory.locked),
                        const SizedBox(width: 8),
                        _buildFilterChip('Sensitive', AppFilterCategory.sensitive),
                        const SizedBox(width: 8),
                        _buildFilterChip('User Apps', AppFilterCategory.user),
                      ],
                    ),
                  ),
                ),

                // Quick Action Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: ActionChip(
                            avatar: const Icon(Icons.security_rounded, size: 16, color: Color(0xFF007AFF)),
                            label: const Text('Lock Sensitive', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.1),
                            onPressed: _lockSensitiveAppsPreset,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: Icon(Icons.lock_open_rounded, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                          label: const Text('Unlock All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          backgroundColor: colorScheme.surface,
                          onPressed: _unlockAllPreset,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ],
                    ),
                  ),
                ),

                // App List
                _filteredApps.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Text(
                          _searchQuery.isNotEmpty
                            ? 'No apps match "$_searchQuery"'
                            : 'No apps in this category',
                          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.35)),
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

  Widget _buildFilterChip(String label, AppFilterCategory category) {
    final theme = Theme.of(context);
    final isSelected = _selectedCategory == category;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _onCategorySelected(category),
      selectedColor: const Color(0xFF007AFF),
      backgroundColor: theme.colorScheme.surface,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.7),
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      showCheckmark: false,
    );
  }
}
