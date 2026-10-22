import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/pin_input.dart';
import '../services/storage_service.dart';

/// PIN verification screen with progressive rate-limiting against brute force attacks.
class PinVerifyScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  final String title;

  const PinVerifyScreen({
    super.key,
    required this.onSuccess,
    this.title = 'Enter PIN',
  });

  @override
  State<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends State<PinVerifyScreen> {
  String? _errorText;
  int _attempts = 0;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _startLockout(int seconds) {
    setState(() {
      _lockoutSeconds = seconds;
      _errorText = 'Too many failed attempts. Try again in ${_lockoutSeconds}s';
    });
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockoutSeconds <= 1) {
        timer.cancel();
        setState(() {
          _lockoutSeconds = 0;
          _errorText = null;
        });
      } else {
        setState(() {
          _lockoutSeconds--;
          _errorText = 'Too many failed attempts. Try again in ${_lockoutSeconds}s';
        });
      }
    });
  }

  void _onPinComplete(String pin) async {
    if (_lockoutSeconds > 0) return;

    final isValid = await StorageService.verifyPin(pin);
    if (isValid) {
      _attempts = 0;
      widget.onSuccess();
    } else {
      _attempts++;
      if (_attempts >= 5) {
        _startLockout(30);
      } else {
        setState(() {
          _errorText = _attempts >= 3
              ? 'Wrong PIN ($_attempts attempts)'
              : 'Wrong PIN. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: IgnorePointer(
          ignoring: _lockoutSeconds > 0,
          child: PinInput(
            key: ValueKey('$_errorText-$_lockoutSeconds'),
            title: widget.title,
            subtitle: _lockoutSeconds > 0
                ? 'Keypad temporarily locked'
                : 'Enter your PIN to continue',
            onPinComplete: _onPinComplete,
            errorText: _errorText,
          ),
        ),
      ),
    );
  }
}
