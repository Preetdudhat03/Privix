import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/platform_channel_service.dart';
import '../services/storage_service.dart';

/// Main dashboard designed with Samsung One UI 9 visual hierarchy.
/// 
/// Key One UI 9 Features:
/// - Expansive collapsible Viewing Area with dynamic security capsule pill
/// - Device Care style circular security gauge widget
/// - First-class Detection Engine switcher (Usage Access vs Accessibility)
/// - Government & Banking App Safe badge & Quick Pause action
/// - Thumb-friendly Inset Grouped Island Cards
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _usageStatsEnabled = false;
  bool _accessibilityEnabled = false;
  bool _overlayEnabled = false;
  bool _batteryOptimized = false;
  int _lockedAppCount = 0;
  String _engineMode = 'usage_stats'; // 'usage_stats' or 'accessibility'
  bool _isPaused = false;
  int _pausedRemainingSeconds = 0;
  bool _isLoading = true;
  Timer? _countdownTimer;
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;

  // Samsung One UI 9 Palette
  static const Color oneUiBlue = Color(0xFF1E6FFE);
  static const Color oneUiGreen = Color(0xFF28C76F);
  static const Color oneUiAmber = Color(0xFFFF9F43);
  static const Color oneUiRed = Color(0xFFFF495C);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authenticateUser();
    _startCountdownTimer();
  }

  Future<void> _authenticateUser() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;
    try {
      final success = await PlatformChannelService.authenticateUser();
      if (mounted) {
        setState(() {
          _isAuthenticated = success;
          _isAuthenticating = false;
        });
        if (success) {
          _loadStatus();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused && _pausedRemainingSeconds > 0) {
        setState(() {
          _pausedRemainingSeconds--;
          if (_pausedRemainingSeconds <= 0) {
            _isPaused = false;
            _loadStatus();
          }
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!_isAuthenticated) {
        _authenticateUser();
      } else {
        _loadStatus();
      }
    }
  }

  Future<void> _loadStatus() async {
    try {
      final results = await Future.wait([
        PlatformChannelService.checkUsageStatsPermission(),
        PlatformChannelService.checkAccessibilityPermission(),
        PlatformChannelService.checkOverlayPermission(),
        PlatformChannelService.checkBatteryOptimization(),
        StorageService.getLockedApps(),
        PlatformChannelService.getEngineMode(),
        PlatformChannelService.isProtectionPaused(),
        PlatformChannelService.getPausedRemainingSeconds(),
      ]);

      if (mounted) {
        setState(() {
          _usageStatsEnabled = results[0] as bool;
          _accessibilityEnabled = results[1] as bool;
          _overlayEnabled = results[2] as bool;
          _batteryOptimized = results[3] as bool;
          _lockedAppCount = (results[4] as List).length;
          _engineMode = results[5] as String;
          _isPaused = results[6] as bool;
          _pausedRemainingSeconds = results[7] as int;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isEnginePermissionGranted => _usageStatsEnabled;

  bool get _isProtectionActive =>
      !_isPaused && _isEnginePermissionGranted && _overlayEnabled && _lockedAppCount > 0;

  int get _securityScore {
    int score = 0;
    if (_isEnginePermissionGranted) score += 40;
    if (_overlayEnabled) score += 35;
    if (_batteryOptimized) score += 15;
    if (_lockedAppCount > 0) score += 10;
    if (_isPaused) score = (score * 0.5).round();
    return score;
  }


  Future<void> _togglePause(int minutes) async {
    HapticFeedback.mediumImpact();
    if (_isPaused) {
      await PlatformChannelService.resumeProtection();
    } else {
      await PlatformChannelService.pauseProtection(minutes: minutes);
    }
    await _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    if (!_isAuthenticated) {
      return _buildLockedGateScreen(theme, isDark, colorScheme);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: oneUiBlue))
          : RefreshIndicator(
              onRefresh: _loadStatus,
              color: oneUiBlue,
              backgroundColor: isDark ? const Color(0xFF1C1D23) : Colors.white,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // One UI 9 Expansive Collapsible Header
                  SliverAppBar(
                    backgroundColor: theme.scaffoldBackgroundColor,
                    expandedHeight: 200,
                    collapsedHeight: 70,
                    floating: false,
                    pinned: true,
                    elevation: 0,
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
                      centerTitle: false,
                      title: Row(
                        children: [
                          Text(
                            'Privix',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Inter',
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildDynamicStatusPill(),
                        ],
                      ),
                      background: Container(
                        color: theme.scaffoldBackgroundColor,
                        child: Stack(
                          children: [
                            Positioned(
                              right: 16,
                              top: 50,
                              child: Opacity(
                                opacity: isDark ? 0.08 : 0.05,
                                child: const Icon(
                                  Icons.shield_rounded,
                                  size: 160,
                                  color: oneUiBlue,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 24,
                              top: 80,
                              child: Text(
                                'Samsung One UI 9 Security Engine',
                                style: TextStyle(
                                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: isDark
                                ? const Color(0xFF1E2028)
                                : const Color(0xFFE9ECF2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: Icon(
                            Icons.settings_outlined,
                            color: colorScheme.onSurface,
                            size: 22,
                          ),
                          onPressed: () => Navigator.pushNamed(context, '/settings')
                              .then((_) => _loadStatus()),
                        ),
                      ),
                    ],
                  ),

                  // Main Interactive Content Area (Thumb Reachable)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. One UI 9 Device Care Security Ring Card
                          _buildDeviceCareCard(),
                          const SizedBox(height: 16),

                          // Instant Shield Warning Banner (Visible if Draw Over Apps is missing)
                          if (!_overlayEnabled) ...[
                            _buildOverlayPermissionWarningBanner(),
                            const SizedBox(height: 16),
                          ],

                          // 2. Government & Banking App Safe Engine Switcher
                          _buildGovBankingCompatibilityCard(),
                          const SizedBox(height: 20),

                          // 3. System Safeguards Grouped Island Card
                          _buildSectionTitle('SYSTEM SAFEGUARDS'),
                          const SizedBox(height: 8),
                          _buildSafeguardsIslandCard(),
                          const SizedBox(height: 20),

                          // 4. Quick Actions Grouped Island Card
                          _buildSectionTitle('QUICK ACTIONS'),
                          const SizedBox(height: 8),
                          _buildQuickActionsIslandCard(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// One UI 9 Dynamic Status Pill in AppBar
  Widget _buildDynamicStatusPill() {
    Color pillColor;
    String label;
    IconData icon;

    if (_isPaused) {
      pillColor = oneUiAmber;
      label = '${(_pausedRemainingSeconds / 60).ceil()}m Paused';
      icon = Icons.pause_circle_filled_rounded;
    } else if (_isProtectionActive) {
      pillColor = oneUiGreen;
      label = 'Active • Protected';
      icon = Icons.check_circle_rounded;
    } else {
      pillColor = oneUiAmber;
      label = 'Attention';
      icon = Icons.error_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: pillColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pillColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: pillColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: pillColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// One UI 9 Device Care Style Circular Security Card
  Widget _buildDeviceCareCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final score = _securityScore;
    final scoreColor = _isPaused
        ? oneUiAmber
        : (score >= 80 ? oneUiGreen : (score >= 50 ? oneUiAmber : oneUiRed));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF262832) : const Color(0xFFE4E7EE),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Circular Score Gauge
              SizedBox(
                width: 78,
                height: 78,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 8,
                      backgroundColor: isDark
                          ? const Color(0xFF262832)
                          : const Color(0xFFEAEFF7),
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text(
                        '$score%',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Status Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPaused
                          ? 'Protection Paused'
                          : (_isProtectionActive ? 'Device Protected' : 'Setup Incomplete'),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isPaused
                          ? 'Temporarily paused (${(_pausedRemainingSeconds / 60).ceil()}m remaining)'
                          : (_isProtectionActive
                              ? '$_lockedAppCount apps locked with zero preview leaks'
                              : _getInactiveSummary()),
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, thickness: 0.8),
          const SizedBox(height: 16),
          // Quick Action Bar inside Device Care
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _togglePause(15),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _isPaused
                        ? oneUiGreen.withValues(alpha: 0.12)
                        : (isDark ? const Color(0xFF1E2028) : const Color(0xFFF0F3F8)),
                    foregroundColor: _isPaused ? oneUiGreen : colorScheme.onSurface,
                    side: BorderSide(
                      color: _isPaused
                          ? oneUiGreen.withValues(alpha: 0.4)
                          : (isDark ? const Color(0xFF2A2D38) : const Color(0xFFDCE1EB)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(
                    _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _isPaused ? 'Resume Lock' : 'Pause 15m',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/app_selection')
                      .then((_) => _loadStatus()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: oneUiBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.add_moderator_rounded, size: 18),
                  label: const Text(
                    'Manage Apps',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Government & Banking Compatibility Card (Direct answer to the user's issue!)
  Widget _buildGovBankingCompatibilityCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1E19) : const Color(0xFFEBFBF3),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: oneUiGreen.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: oneUiGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: oneUiGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Government & Banking App Safe',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Zero Accessibility Conflict (mAadhaar, SBI Safe)',
                      style: TextStyle(
                        color: oneUiGreen.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Powered by the native Usage Access Engine. Accessibility Service is completely removed, allowing mAadhaar, DigiLocker, Umang, and banking apps to operate with zero security blocks or warnings.',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.75),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// System Safeguards Inset Grouped Island Card
  Widget _buildSafeguardsIslandCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? const Color(0xFF262832) : const Color(0xFFE4E7EE),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Primary engine permission tile
          _buildPermissionTile(
            icon: Icons.data_usage_rounded,
            title: 'Usage Access Permission',
            subtitle: 'Monitors foreground apps without triggering Accessibility blocks',
            isEnabled: _usageStatsEnabled,
            isRecommended: true,
            showDivider: true,
            onTap: () => PlatformChannelService.openUsageStatsSettings(),
          ),

          // Draw Over Apps
          _buildPermissionTile(
            icon: Icons.layers_rounded,
            title: 'Draw Over Other Apps',
            subtitle: 'Displays instant curtain and biometric unlock overlay',
            isEnabled: _overlayEnabled,
            isRecommended: false,
            showDivider: true,
            onTap: () => PlatformChannelService.openOverlaySettings(),
          ),

          // Battery Optimization
          _buildPermissionTile(
            icon: Icons.battery_saver_rounded,
            title: 'Battery Optimization Exemption',
            subtitle: 'Prevents Samsung One UI from killing background service',
            isEnabled: _batteryOptimized,
            isRecommended: false,
            showDivider: false,
            onTap: () => PlatformChannelService.openBatteryOptimizationSettings(),
          ),
        ],
      ),
    );
  }

  /// Quick Actions Inset Grouped Island Card
  Widget _buildQuickActionsIslandCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? const Color(0xFF262832) : const Color(0xFFE4E7EE),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildActionTile(
            icon: Icons.lock_clock_rounded,
            iconColor: oneUiBlue,
            title: 'Manage Locked Applications',
            subtitle: '$_lockedAppCount application${_lockedAppCount == 1 ? '' : 's'} secured',
            showDivider: true,
            onTap: () => Navigator.pushNamed(context, '/app_selection')
                .then((_) => _loadStatus()),
          ),
          _buildActionTile(
            icon: Icons.security_update_good_rounded,
            iconColor: oneUiGreen,
            title: 'Samsung Quick Settings Tile',
            subtitle: 'Add Privix tile to notification shade for 1-tap pause',
            showDivider: true,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Swipe down from top twice -> Tap Edit buttons -> Drag Privix Lock into active tiles.'),
                  duration: Duration(seconds: 4),
                ),
              );
            },
          ),
          _buildActionTile(
            icon: Icons.tune_rounded,
            iconColor: colorScheme.onSurface.withValues(alpha: 0.6),
            title: 'Security & App Preferences',
            subtitle: 'Relock timers, biometrics & offline privacy',
            showDivider: false,
            onTap: () => Navigator.pushNamed(context, '/settings')
                .then((_) => _loadStatus()),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isEnabled,
    required bool isRecommended,
    required bool showDivider,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? oneUiGreen.withValues(alpha: 0.12)
                        : oneUiAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: isEnabled ? oneUiGreen : oneUiAmber,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: oneUiGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'SAFE',
                                style: TextStyle(
                                  color: oneUiGreen,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  isEnabled ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                  color: isEnabled ? oneUiGreen : colorScheme.onSurface.withValues(alpha: 0.4),
                  size: isEnabled ? 22 : 24,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 76, right: 18),
            child: Divider(
              height: 1,
              thickness: 0.8,
              color: colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool showDivider,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 76, right: 18),
            child: Divider(
              height: 1,
              thickness: 0.8,
              color: colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
      ],
    );
  }

  /// High-visibility warning banner shown when Draw Over Other Apps is missing
  Widget _buildOverlayPermissionWarningBanner() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2E2207) : const Color(0xFFFFF7E6);
    final borderColor = isDark ? const Color(0xFF59410D) : const Color(0xFFFFE0A3);
    final textColor = isDark ? const Color(0xFFFFD580) : const Color(0xFF7A4B00);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: textColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Instant Shield Required',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Without "Appear on top" permission, Android briefly flashes the locked app before opening the lock screen. Grant this permission to eliminate preview leaks.',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                HapticFeedback.lightImpact();
                await PlatformChannelService.openOverlaySettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: textColor,
                foregroundColor: isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                elevation: 0,
              ),
              icon: const Icon(Icons.touch_app_rounded, size: 16),
              label: const Text(
                'Grant "Appear On Top" Permission',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 2),
      child: Text(
        title,
        style: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  String _getInactiveSummary() {
    if (_engineMode == 'usage_stats' && !_usageStatsEnabled) {
      return 'Grant Usage Access permission to enable app lock';
    }
    if (_engineMode == 'accessibility' && !_accessibilityEnabled) {
      return 'Enable Accessibility Service to activate detection';
    }
    if (!_overlayEnabled) return 'Grant Draw Over Apps overlay permission';
    if (_lockedAppCount == 0) return 'No applications locked yet';
    return 'Complete system permissions to activate';
  }

  Widget _buildLockedGateScreen(ThemeData theme, bool isDark, ColorScheme colorScheme) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1D23) : const Color(0xFFE8EEF9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: oneUiBlue.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock_rounded,
                      size: 44,
                      color: oneUiBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Privix is Locked',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Authentication required to access Privix dashboard and security settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _authenticateUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: oneUiBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.fingerprint_rounded, size: 24),
                    label: const Text(
                      'Unlock Privix',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => SystemNavigator.pop(),
                  child: Text(
                    'Exit',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
