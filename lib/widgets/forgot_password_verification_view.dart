import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'reset_password_view.dart';

class ForgotPasswordVerificationView extends ConsumerStatefulWidget {
  final String email;

  const ForgotPasswordVerificationView({
    super.key,
    required this.email,
  });

  @override
  ConsumerState<ForgotPasswordVerificationView> createState() =>
      _ForgotPasswordVerificationViewState();
}

class _ForgotPasswordVerificationViewState
    extends ConsumerState<ForgotPasswordVerificationView> {
  final TextEditingController _codeController = TextEditingController();
  bool _showAlert = false;
  String _alertMessage = "";
  bool _isLoading = false;
  Timer? _resendTimer;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    _setSystemUIOverlayStyle();
    _sendVerificationEmail();
    _startResendTimer();
  }

  void _setSystemUIOverlayStyle() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _resendTimer?.cancel();
    _resetSystemUIOverlayStyle();
    super.dispose();
  }

  void _resetSystemUIOverlayStyle() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.black,
      ),
    );
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendVerificationEmail() async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: widget.email);
      debugPrint("✉️ Password reset email sent to ${widget.email}");
    } catch (e) {
      debugPrint("❌ Error sending password reset email: $e");
      if (mounted) {
        setState(() {
          _alertMessage = _getErrorMessage(e.toString());
          _showAlert = true;
        });
      }
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('user-not-found')) {
      return 'No account found with this email address';
    } else if (error.contains('invalid-email')) {
      return 'Invalid email address';
    } else if (error.contains('too-many-requests')) {
      return 'Too many requests. Please try again later';
    } else if (error.contains('network')) {
      return 'Network error. Please check your connection';
    } else {
      return 'Failed to send reset email. Please try again';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: const Color(0xFF1C135D),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: Stack(
          children: [
            GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
              },
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 40),
                        _buildForm(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_showAlert) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _showAlert = false),
                  child: Container(color: Colors.black54),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: AlertDialog(
                    backgroundColor: const Color(0xFF1C1C1E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                      "Error",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    content: Text(
                      _alertMessage.isEmpty
                          ? "Something went wrong."
                          : _alertMessage,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.3,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() => _showAlert = false),
                        child: const Text("OK"),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Verifying...",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
          ),
          const Expanded(
            child: SizedBox.shrink(),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.email_outlined,
            size: 60,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          "Enter verification code",
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "We've sent a verification code to:",
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          widget.email,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        _buildCodeTextField(),
        const SizedBox(height: 16),
        _buildContinueButton(),
        const SizedBox(height: 16),
        _buildResendSection(),
      ],
    );
  }

  Widget _buildCodeTextField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _handleContinue(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
        textAlign: TextAlign.center,
        maxLength: 6,
        decoration: InputDecoration(
          hintText: "000000",
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 18,
            letterSpacing: 2,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 20,
          ),
          counterText: '',
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    final isEnabled = _codeController.text.length == 6 && !_isLoading;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: isEnabled ? _handleContinue : null,
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF955CFF), Color(0xFF3D99F7)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              _isLoading ? "Verifying..." : "Continue",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResendSection() {
    return Column(
      children: [
        Text(
          "Didn't receive the code?",
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _resendCountdown > 0 ? null : _resendCode,
          child: Text(
            _resendCountdown > 0
                ? "Resend code in ${_resendCountdown}s"
                : "Resend code",
            style: TextStyle(
              fontSize: 16,
              color: _resendCountdown > 0
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.blue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _handleContinue() {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() {
        _alertMessage = "Please enter the complete 6-digit code";
        _showAlert = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // In a real app, you would verify the code here
    // For now, we'll simulate verification and navigate to reset password
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ResetPasswordView(
              email: widget.email,
              verificationCode: code,
            ),
          ),
        );
      }
    });
  }

  void _resendCode() {
    _sendVerificationEmail();
    _startResendTimer();
    setState(() {
      _alertMessage = "Verification code sent!";
      _showAlert = true;
    });
  }
}
