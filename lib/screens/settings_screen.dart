import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/platform_channel_service.dart';

/// Settings screen for configuring relock behavior and permissions.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _relockTimeout = 0;
  bool _isLoading = true;

  static const _relockOptions = [
    {'label': 'Immediately', 'value': 0},
    {'label': '30 seconds', 'value': 30000},
    {'label': '1 minute', 'value': 60000},
    {'label': '5 minutes', 'value': 300000},
    {'label': 'Never (always unlocked)', 'value': -1},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final relockTimeout = await StorageService.getRelockTimeout();

    if (mounted) {
      setState(() {
        _relockTimeout = relockTimeout;
        _isLoading = false;
      });
    }
  }

  Future<void> _setRelockTimeout(int timeoutMs) async {
    await StorageService.setRelockTimeout(timeoutMs);
    if (mounted) setState(() => _relockTimeout = timeoutMs);
  }

  void _showRelockPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Relock Timer',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ..._relockOptions.map((option) {
              final value = option['value'] as int;
              final isSelected = _relockTimeout == value;
              return ListTile(
                title: Text(
                  option['label'] as String,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF007AFF) : Colors.white,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                trailing: isSelected
                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF007AFF), size: 24)
                  : null,
                onTap: () {
                  _setRelockTimeout(value);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF007AFF)))
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
                    'Settings',
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

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: Column(
                    children: [
                      // Security Focus Block
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF007AFF).withOpacity(0.12),
                              ),
                              child: const Icon(Icons.lock_person_rounded, color: Color(0xFF007AFF), size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Secure Auth',
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Privix uses your device's Fingerprint, Face, or PIN.",
                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Behavior section
                      _buildSectionHeader('Behavior'),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: _buildSettingTile(
                          icon: Icons.timer_rounded,
                          title: 'Relock Timer',
                          subtitle: _getRelockLabel(),
                          showDivider: false,
                          onTap: _showRelockPicker,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Permissions section
                      _buildSectionHeader('Permissions'),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: Column(
                          children: [
                            _buildSettingTile(
                              icon: Icons.accessibility_new_rounded,
                              title: 'Accessibility Service',
                              subtitle: 'Required for app detection',
                              showDivider: true,
                              onTap: () => PlatformChannelService.openAccessibilitySettings(),
                            ),
                            _buildSettingTile(
                              icon: Icons.layers_rounded,
                              title: 'Draw Over Apps',
                              subtitle: 'Required for lock overlay',
                              showDivider: true,
                              onTap: () => PlatformChannelService.openOverlaySettings(),
                            ),
                            _buildSettingTile(
                              icon: Icons.battery_saver_rounded,
                              title: 'Battery Optimization',
                              subtitle: 'Prevent background death',
                              showDivider: false,
                              onTap: () => PlatformChannelService.openBatteryOptimizationSettings(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),

                      // About
                      Text(
                        'Privix App Lock v1.0.0',
                        style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Optimized for One UI 7',
                        style: TextStyle(color: const Color(0xFF007AFF).withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }

  String _getRelockLabel() {
    for (final option in _relockOptions) {
      if (option['value'] == _relockTimeout) {
        return option['label'] as String;
      }
    }
    return 'Immediately';
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
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
                    color: const Color(0xFF007AFF).withOpacity(0.12),
                  ),
                  child: Icon(icon, color: const Color(0xFF007AFF), size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
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
