import 'package:flutter/material.dart';
import '../services/platform_channel_service.dart';
import '../services/storage_service.dart';

/// Main dashboard after PIN setup.
/// Shows lock status, permission states, locked app count, and quick actions.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _accessibilityEnabled = false;
  bool _overlayEnabled = false;
  bool _batteryOptimized = false;
  bool _serviceRunning = false;
  int _lockedAppCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Refresh status when user returns from settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    try {
      final results = await Future.wait([
        PlatformChannelService.checkAccessibilityPermission(),
        PlatformChannelService.checkOverlayPermission(),
        PlatformChannelService.checkBatteryOptimization(),
        PlatformChannelService.isServiceRunning(),
        StorageService.getLockedApps(),
      ]);

      if (mounted) {
        setState(() {
          _accessibilityEnabled = results[0] as bool;
          _overlayEnabled = results[1] as bool;
          _batteryOptimized = results[2] as bool;
          _serviceRunning = results[3] as bool;
          _lockedAppCount = (results[4] as List).length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isProtectionActive =>
      _accessibilityEnabled && _overlayEnabled && _lockedAppCount > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF007AFF)))
        : RefreshIndicator(
            onRefresh: _loadStatus,
            color: const Color(0xFF007AFF),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // App bar with One UI Large Title
                SliverAppBar(
                  backgroundColor: Colors.black,
                  expandedHeight: 200,
                  collapsedHeight: 80,
                  floating: false,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
                    centerTitle: false,
                    title: Text(
                      'Privix',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                      ),
                    ),
                    background: Container(
                      color: Colors.black,
                      child: Stack(
                        children: [
                          Positioned(
                            right: -20,
                            top: 40,
                            child: Icon(
                              Icons.shield,
                              size: 180,
                              color: const Color(0xFF007AFF).withOpacity(0.05),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                        onPressed: () => Navigator.pushNamed(context, '/settings')
                          .then((_) => _loadStatus()),
                      ),
                    ),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Focus block
                        _buildStatusCard(),
                        const SizedBox(height: 24),

                        // Section Headers and Cards
                        _buildSectionTitle('Permissions'),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Column(
                            children: [
                              _buildPermissionCard(
                                icon: Icons.accessibility_new,
                                title: 'Accessibility Service',
                                subtitle: 'Detect foreground apps',
                                isEnabled: _accessibilityEnabled,
                                showDivider: true,
                                onTap: () => PlatformChannelService.openAccessibilitySettings(),
                              ),
                              _buildPermissionCard(
                                icon: Icons.layers,
                                title: 'Draw Over Apps',
                                subtitle: 'Show lock screen overlay',
                                isEnabled: _overlayEnabled,
                                showDivider: true,
                                onTap: () => PlatformChannelService.openOverlaySettings(),
                              ),
                              _buildPermissionCard(
                                icon: Icons.battery_saver,
                                title: 'Battery Optimization',
                                subtitle: 'Keep service alive',
                                isEnabled: _batteryOptimized,
                                showDivider: false,
                                onTap: () => PlatformChannelService.openBatteryOptimizationSettings(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        _buildSectionTitle('Quick Actions'),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Column(
                            children: [
                              _buildActionCard(
                                icon: Icons.apps_rounded,
                                title: 'Manage Locked Apps',
                                subtitle: '$_lockedAppCount apps locked',
                                color: const Color(0xFF007AFF),
                                showDivider: true,
                                onTap: () => Navigator.pushNamed(context, '/app_selection')
                                  .then((_) => _loadStatus()),
                              ),
                              _buildActionCard(
                                icon: Icons.pin,
                                title: 'Settings',
                                subtitle: 'Behavior & PIN settings',
                                color: Colors.grey[400]!,
                                showDivider: false,
                                onTap: () => Navigator.pushNamed(context, '/settings'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isProtectionActive
                ? const Color(0xFF007AFF).withOpacity(0.1)
                : const Color(0xFFFF453A).withOpacity(0.1),
            ),
            child: Icon(
              _isProtectionActive ? Icons.shield_rounded : Icons.shield_outlined,
              color: _isProtectionActive
                ? const Color(0xFF007AFF)
                : const Color(0xFFFF453A),
              size: 56,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _isProtectionActive ? 'Protection Active' : 'Not Fully Protected',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isProtectionActive
              ? '$_lockedAppCount app${_lockedAppCount == 1 ? '' : 's'} are currently secured'
              : _getInactiveReason(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _getInactiveReason() {
    if (!_accessibilityEnabled) return 'Enable Accessibility Service to activate';
    if (!_overlayEnabled) return 'Enable Draw Over Apps permission';
    if (_lockedAppCount == 0) return 'No apps selected for locking';
    return 'Configure permissions to activate';
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isEnabled,
    required bool showDivider,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: isEnabled ? null : onTap,
          borderRadius: BorderRadius.circular(32),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isEnabled
                      ? const Color(0xFF007AFF).withOpacity(0.12)
                      : Colors.white.withOpacity(0.05),
                  ),
                  child: Icon(
                    icon,
                    color: isEnabled ? const Color(0xFF007AFF) : Colors.white38,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isEnabled ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
                  color: isEnabled ? const Color(0xFF007AFF) : Colors.white24,
                  size: isEnabled ? 24 : 14,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 80, right: 20),
            child: Divider(
              height: 1,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool showDivider,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 80, right: 20),
            child: Divider(
              height: 1,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
      ],
    );
  }
}
