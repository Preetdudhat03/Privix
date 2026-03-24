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
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
        : RefreshIndicator(
            onRefresh: _loadStatus,
            color: const Color(0xFF6C63FF),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // App bar
                SliverAppBar(
                  backgroundColor: const Color(0xFF0D0D1A),
                  expandedHeight: 80,
                  floating: true,
                  pinned: true,
                  title: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF6C63FF),
                              const Color(0xFF6C63FF).withOpacity(0.6),
                            ],
                          ),
                        ),
                        child: const Icon(Icons.shield, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Privix',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                      onPressed: () => Navigator.pushNamed(context, '/settings')
                        .then((_) => _loadStatus()),
                    ),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Status card
                        _buildStatusCard(),
                        const SizedBox(height: 20),

                        // Permission cards
                        _buildSectionTitle('Permissions'),
                        const SizedBox(height: 12),
                        _buildPermissionCard(
                          icon: Icons.accessibility_new,
                          title: 'Accessibility Service',
                          subtitle: 'Required to detect foreground apps',
                          isEnabled: _accessibilityEnabled,
                          onTap: () => PlatformChannelService.openAccessibilitySettings(),
                        ),
                        const SizedBox(height: 8),
                        _buildPermissionCard(
                          icon: Icons.layers,
                          title: 'Draw Over Apps',
                          subtitle: 'Required to show lock screen overlay',
                          isEnabled: _overlayEnabled,
                          onTap: () => PlatformChannelService.openOverlaySettings(),
                        ),
                        const SizedBox(height: 8),
                        _buildPermissionCard(
                          icon: Icons.battery_saver,
                          title: 'Battery Optimization',
                          subtitle: 'Prevents system from killing the service',
                          isEnabled: _batteryOptimized,
                          onTap: () => PlatformChannelService.openBatteryOptimizationSettings(),
                        ),
                        const SizedBox(height: 24),

                        // Quick actions
                        _buildSectionTitle('Quick Actions'),
                        const SizedBox(height: 12),
                        _buildActionCard(
                          icon: Icons.apps_rounded,
                          title: 'Manage Locked Apps',
                          subtitle: '$_lockedAppCount apps locked',
                          color: const Color(0xFF6C63FF),
                          onTap: () => Navigator.pushNamed(context, '/app_selection')
                            .then((_) => _loadStatus()),
                        ),
                        const SizedBox(height: 8),
                        _buildActionCard(
                          icon: Icons.pin,
                          title: 'Change PIN',
                          subtitle: 'Update your lock screen PIN',
                          color: const Color(0xFF00C896),
                          onTap: () => Navigator.pushNamed(context, '/settings'),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: _isProtectionActive
            ? [const Color(0xFF1A2A1A), const Color(0xFF0D1A0D)]
            : [const Color(0xFF2A1A1A), const Color(0xFF1A0D0D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: _isProtectionActive
            ? const Color(0xFF00C896).withOpacity(0.3)
            : const Color(0xFFCF6679).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            _isProtectionActive ? Icons.shield : Icons.shield_outlined,
            color: _isProtectionActive
              ? const Color(0xFF00C896)
              : const Color(0xFFCF6679),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            _isProtectionActive ? 'Protection Active' : 'Protection Inactive',
            style: TextStyle(
              color: _isProtectionActive
                ? const Color(0xFF00C896)
                : const Color(0xFFCF6679),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isProtectionActive
              ? '$_lockedAppCount app${_lockedAppCount == 1 ? '' : 's'} protected'
              : _getInactiveReason(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isEnabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEnabled
              ? const Color(0xFF00C896).withOpacity(0.3)
              : const Color(0xFF333344),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isEnabled
                  ? const Color(0xFF00C896).withOpacity(0.15)
                  : const Color(0xFF333344),
              ),
              child: Icon(
                icon,
                color: isEnabled ? const Color(0xFF00C896) : Colors.white54,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isEnabled ? Icons.check_circle : Icons.arrow_forward_ios,
              color: isEnabled ? const Color(0xFF00C896) : Colors.white30,
              size: isEnabled ? 22 : 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF333344)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 16),
          ],
        ),
      ),
    );
  }
}
