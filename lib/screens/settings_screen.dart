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
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    color: isSelected ? const Color(0xFF6C63FF) : Colors.white,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                trailing: isSelected
                  ? const Icon(Icons.check_circle, color: Color(0xFF6C63FF), size: 20)
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
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
        : ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              // Security note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_person, color: Color(0xFF6C63FF)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Privix uses your device's secure lock screen (Fingerprint, Face, PIN).",
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Behavior section
              _buildSectionHeader('Behavior'),
              const SizedBox(height: 12),
              _buildSettingTile(
                icon: Icons.timer,
                title: 'Relock Timer',
                subtitle: _getRelockLabel(),
                onTap: _showRelockPicker,
              ),
              const SizedBox(height: 24),

              // Permissions section
              _buildSectionHeader('Permissions'),
              const SizedBox(height: 12),
              _buildSettingTile(
                icon: Icons.accessibility_new,
                title: 'Accessibility Service',
                subtitle: 'Open system accessibility settings',
                onTap: () => PlatformChannelService.openAccessibilitySettings(),
              ),
              const SizedBox(height: 8),
              _buildSettingTile(
                icon: Icons.layers,
                title: 'Draw Over Apps',
                subtitle: 'Optional background permission',
                onTap: () => PlatformChannelService.openOverlaySettings(),
              ),
              const SizedBox(height: 8),
              _buildSettingTile(
                icon: Icons.battery_saver,
                title: 'Battery Optimization',
                subtitle: 'Prevent service from being killed',
                onTap: () => PlatformChannelService.openBatteryOptimizationSettings(),
              ),
              const SizedBox(height: 32),

              // About
              Center(
                child: Text(
                  'Privix App Lock v1.0.0',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Powered by Android System Authentication',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 11,
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
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: Colors.white.withOpacity(0.5),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
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
                color: const Color(0xFF6C63FF).withOpacity(0.12),
              ),
              child: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
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
