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
        StorageService.getLockedApps(),
      ]);

      if (mounted) {
        setState(() {
          _accessibilityEnabled = results[0] as bool;
          _overlayEnabled = results[1] as bool;
          _batteryOptimized = results[2] as bool;
          _lockedAppCount = (results[3] as List).length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isProtectionActive =>
      _accessibilityEnabled && _overlayEnabled && _lockedAppCount > 0;

  int get _securityScore {
    int score = 0;
    if (_accessibilityEnabled) score += 40;
    if (_overlayEnabled) score += 40;
    if (_batteryOptimized) score += 10;
    if (_lockedAppCount > 0) score += 10;
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                // Header
                SliverAppBar(
                  backgroundColor: theme.scaffoldBackgroundColor,
                  expandedHeight: 190,
                  collapsedHeight: 80,
                  floating: false,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
                    centerTitle: false,
                    title: Text(
                      'Privix',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                      ),
                    ),
                    background: Container(
                      color: theme.scaffoldBackgroundColor,
                      child: Stack(
                        children: [
                          Positioned(
                            right: -20,
                            top: 40,
                            child: Icon(
                              Icons.shield_rounded,
                              size: 180,
                              color: const Color(0xFF007AFF).withValues(alpha: 0.05),
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
                        icon: Icon(
                          Icons.settings_outlined,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
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
                        // Status Card
                        _buildStatusCard(),
                        const SizedBox(height: 24),

                        // System Safeguards
                        _buildSectionTitle('System Safeguards'),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Column(
                            children: [
                              _buildPermissionTile(
                                icon: Icons.accessibility_new_rounded,
                                title: 'Accessibility Service',
                                subtitle: 'Instant app detection engine',
                                isEnabled: _accessibilityEnabled,
                                showDivider: true,
                                onTap: () => PlatformChannelService.openAccessibilitySettings(),
                              ),
                              _buildPermissionTile(
                                icon: Icons.layers_rounded,
                                title: 'Draw Over Apps',
                                subtitle: 'Lock screen overlay display',
                                isEnabled: _overlayEnabled,
                                showDivider: true,
                                onTap: () => PlatformChannelService.openOverlaySettings(),
                              ),
                              _buildPermissionTile(
                                icon: Icons.battery_saver_rounded,
                                title: 'Battery Optimization',
                                subtitle: 'Background persistence',
                                isEnabled: _batteryOptimized,
                                showDivider: false,
                                onTap: () => PlatformChannelService.openBatteryOptimizationSettings(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Quick Actions
                        _buildSectionTitle('Quick Actions'),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
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
                                icon: Icons.tune_rounded,
                                title: 'Settings',
                                subtitle: 'Relock timeout & behavior',
                                color: colorScheme.onSurface.withValues(alpha: 0.5),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isProtectionActive
                    ? const Color(0xFF007AFF).withValues(alpha: 0.12)
                    : const Color(0xFFFF453A).withValues(alpha: 0.12),
                ),
                child: Icon(
                  _isProtectionActive ? Icons.shield_rounded : Icons.shield_outlined,
                  color: _isProtectionActive ? const Color(0xFF007AFF) : const Color(0xFFFF453A),
                  size: 44,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _isProtectionActive
                      ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                      : colorScheme.error.withValues(alpha: 0.1),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isProtectionActive ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                      size: 14,
                      color: _isProtectionActive ? const Color(0xFF007AFF) : colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Score: $_securityScore%',
                      style: TextStyle(
                        color: _isProtectionActive ? const Color(0xFF007AFF) : colorScheme.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _isProtectionActive ? 'Protection Active' : 'Action Required',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _isProtectionActive
                ? '$_lockedAppCount app${_lockedAppCount == 1 ? '' : 's'} protected with zero-latency lock'
                : _getInactiveReason(),
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
              ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isEnabled,
    required bool showDivider,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
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
                      ? const Color(0xFF007AFF).withValues(alpha: 0.12)
                      : colorScheme.onSurface.withValues(alpha: 0.05),
                  ),
                  child: Icon(
                    icon,
                    color: isEnabled ? const Color(0xFF007AFF) : colorScheme.onSurface.withValues(alpha: 0.38),
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
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isEnabled ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
                  color: isEnabled ? const Color(0xFF007AFF) : colorScheme.onSurface.withValues(alpha: 0.24),
                  size: isEnabled ? 22 : 14,
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
              color: colorScheme.onSurface.withValues(alpha: 0.05),
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
    final colorScheme = Theme.of(context).colorScheme;
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
                    color: color.withValues(alpha: 0.12),
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
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: colorScheme.onSurface.withValues(alpha: 0.24),
                  size: 14,
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
              color: colorScheme.onSurface.withValues(alpha: 0.05),
            ),
          ),
      ],
    );
  }
}
