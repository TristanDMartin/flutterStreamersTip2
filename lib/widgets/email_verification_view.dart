import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../routing/app_navigator.dart';
import '../services/robust_auth_service.dart';
import '../services/pending_auth_redirect_service.dart';
import '../components/onboarding/email_verification.dart';
import '../components/onboarding/email_verification_sender.dart';
import '../components/onboarding/complete_verified_activation.dart';

enum EmailVerificationDisplayMode { gate, banner }

class EmailVerificationView extends ConsumerStatefulWidget {
  final String email;
  final VoidCallback? onVerified;

  /// When true (default), verified users run [PendingAuthRedirectService.consumeOrGoHome].
  /// Set false when this widget is embedded in a shell that should rebuild instead.
  final bool navigateToHomeOnVerify;

  final EmailVerificationDisplayMode mode;
  final VoidCallback? onContinueToSetup;

  /// When false, system UI is managed by an outer shell (e.g. onboarding gate).
  final bool manageSystemUi;

  const EmailVerificationView({
    super.key,
    required this.email,
    this.onVerified,
    this.navigateToHomeOnVerify = true,
    this.mode = EmailVerificationDisplayMode.gate,
    this.onContinueToSetup,
    this.manageSystemUi = true,
  });

  @override
  ConsumerState<EmailVerificationView> createState() =>
      _EmailVerificationViewState();
}

class _EmailVerificationViewState extends ConsumerState<EmailVerificationView>
    with WidgetsBindingObserver {
  bool _isCheckingVerification = false;
  bool _isResendingEmail = false;
  String _statusMessage = "";
  Timer? _verificationCheckTimer;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  late final String _intendedUid;
  late final String _intendedEmail;

  @override
  void initState() {
    super.initState();
    if (widget.manageSystemUi) {
      _setSystemUIOverlayStyle();
    }
    _intendedUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _intendedEmail = widget.email;
    WidgetsBinding.instance.addObserver(this);
    _sendVerificationEmail();
    _startAutoVerificationCheck();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkEmailVerification(silent: true));
    }
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
    WidgetsBinding.instance.removeObserver(this);
    if (widget.manageSystemUi) {
      _resetSystemUIOverlayStyle();
    }
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
        Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkEmailVerification(silent: true);
    });
  }

  Future<void> _sendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null &&
          !user.emailVerified &&
          _intendedUid.isNotEmpty &&
          user.uid == _intendedUid) {
        await sendBoundEmailVerification(user: user);
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
      if (user != null &&
          !user.emailVerified &&
          _intendedUid.isNotEmpty &&
          user.uid == _intendedUid) {
        await sendBoundEmailVerification(user: user);
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
    });

    try {
      final VerificationIdentityResult result =
          await confirmBoundEmailVerification(
        intendedUid: _intendedUid,
        intendedEmail: _intendedEmail,
      );
      if (result.status == VerificationIdentityStatus.mismatch) {
        if (!silent && mounted) {
          setState(() {
            _statusMessage =
                'This app is signed in as a different account. Sign in as $_intendedEmail to continue.';
          });
        }
        return;
      }
      if (result.status == VerificationIdentityStatus.ready) {
        _verificationCheckTimer?.cancel();
        if (mounted) {
          setState(() {
            _statusMessage = 'Email verified\nContinuing…';
          });
        }
        try {
          await completeVerifiedActivation(
            intendedUid: _intendedUid.isEmpty ? null : _intendedUid,
          );
        } on VerifiedActivationException catch (error) {
          if (error.code == 'EMAIL_VERIFICATION_REQUIRED') {
            if (!silent && mounted) {
              setState(() {
                _statusMessage =
                    'Email not verified yet. Please check your inbox.';
              });
            }
            return;
          }
          if (mounted) {
            setState(() {
              _statusMessage = kVerifiedActivationPersistentError;
            });
          }
          return;
        }
        if (mounted) {
          widget.onVerified?.call();
          if (widget.navigateToHomeOnVerify) {
            PendingAuthRedirectService.instance.consumeOrGoHome(context);
          }
        }
      } else if (!silent) {
        setState(() {
          _statusMessage = "Email not verified yet. Please check your inbox.";
        });
      }
    } catch (e) {
      debugPrint("❌ Error checking verification: $e");
      if (!silent && mounted) {
        setState(() {
          _statusMessage = kVerifiedActivationPersistentError;
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

  Future<void> _handleSignOut() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Sign out?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Verify your email to use StreamersTip. Sign out and log back '
          'in after you verify.',
          style: TextStyle(color: Colors.white70, height: 1.3),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Sign out',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(robustAuthServiceProvider).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == EmailVerificationDisplayMode.banner) {
      return _buildBannerMode(context);
    }
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: <Widget>[
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
    );
  }

  Widget _buildBannerMode(BuildContext context) {
    return Material(
      color: const Color(0xFFFEF3C7),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              const Icon(Icons.mail_outline_rounded, color: Color(0xFF92400E)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Verify your email to unlock tipping and DMs',
                  style: TextStyle(
                    color: const Color(0xFF92400E),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed:
                    _isResendingEmail ? null : _resendVerificationEmail,
                child: Text(
                  _isResendingEmail ? 'Sending...' : 'Resend →',
                  style: const TextStyle(
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleContinueToSetup() {
    widget.onContinueToSetup?.call();
    if (widget.onContinueToSetup != null) {
      return;
    }
    PendingAuthRedirectService.instance.consumeOrGoHome(context);
  }

  Widget _buildHeader() {
    return Row(
      children: [
        if (widget.onContinueToSetup != null)
          TextButton(
            onPressed: _handleContinueToSetup,
            child: const Text(
              'Skip for now',
              style: TextStyle(color: Colors.white70),
            ),
          )
        else
          TextButton(
            onPressed: _handleSignOut,
            child: const Text(
              'Sign out',
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
        const SizedBox(width: 56),
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
          text: 'Continue to Setup',
          onTap: _handleContinueToSetup,
          isPrimary: true,
        ),
        const SizedBox(height: 16),
        _buildButton(
          text: _isCheckingVerification
              ? "Checking..."
              : "I've Verified My Email",
          onTap: _isCheckingVerification
              ? null
              : () => _checkEmailVerification(silent: false),
          isPrimary: false,
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
            await ref.read(robustAuthServiceProvider).signOut();
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
