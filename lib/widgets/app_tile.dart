import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/platform_channel_service.dart';


/// Reusable widget for displaying an app in a list with a lock toggle.
/// Uses lazy loading for icons to ensure smooth scrolling and fast initial load.
class AppTile extends StatefulWidget {
  final String appName;
  final String packageName;
  final bool isLocked;
  final ValueChanged<bool> onToggle;

  const AppTile({
    super.key,
    required this.appName,
    required this.packageName,
    required this.isLocked,
    required this.onToggle,
  });

  @override
  State<AppTile> createState() => _AppTileState();
}

class _AppTileState extends State<AppTile> {
  Uint8List? _iconBytes;
  bool _loadingIcon = false;
  static final Map<String, Uint8List> _iconCache = {};

  @override
  void initState() {
    super.initState();
    _loadIcon();
  }

  @override
  void didUpdateWidget(AppTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.packageName != widget.packageName) {
      _loadIcon();
    }
  }

  Future<void> _loadIcon() async {
    if (_iconCache.containsKey(widget.packageName)) {
      if (mounted) {
        setState(() {
          _iconBytes = _iconCache[widget.packageName];
          _loadingIcon = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _loadingIcon = true);
    }

    try {
      final icon = await PlatformChannelService.getAppIcon(widget.packageName);
      if (icon != null) {
        _iconCache[widget.packageName] = icon;
      }
      if (mounted) {
        setState(() {
          _iconBytes = icon;
          _loadingIcon = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingIcon = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: widget.isLocked 
          ? const Color(0xFF1E1B2E) 
          : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: widget.isLocked 
          ? Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3), width: 1)
          : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A3E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _iconBytes != null
              ? Image.memory(_iconBytes!, width: 48, height: 48, fit: BoxFit.cover,
                  gaplessPlayback: true)
              : _loadingIcon 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF)),
                    ),
                  )
                : const Icon(Icons.android, color: Color(0xFF6C63FF), size: 28),
          ),
        ),
        title: Text(
          widget.appName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          widget.packageName,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Switch(
          value: widget.isLocked,
          onChanged: widget.onToggle,
          activeColor: const Color(0xFF6C63FF),
          activeTrackColor: const Color(0xFF6C63FF).withOpacity(0.3),
          inactiveThumbColor: const Color(0xFF555555),
          inactiveTrackColor: const Color(0xFF333333),
        ),
      ),
    );
  }
}
