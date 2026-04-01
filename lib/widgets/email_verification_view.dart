import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../routing/app_navigator.dart';
import '../services/pending_auth_redirect_service.dart';

class EmailVerificationView extends ConsumerStatefulWidget {
  final String email;
  final VoidCallback? onVerified;
  final VoidCallback? onSkip;

  const EmailVerificationView({
    super.key,
    required this.email,
    this.onVerified,
    this.onSkip,
  });

  @override
  ConsumerState<EmailVerificationView> createState() =>
      _EmailVerificationViewState();
}

class _EmailVerificationViewState extends ConsumerState<EmailVerificationView> {
  bool _isCheckingVerification = false;
  bool _isResendingEmail = false;
  String _statusMessage = "";
  Timer? _verificationCheckTimer;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _setSystemUIOverlayStyle();
    _sendVerificationEmail();
    _startAutoVerificationCheck();
  }

  void _setSystemUIOverlayStyle() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF1C135D),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _verificationCheckTimer?.cancel();
    _cooldownTimer?.cancel();
    _resetSystemUIOverlayStyle();
    super.dispose();
  }

  void _resetSystemUIOverlayStyle() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _startAutoVerificationCheck() {
    _verificationCheckTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkEmailVerification(silent: true);
    });
  }

  Future<void> _sendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        debugPrint("✉️ Verification email sent to ${widget.email}");
        setState(() {
          _statusMessage = "Verification email sent!";
        });
      }
    } catch (e) {
      debugPrint("❌ Error sending verification email: $e");
      setState(() {
        _statusMessage = "Error sending email. Please try again.";
      });
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_resendCooldown > 0) {
      setState(() {
        _statusMessage =
            "Please wait $_resendCooldown seconds before resending";
      });
      return;
    }
    setState(() {
      _isResendingEmail = true;
      _statusMessage = "";
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        setState(() {
          _statusMessage = "Verification email sent!";
          _resendCooldown = 60;
        });
        _startCooldownTimer();
        debugPrint("✉️ Verification email resent to ${widget.email}");
      }
    } catch (e) {
      debugPrint("❌ Error resending verification email: $e");
      setState(() {
        _statusMessage = _getErrorMessage(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResendingEmail = false;
        });
      }
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        setState(() {
          _resendCooldown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _checkEmailVerification({bool silent = false}) async {
    if (_isCheckingVerification) return;
    setState(() {
      _isCheckingVerification = true;
      if (!silent) {
        _statusMessage = "Checking verification status...";
      }
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        final refreshedUser = FirebaseAuth.instance.currentUser;
        if (refreshedUser != null && refreshedUser.emailVerified) {
          debugPrint("✅ Email verified!");
          _verificationCheckTimer?.cancel();
          setState(() {
            _statusMessage = "Email verified! Redirecting...";
          });
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            widget.onVerified?.call();
            PendingAuthRedirectService.instance.consumeOrGoHome(context);
          }
        } else if (!silent) {
          setState(() {
            _statusMessage = "Email not verified yet. Please check your inbox.";
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Error checking verification: $e");
      if (!silent && mounted) {
        setState(() {
          _statusMessage = "Error checking verification. Please try again.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingVerification = false;
        });
      }
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('too-many-requests')) {
      return 'Too many requests. Please try again later.';
    } else if (error.contains('network')) {
      return 'Network error. Please check your connection.';
    } else {
      return 'An error occurred. Please try again.';
    }
  }

  Future<void> _handleSkip() async {
    final shouldSkip = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          "Skip Verification?",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          "You can verify your email later in settings. Some features may be limited until verification.",
          style: TextStyle(color: Colors.white70, height: 1.3),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              "Skip",
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );

    if (shouldSkip == true && mounted) {
      widget.onSkip?.call();
      PendingAuthRedirectService.instance.consumeOrGoHome(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildHeader(),
                  const Spacer(),
                  _buildVerificationContent(),
                  const Spacer(),
                  _buildActionButtons(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        TextButton(
          onPressed: _handleSkip,
          child: const Text(
            "Skip",
            style: TextStyle(color: Colors.orange),
          ),
        ),
        const Spacer(),
        const Text(
          "Verify Email",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        const Text(
          "Skip",
          style: TextStyle(color: Colors.transparent),
        ),
      ],
    );
  }

  Widget _buildVerificationContent() {
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
          "Verify Your Email",
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          "We've sent a verification email to:",
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
        const SizedBox(height: 24),
        const Text(
          "Please check your inbox and click the verification link.",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        if (_statusMessage.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusMessage,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildButton(
          text: _isCheckingVerification
              ? "Checking..."
              : "I've Verified My Email",
          onTap: _isCheckingVerification
              ? null
              : () => _checkEmailVerification(silent: false),
          isPrimary: true,
        ),
        const SizedBox(height: 16),
        _buildButton(
          text: _isResendingEmail
              ? "Sending..."
              : _resendCooldown > 0
                  ? "Resend Email ($_resendCooldown)"
                  : "Resend Verification Email",
          onTap: _isResendingEmail || _resendCooldown > 0
              ? null
              : _resendVerificationEmail,
          isPrimary: false,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              AppNavigator.replaceWithAuth(context);
            }
          },
          child: const Text(
            "Use Different Email",
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String text,
    required VoidCallback? onTap,
    required bool isPrimary,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            gradient: isPrimary
                ? const LinearGradient(
                    colors: [Color(0xFF955CFF), Color(0xFF3D99F7)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: isPrimary ? null : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: isPrimary
                ? null
                : Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
          ),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
