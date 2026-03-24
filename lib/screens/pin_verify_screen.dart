import 'package:flutter/material.dart';
import '../widgets/pin_input.dart';
import '../services/storage_service.dart';

/// PIN verification screen for accessing settings or re-authenticating.
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

  void _onPinComplete(String pin) async {
    final isValid = await StorageService.verifyPin(pin);
    if (isValid) {
      widget.onSuccess();
    } else {
      _attempts++;
      setState(() {
        _errorText = _attempts >= 3
          ? 'Wrong PIN ($_attempts attempts)'
          : 'Wrong PIN. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: PinInput(
          key: ValueKey(_errorText),
          title: widget.title,
          subtitle: 'Enter your PIN to continue',
          onPinComplete: _onPinComplete,
          errorText: _errorText,
        ),
      ),
    );
  }
}
