import 'package:flutter/material.dart';

/// Custom PIN input widget with animated dots and a number pad.
class PinInput extends StatefulWidget {
  final int pinLength;
  final String title;
  final String subtitle;
  final ValueChanged<String> onPinComplete;
  final String? errorText;

  const PinInput({
    super.key,
    this.pinLength = 4,
    this.title = 'Enter PIN',
    this.subtitle = '',
    required this.onPinComplete,
    this.errorText,
  });

  @override
  State<PinInput> createState() => _PinInputState();
}

class _PinInputState extends State<PinInput> with SingleTickerProviderStateMixin {
  String _pin = '';
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12)
      .chain(CurveTween(curve: Curves.elasticIn))
      .animate(_shakeController);
  }

  @override
  void didUpdateWidget(PinInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If error text changed, trigger shake animation
    if (widget.errorText != null && widget.errorText != oldWidget.errorText) {
      _shakeController.forward(from: 0);
      setState(() => _pin = '');
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitPressed(int digit) {
    if (_pin.length >= widget.pinLength) return;
    setState(() {
      _pin += digit.toString();
    });
    if (_pin.length == widget.pinLength) {
      widget.onPinComplete(_pin);
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Lock icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6C63FF).withOpacity(0.2),
                const Color(0xFF6C63FF).withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(
            Icons.lock_outline_rounded,
            color: Color(0xFF6C63FF),
            size: 32,
          ),
        ),
        const SizedBox(height: 24),

        // Title
        Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        if (widget.subtitle.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            widget.subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
        const SizedBox(height: 40),

        // PIN dots
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                _shakeAnimation.value * ((_shakeController.value > 0.5) ? -1 : 1),
                0,
              ),
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.pinLength, (index) {
              final isFilled = index < _pin.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: isFilled ? 18 : 16,
                height: isFilled ? 18 : 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled 
                    ? const Color(0xFF6C63FF) 
                    : Colors.transparent,
                  border: Border.all(
                    color: isFilled 
                      ? const Color(0xFF6C63FF) 
                      : const Color(0xFF444444),
                    width: 2,
                  ),
                  boxShadow: isFilled 
                    ? [BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )]
                    : null,
                ),
              );
            }),
          ),
        ),

        // Error text
        if (widget.errorText != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.errorText!,
            style: const TextStyle(
              color: Color(0xFFCF6679),
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 48),

        // Number pad
        _buildNumberPad(),
      ],
    );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        _buildRow([1, 2, 3]),
        const SizedBox(height: 16),
        _buildRow([4, 5, 6]),
        const SizedBox(height: 16),
        _buildRow([7, 8, 9]),
        const SizedBox(height: 16),
        _buildBottomRow(),
      ],
    );
  }

  Widget _buildRow(List<int> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map((d) => _buildDigitButton(d)).toList(),
    );
  }

  Widget _buildBottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Empty space
        const SizedBox(width: 80, height: 72),
        _buildDigitButton(0),
        // Backspace
        SizedBox(
          width: 80,
          height: 72,
          child: IconButton(
            onPressed: _onBackspace,
            icon: Icon(
              Icons.backspace_outlined,
              color: Colors.white.withOpacity(0.7),
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDigitButton(int digit) {
    return Container(
      width: 80,
      height: 72,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onDigitPressed(digit),
          borderRadius: BorderRadius.circular(36),
          splashColor: const Color(0xFF6C63FF).withOpacity(0.2),
          highlightColor: const Color(0xFF6C63FF).withOpacity(0.1),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E1E2E),
              border: Border.all(
                color: const Color(0xFF333344),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                digit.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
