import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/icon_cache_service.dart';

/// Reusable widget for displaying an app in a list with a lock toggle.
/// Loads icons lazily with hardware-accelerated memory caching.
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
  bool _isLoading = false;

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
    if (_isLoading) return;
    
    // Quick check if already in sync cache
    final syncIcon = IconCacheService.getSyncIcon(widget.packageName);
    if (syncIcon != null) {
      if (mounted) setState(() => _iconBytes = syncIcon);
      return;
    }

    _isLoading = true;
    final icon = await IconCacheService.getIcon(widget.packageName);
    
    if (mounted) {
      setState(() {
        _iconBytes = icon;
        _isLoading = false;
      });
    }
  }

  void _handleToggle(bool value) {
    HapticFeedback.selectionClick();
    widget.onToggle(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _handleToggle(!widget.isLocked),
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isLocked
                ? theme.colorScheme.primary.withValues(alpha: 0.06)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: widget.isLocked
                ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2), width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _iconBytes != null
                      ? Image.memory(
                          _iconBytes!,
                          key: ValueKey(widget.packageName),
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          cacheWidth: 104,
                          cacheHeight: 104,
                        )
                      : Container(
                          key: const ValueKey('placeholder'),
                          width: 52,
                          height: 52,
                          color: Colors.transparent,
                          child: Icon(
                            Icons.android_rounded,
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                            size: 32,
                          ),
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.appName,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.isLocked)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.lock_rounded,
                              size: 15,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.packageName,
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: widget.isLocked,
                onChanged: _handleToggle,
                activeTrackColor: theme.colorScheme.primary,
                activeThumbColor: Colors.white,
                inactiveThumbColor: colorScheme.onSurface.withValues(alpha: 0.4),
                inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.12),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
