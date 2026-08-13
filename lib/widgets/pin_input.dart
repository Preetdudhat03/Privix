import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable PIN Input Widget with custom numeric keypad,
/// animated dot indicators, error text, and haptic feedback.
class PinInput extends StatefulWidget {
  final String title;
  final String subtitle;
  final ValueChanged<String> onPinComplete;
  final String? errorText;
  final int pinLength;

  const PinInput({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onPinComplete,
    this.errorText,
    this.pinLength = 4,
  });

  @override
  State<PinInput> createState() => _PinInputState();
}

class _PinInputState extends State<PinInput> with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    if (widget.errorText != null && widget.errorText!.isNotEmpty) {
      _triggerErrorShake();
    }
  }

  @override
  void didUpdateWidget(PinInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorText != null && widget.errorText != oldWidget.errorText) {
      _triggerErrorShake();
    }
  }

  void _triggerErrorShake() {
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0).then((_) {
      setState(() => _enteredPin = '');
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyTap(String number) {
    if (_enteredPin.length < widget.pinLength) {
      HapticFeedback.lightImpact();
      setState(() {
        _enteredPin += number;
      });

      if (_enteredPin.length == widget.pinLength) {
        widget.onPinComplete(_enteredPin);
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Header (Title + Subtitle)
        Column(
          children: [
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(alpha: 0.12),
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                color: colorScheme.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.subtitle,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),

        // Animated PIN Dots + Error Message
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnimation.value, 0),
              child: child,
            );
          },
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.pinLength, (index) {
                  final isFilled = index < _enteredPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.15),
                      border: Border.all(
                        color: isFilled
                            ? colorScheme.primary
                            : colorScheme.onSurface.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: isFilled
                          ? [
                              BoxShadow(
                                color: colorScheme.primary.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: widget.errorText != null ? 1.0 : 0.0,
                child: Text(
                  widget.errorText ?? '',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Custom Numeric Keypad
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
          child: Column(
            children: [
              _buildKeyRow(['1', '2', '3']),
              const SizedBox(height: 16),
              _buildKeyRow(['4', '5', '6']),
              const SizedBox(height: 16),
              _buildKeyRow(['7', '8', '9']),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 72, height: 72), // Empty balance cell
                  _buildKeyButton('0'),
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: IconButton(
                      onPressed: _onBackspace,
                      icon: Icon(
                        Icons.backspace_outlined,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKeyButton(key)).toList(),
    );
  }

  Widget _buildKeyButton(String label) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _onKeyTap(label),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
