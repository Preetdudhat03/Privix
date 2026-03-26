import 'package:flutter/material.dart';
import '../models/app_info.dart';
import '../services/platform_channel_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_tile.dart';

/// Screen to select which apps to lock.
/// Lists all user-installed apps with toggle switches.
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
  final _searchController = TextEditingController();

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

  Future<void> _loadApps() async {
    try {
      final apps = await PlatformChannelService.getInstalledApps();
      final lockedApps = await StorageService.getLockedApps();
      final lockedSet = lockedApps.toSet();

      for (final app in apps) {
        app.isLocked = lockedSet.contains(app.packageName);
      }

      // Sort: locked apps first, then alphabetically
      apps.sort((a, b) {
        if (a.isLocked && !b.isLocked) return -1;
        if (!a.isLocked && b.isLocked) return 1;
        return a.appName.toLowerCase().compareTo(b.appName.toLowerCase());
      });

      setState(() {
        _apps = apps;
        _filteredApps = apps;
        _lockedPackages = lockedSet;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load apps: $e')),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filteredApps = _apps.where((app) {
        return app.appName.toLowerCase().contains(query.toLowerCase()) ||
               app.packageName.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
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

  @override
  Widget build(BuildContext context) {
    final lockedCount = _lockedPackages.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF007AFF)),
          )
        : CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // One UI Large Header
              SliverAppBar(
                backgroundColor: Colors.black,
                expandedHeight: 180,
                collapsedHeight: 80,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
                  centerTitle: false,
                  title: const Text(
                    'Select Apps',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  background: Container(color: Colors.black),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              // Search Box Sliver
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Search applications',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.4), size: 22),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
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

              // Info Badge Sliver
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Row(
                    children: [
                      Text(
                        '$lockedCount locked ',
                        style: const TextStyle(
                          color: Color(0xFF007AFF),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '· ${_filteredApps.length} apps',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 13,
                        ),
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
                          ? 'No results for "$_searchQuery"'
                          : 'No apps found',
                        style: TextStyle(color: Colors.white.withOpacity(0.3)),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final app = _filteredApps[index];
                        return AppTile(
                          appName: app.appName,
                          packageName: app.packageName,
                          icon: app.icon,
                          isLocked: app.isLocked,
                          onToggle: (value) => _onToggle(app, value),
                        );
                      },
                      childCount: _filteredApps.length,
                    ),
                  ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
    );
  }
}
