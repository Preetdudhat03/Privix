import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../services/platform_channel_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Settings screen designed with Samsung One UI 9 grouped card hierarchy.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _relockTimeout = 0;
  bool _biometricEnabled = false;
  String _engineMode = 'usage_stats';
  bool _isPaused = false;
  int _pausedRemainingSeconds = 0;
  bool _usageStatsGranted = false;
  bool _overlayGranted = false;
  bool _batteryOptimized = false;
  String _appVersion = '2.2.4';
  bool _isLoading = true;

  static const Color oneUiBlue = Color(0xFF1E6FFE);
  static const Color oneUiGreen = Color(0xFF28C76F);
  static const Color oneUiAmber = Color(0xFFFF9F43);

  static const _relockOptions = [
    {'label': 'Immediately (0 seconds)', 'value': 0},
    {'label': '15 seconds', 'value': 15000},
    {'label': '30 seconds', 'value': 30000},
    {'label': '1 minute', 'value': 60000},
    {'label': '5 minutes', 'value': 300000},
    {'label': 'Until screen turns off', 'value': -1},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final results = await Future.wait([
        StorageService.getRelockTimeout(),
        StorageService.isBiometricEnabled(),
        StorageService.getEngineMode(),
        PlatformChannelService.isProtectionPaused(),
        PlatformChannelService.getPausedRemainingSeconds(),
        PlatformChannelService.checkUsageStatsPermission(),
        PlatformChannelService.checkOverlayPermission(),
        PlatformChannelService.checkBatteryOptimization(),
      ]);

      String version = '2.2.4';
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        version = packageInfo.version;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _relockTimeout = results[0] as int;
          _biometricEnabled = results[1] as bool;
          _engineMode = results[2] as String;
          _isPaused = results[3] as bool;
          _pausedRemainingSeconds = results[4] as int;
          _usageStatsGranted = results[5] as bool;
          _overlayGranted = results[6] as bool;
          _batteryOptimized = results[7] as bool;
          _appVersion = version;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _setBiometric(bool enabled) async {
    HapticFeedback.lightImpact();
    await StorageService.setBiometricEnabled(enabled);
    setState(() => _biometricEnabled = enabled);
  }

  Future<void> _setRelockTimeout(int timeoutMs) async {
    HapticFeedback.lightImpact();
    await StorageService.setRelockTimeout(timeoutMs);
    setState(() => _relockTimeout = timeoutMs);
  }

  Future<void> _togglePause(int minutes) async {
    HapticFeedback.mediumImpact();
    if (_isPaused) {
      await PlatformChannelService.resumeProtection();
    } else {
      await PlatformChannelService.pauseProtection(minutes: minutes);
    }
    await _loadSettings();
  }

  void _showRelockPicker() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Relock Timeout',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ..._relockOptions.map((option) {
                final value = option['value'] as int;
                final isSelected = _relockTimeout == value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Material(
                    color: isSelected
                        ? oneUiBlue.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text(
                        option['label'] as String,
                        style: TextStyle(
                          color: isSelected ? oneUiBlue : theme.colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: oneUiBlue, size: 20)
                          : null,
                      onTap: () {
                        _setRelockTimeout(value);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: oneUiBlue))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
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
                    title: Text(
                      'Settings',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Inter',
                        letterSpacing: -0.5,
                      ),
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
                ),

                // Settings Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Government & Banking App Compatibility (The User's Core Problem!)
                        _buildSectionTitle('GOVERNMENT & BANKING APP COMPATIBILITY'),
                        const SizedBox(height: 8),
                        _buildGovCompatibilityCard(),
                        const SizedBox(height: 20),

                        // 2. Detection Engine Mode
                        _buildSectionTitle('DETECTION ENGINE'),
                        const SizedBox(height: 8),
                        _buildDetectionEngineCard(),
                        const SizedBox(height: 20),

                        // 3. Temporary Pause Protection
                        _buildSectionTitle('TEMPORARY PAUSE PROTECTION'),
                        const SizedBox(height: 8),
                        _buildPauseCard(),
                        const SizedBox(height: 20),

                        // 4. Security & Authentication
                        _buildSectionTitle('AUTHENTICATION & TIMEOUT'),
                        const SizedBox(height: 8),
                        _buildAuthCard(),
                        const SizedBox(height: 20),

                        // 5. System Permissions
                        _buildSectionTitle('SYSTEM PERMISSIONS'),
                        const SizedBox(height: 8),
                        _buildPermissionsCard(),
                        const SizedBox(height: 20),

                        // 6. Security Assurance & Privacy
                        _buildSectionTitle('PRIVACY & THREAT SAFETY'),
                        const SizedBox(height: 8),
                        _buildSecurityAssuranceCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// Government & Banking App Compatibility Card
  Widget _buildGovCompatibilityCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final isUsageMode = _engineMode == 'usage_stats';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isUsageMode
            ? (isDark ? const Color(0xFF0F1E19) : const Color(0xFFEBFBF3))
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isUsageMode
              ? oneUiGreen.withValues(alpha: 0.4)
              : (isDark ? const Color(0xFF262832) : const Color(0xFFE4E7EE)),
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
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Why Government Apps Stop Working',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'mAadhaar • DigiLocker • SBI YONO • UPI',
                      style: TextStyle(
                        color: oneUiGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Government and banking applications (such as mAadhaar, DigiLocker, and SBI YONO) block devices with active Accessibility Services.\n\n'
            'Privix operates 100% without Accessibility Services. It uses native Usage Access and a lightweight foreground service, allowing your banking and identity apps to function completely unimpeded!',
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

  /// Detection Engine Card
  Widget _buildDetectionEngineCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? const Color(0xFF262832) : const Color(0xFFE4E7EE),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: oneUiGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: oneUiGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Usage Access Engine',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: oneUiGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'ACTIVE • 100% SAFE',
                        style: TextStyle(color: oneUiGreen, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'High-speed foreground monitoring. Zero accessibility permissions, zero Play Protect warnings, safe with banking apps.',
                  style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.55), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Pause Protection Card
  Widget _buildPauseCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? const Color(0xFF262832) : const Color(0xFFE4E7EE),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (_isPaused ? oneUiGreen : oneUiAmber).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        color: _isPaused ? oneUiGreen : oneUiAmber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isPaused ? 'Protection Paused' : 'Quick Pause',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _isPaused
                                ? '${(_pausedRemainingSeconds / 60).ceil()}m remaining'
                                : 'Temporarily suspend app locks',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _isPaused,
                onChanged: (_) => _togglePause(15),
                activeTrackColor: oneUiAmber,
              ),
            ],
          ),
          if (!_isPaused) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                _buildPauseTimeButton(5, '5 min'),
                const SizedBox(width: 8),
                _buildPauseTimeButton(15, '15 min'),
                const SizedBox(width: 8),
                _buildPauseTimeButton(30, '30 min'),
                const SizedBox(width: 8),
                _buildPauseTimeButton(60, '1 hour'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPauseTimeButton(int minutes, String label) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: () => _togglePause(minutes),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2028) : const Color(0xFFEFF2F8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Authentication & Timeout Card
  Widget _buildAuthCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    String timeoutLabel = 'Immediately';
    for (final opt in _relockOptions) {
      if (opt['value'] == _relockTimeout) {
        timeoutLabel = opt['label'] as String;
        break;
      }
    }

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
          // Biometric Unlock
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: oneUiBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.fingerprint_rounded, color: oneUiBlue, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Biometric Authentication',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Unlock with Fingerprint or Face',
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _biometricEnabled,
                  onChanged: _setBiometric,
                  activeTrackColor: oneUiBlue,
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.8,
            color: colorScheme.onSurface.withValues(alpha: 0.08),
            indent: 72,
            endIndent: 18,
          ),
          // Relock Timeout Picker
          InkWell(
            onTap: _showRelockPicker,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.timer_rounded, color: Color(0xFF6C5CE7), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Relock Timer',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          timeoutLabel,
                          style: TextStyle(
                            color: oneUiBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// System Permissions Card
  Widget _buildPermissionsCard() {
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
          _buildPermissionItem(
            'Usage Data Access',
            'Required for Gov & Banking Safe mode',
            _usageStatsGranted,
            () => PlatformChannelService.openUsageStatsSettings(),
          ),
          const Divider(height: 1, thickness: 0.8, indent: 20, endIndent: 20),
          _buildPermissionItem(
            'Draw Over Other Apps',
            'Required for instant lock screen curtain',
            _overlayGranted,
            () => PlatformChannelService.openOverlaySettings(),
          ),
          const Divider(height: 1, thickness: 0.8, indent: 20, endIndent: 20),
          _buildPermissionItem(
            'Battery Optimization Exemption',
            'Prevents Samsung OS from killing service',
            _batteryOptimized,
            () => PlatformChannelService.openBatteryOptimizationSettings(),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(
    String title,
    String subtitle,
    bool isGranted,
    VoidCallback onTap,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 11)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (isGranted ? oneUiGreen : oneUiAmber).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isGranted ? 'GRANTED' : 'GRANT',
            style: TextStyle(
              color: isGranted ? oneUiGreen : oneUiAmber,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  /// Security Assurance & Privacy Card
  Widget _buildSecurityAssuranceCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? const Color(0xFF262832) : const Color(0xFFE4E7EE),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: oneUiBlue, size: 22),
              const SizedBox(width: 10),
              Text(
                'Play Protect & Samsung Knox Safe',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '• Threat Warning Eliminated: canRetrieveWindowContent is permanently disabled.\n'
            '• 100% Offline: Zero INTERNET permissions declared in AndroidManifest.\n'
            '• Local Security: All PIN hashes stored strictly on your device.',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Privix v$_appVersion • Samsung One UI 9 Edition',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: FontWeight.w500,
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
}
