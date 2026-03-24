import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Reusable widget for displaying an app in a list with a lock toggle.
class AppTile extends StatelessWidget {
  final String appName;
  final String packageName;
  final Uint8List? icon;
  final bool isLocked;
  final ValueChanged<bool> onToggle;

  const AppTile({
    super.key,
    required this.appName,
    required this.packageName,
    required this.isLocked,
    required this.onToggle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isLocked 
          ? const Color(0xFF1E1B2E) 
          : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: isLocked 
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
            child: icon != null
              ? Image.memory(icon!, width: 48, height: 48, fit: BoxFit.cover)
              : const Icon(Icons.android, color: Color(0xFF6C63FF), size: 28),
          ),
        ),
        title: Text(
          appName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          packageName,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Switch(
          value: isLocked,
          onChanged: onToggle,
          activeColor: const Color(0xFF6C63FF),
          activeTrackColor: const Color(0xFF6C63FF).withOpacity(0.3),
          inactiveThumbColor: const Color(0xFF555555),
          inactiveTrackColor: const Color(0xFF333333),
        ),
      ),
    );
  }
}
