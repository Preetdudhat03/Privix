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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => onToggle(!isLocked),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: icon != null
                    ? Image.memory(icon!, width: 52, height: 52, fit: BoxFit.cover)
                    : Icon(Icons.android, color: theme.colorScheme.primary, size: 32),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appName,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      packageName,
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.4),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Switch(
                value: isLocked,
                onChanged: onToggle,
                activeColor: theme.colorScheme.primary,
                activeTrackColor: theme.colorScheme.primary.withOpacity(0.35),
                inactiveThumbColor: colorScheme.onSurface.withOpacity(0.4),
                inactiveTrackColor: colorScheme.onSurface.withOpacity(0.12),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
