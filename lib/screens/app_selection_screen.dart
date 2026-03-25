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
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        elevation: 0,
        title: const Text(
          'Select Apps',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF333344)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search apps...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.4)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 18),
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
      ),
      body: _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
          )
        : Column(
            children: [
              // Locked count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock, color: Color(0xFF6C63FF), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            '$lockedCount locked',
                            style: const TextStyle(
                              color: Color(0xFF6C63FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_filteredApps.length} apps',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // App list
              Expanded(
                child: _filteredApps.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isNotEmpty
                          ? 'No apps found for "$_searchQuery"'
                          : 'No apps found',
                        style: TextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _filteredApps.length,
                      itemBuilder: (context, index) {
                        final app = _filteredApps[index];
                        return AppTile(
                          appName: app.appName,
                          packageName: app.packageName,
                          isLocked: app.isLocked,
                          onToggle: (value) => _onToggle(app, value),
                        );
                      },
                    ),
              ),
            ],
          ),
    );
  }
}
