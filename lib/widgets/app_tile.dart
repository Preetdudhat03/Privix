import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/icon_cache_service.dart';

/// Reusable widget for displaying an app in a list with a lock toggle.
/// Loads icons lazily for better performance.
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
    
    setState(() => _isLoading = true);
    final icon = await IconCacheService.getIcon(widget.packageName);
    
    if (mounted) {
      setState(() {
        _iconBytes = icon;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => widget.onToggle(!widget.isLocked),
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
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _iconBytes != null
                      ? Image.memory(
                          _iconBytes!,
                          key: ValueKey(widget.packageName), // Essential for AnimatedSwitcher
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          cacheWidth: 104,
                          cacheHeight: 104,
                        )
                      : Container(
                          key: const ValueKey('placeholder'),
                          width: 52,
                          height: 52,
                          color: Colors.transparent,
                          child: Icon(Icons.android, color: theme.colorScheme.primary.withOpacity(0.3), size: 32),
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
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
                    const SizedBox(height: 2),
                    Text(
                      widget.packageName,
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
                value: widget.isLocked,
                onChanged: widget.onToggle,
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
