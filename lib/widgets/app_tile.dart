import 'package:flutter/material.dart';
import '../services/icon_cache_service.dart';
import '../services/app_service.dart';
import '../models/app_info.dart';

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
    // Use pre-fetched icon if available from AppInfo
    final app = AppService().apps.firstWhere(
      (a) => a.packageName == widget.packageName,
      orElse: () => AppInfo(packageName: '', appName: ''),
    );
    
    _iconBytes = app.icon;
    
    // If we have an icon, put it in cache immediately
    if (_iconBytes != null) {
      IconCacheService.putIcon(widget.packageName, _iconBytes!);
    } else {
      _loadIcon();
    }
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
    
    // Generate a soft color based on app name for the placeholder
    final placeholderColor = _generateColor(widget.appName);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Padding(
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
                      color: placeholderColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _iconBytes != null
                        ? Image.memory(
                            _iconBytes!,
                            key: ValueKey(widget.packageName),
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            cacheWidth: 104,
                            cacheHeight: 104,
                          )
                        : Container(
                            key: const ValueKey('placeholder'),
                            alignment: Alignment.center,
                            child: Text(
                              widget.appName.isNotEmpty ? widget.appName[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: placeholderColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
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
      ),
    );
  }

  Color _generateColor(String text) {
    if (text.isEmpty) return const Color(0xFF007AFF);
    final hash = text.hashCode;
    final colors = [
      const Color(0xFF007AFF), // Blue
      const Color(0xFF5856D6), // Indigo
      const Color(0xFFFF2D55), // Pink
      const Color(0xFFFF9500), // Orange
      const Color(0xFF34C759), // Green
      const Color(0xFF5AC8FA), // Teal
      const Color(0xFFAF52DE), // Purple
    ];
    return colors[hash.abs() % colors.length];
  }
}
