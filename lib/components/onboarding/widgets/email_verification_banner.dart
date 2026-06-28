import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../onboarding_service.dart';

class EmailVerificationBanner extends StatefulWidget {
  const EmailVerificationBanner({
    super.key,
    required this.userId,
    required this.email,
    this.service,
    this.onDismissed,
  });

  final String userId;
  final String email;
  final OnboardingService? service;
  final VoidCallback? onDismissed;

  @override
  State<EmailVerificationBanner> createState() =>
      _EmailVerificationBannerState();
}

class _EmailVerificationBannerState extends State<EmailVerificationBanner> {
  late final OnboardingService _service;
  bool _isResending = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? OnboardingService();
  }

  Future<void> _resendEmail() async {
    if (_isResending) {
      return;
    }
    setState(() {
      _isResending = true;
      _statusMessage = null;
    });
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        if (mounted) {
          setState(() {
            _statusMessage = 'Verification email sent!';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Could not resend. Try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _dismiss() async {
    await _service.dismissEmailBanner(widget.userId);
    widget.onDismissed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFEF3C7),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(
              Icons.mail_outline_rounded,
              color: Color(0xFF92400E),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Verify your email to unlock tipping and DMs',
                    style: TextStyle(
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  if (_statusMessage != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      _statusMessage!,
                      style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _isResending ? null : _resendEmail,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _isResending ? 'Sending...' : 'Resend →',
                      style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _dismiss,
              icon: const Icon(
                Icons.close_rounded,
                color: Color(0xFF92400E),
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
