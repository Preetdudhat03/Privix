import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/icon_cache_service.dart';

/// Reusable widget for displaying an app in a list with a Samsung One UI 9 lock toggle.
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

  static const Color oneUiBlue = Color(0xFF1E6FFE);

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
    final isDark = theme.brightness == Brightness.dark;
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
                ? oneUiBlue.withValues(alpha: isDark ? 0.12 : 0.08)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.isLocked
                  ? oneUiBlue.withValues(alpha: 0.35)
                  : (isDark ? const Color(0xFF242630) : const Color(0xFFE6E9F0)),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF22242C) : const Color(0xFFEFF2F8),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _iconBytes != null
                        ? Image.memory(
                            _iconBytes!,
                            key: ValueKey(widget.packageName),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            cacheWidth: 100,
                            cacheHeight: 100,
                          )
                        : Container(
                            key: const ValueKey('placeholder'),
                            width: 50,
                            height: 50,
                            color: Colors.transparent,
                            child: const Icon(
                              Icons.android_rounded,
                              color: oneUiBlue,
                              size: 28,
                            ),
                          ),
                  ),
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
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.lock_rounded,
                              size: 14,
                              color: oneUiBlue,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.packageName,
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.45),
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
                activeTrackColor: oneUiBlue,
                activeThumbColor: Colors.white,
                inactiveThumbColor: isDark ? const Color(0xFF757884) : const Color(0xFF9EA3AF),
                inactiveTrackColor: isDark ? const Color(0xFF2D3039) : const Color(0xFFDEE2EB),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
