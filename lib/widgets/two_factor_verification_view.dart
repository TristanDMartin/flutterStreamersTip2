import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/two_factor_auth_service.dart';

class TwoFactorVerificationView extends ConsumerStatefulWidget {
  final String userId;
  final Function(bool) onVerified;
  final Function()? onCancel;

  const TwoFactorVerificationView({
    super.key,
    required this.userId,
    required this.onVerified,
    this.onCancel,
  });

  @override
  ConsumerState<TwoFactorVerificationView> createState() =>
      _TwoFactorVerificationViewState();
}

class _TwoFactorVerificationViewState
    extends ConsumerState<TwoFactorVerificationView> {
  final TextEditingController _codeController = TextEditingController();
  final TwoFactorAuthService _twoFactorService = TwoFactorAuthService();
  bool _isVerifying = false;
  bool _useBackupCode = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    setState(() {
      _isVerifying = true;
      _errorMessage = '';
    });

    try {
      final code = _codeController.text.trim();
      if (code.length != 6) {
        setState(() {
          _errorMessage = 'Please enter a 6-digit code';
          _isVerifying = false;
        });
        return;
      }

      bool isValid;
      if (_useBackupCode) {
        isValid = await _twoFactorService.verifyBackupCode(
          userId: widget.userId,
          code: code,
        );
      } else {
        isValid = await _twoFactorService.verify2FACode(
          userId: widget.userId,
          code: code,
        );
      }

      if (isValid && mounted) {
        widget.onVerified(true);
      } else {
        setState(() {
          _errorMessage = 'Invalid code. Please try again.';
          _isVerifying = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Verification failed: $e';
        _isVerifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C135D),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Two-Factor Verification',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _useBackupCode
                      ? 'Enter your backup code'
                      : 'Enter the 6-digit code from your authenticator app',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _errorMessage.isNotEmpty
                          ? Colors.red
                          : Colors.white.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: _useBackupCode ? null : 6,
                    textAlign: TextAlign.center,
                    autofocus: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 12,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      hintText: _useBackupCode ? 'Backup code' : '000000',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 32,
                        letterSpacing: 12,
                        fontFamily: 'monospace',
                      ),
                      contentPadding: const EdgeInsets.all(20),
                    ),
                    onSubmitted: (_) => _verifyCode(),
                  ),
                ),
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF955CFF),
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _isVerifying
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Verify',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                if (!_useBackupCode)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _useBackupCode = true;
                        _errorMessage = '';
                        _codeController.clear();
                      });
                    },
                    child: Text(
                      'Use a backup code instead',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ),
                if (_useBackupCode)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _useBackupCode = false;
                        _errorMessage = '';
                        _codeController.clear();
                      });
                    },
                    child: Text(
                      'Use authenticator code',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                if (widget.onCancel != null)
                  TextButton(
                    onPressed: widget.onCancel,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
