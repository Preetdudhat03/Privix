import 'package:flutter/material.dart';
import '../widgets/pin_input.dart';
import '../services/storage_service.dart';

/// First-time PIN setup screen.
/// Supports 4-digit or 6-digit PIN with confirmation step.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String? _firstPin;
  String? _errorText;
  bool _isConfirming = false;
  int _pinLength = 4;
  bool _isSaving = false;

  void _onPinComplete(String pin) async {
    if (!_isConfirming) {
      // First entry — save and ask for confirmation
      setState(() {
        _firstPin = pin;
        _isConfirming = true;
        _errorText = null;
      });
    } else {
      // Confirmation entry
      if (pin == _firstPin) {
        setState(() => _isSaving = true);
        await StorageService.savePin(pin);
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        setState(() {
          _errorText = 'PINs do not match. Try again.';
          _isConfirming = false;
          _firstPin = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: _isSaving
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
            )
          : Column(
              children: [
                const SizedBox(height: 20),
                // PIN length toggle
                if (!_isConfirming) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLengthChip(4),
                        const SizedBox(width: 12),
                        _buildLengthChip(6),
                      ],
                    ),
                  ),
                ],
                Expanded(
                  child: PinInput(
                    key: ValueKey('$_isConfirming-$_pinLength-$_errorText'),
                    pinLength: _pinLength,
                    title: _isConfirming ? 'Confirm PIN' : 'Create PIN',
                    subtitle: _isConfirming
                      ? 'Re-enter your $_pinLength-digit PIN'
                      : 'Choose a $_pinLength-digit PIN to protect your apps',
                    onPinComplete: _onPinComplete,
                    errorText: _errorText,
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildLengthChip(int length) {
    final isSelected = _pinLength == length;
    return GestureDetector(
      onTap: () => setState(() {
        _pinLength = length;
        _firstPin = null;
        _errorText = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isSelected 
            ? const Color(0xFF6C63FF) 
            : const Color(0xFF1E1E2E),
          border: Border.all(
            color: isSelected 
              ? const Color(0xFF6C63FF) 
              : const Color(0xFF333344),
          ),
        ),
        child: Text(
          '$length-digit',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
