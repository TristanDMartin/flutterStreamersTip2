import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/email_verification_feature_gate.dart';

Future<bool> showEmailVerificationRequiredSheet({
  required BuildContext context,
  required EmailVerificationGatedFeature feature,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      return _EmailVerificationRequiredSheet(feature: feature);
    },
  ).then((bool? value) => value == true);
}

class _EmailVerificationRequiredSheet extends StatefulWidget {
  const _EmailVerificationRequiredSheet({required this.feature});

  final EmailVerificationGatedFeature feature;

  @override
  State<_EmailVerificationRequiredSheet> createState() =>
      _EmailVerificationRequiredSheetState();
}

class _EmailVerificationRequiredSheetState
    extends State<_EmailVerificationRequiredSheet> {
  bool _isResending = false;
  bool _isChecking = false;
  String? _statusMessage;

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
          _statusMessage = 'Could not resend. Try again shortly.';
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

  Future<void> _checkVerified() async {
    if (_isChecking) {
      return;
    }
    setState(() {
      _isChecking = true;
      _statusMessage = 'Checking verification...';
    });
    final bool verified =
        await EmailVerificationFeatureGate.refreshVerificationStatus();
    if (!mounted) {
      return;
    }
    if (verified) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isChecking = false;
      _statusMessage = 'Email not verified yet. Check your inbox.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final String email = user?.email ?? '';
    return Material(
      color: const Color(0xFF0F172A),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.mail_outline_rounded,
                      color: Color(0xFF92400E),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            EmailVerificationFeatureGate.titleFor(
                              widget.feature,
                            ),
                            style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            EmailVerificationFeatureGate.messageFor(
                              widget.feature,
                            ),
                            style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (email.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (_statusMessage != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _statusMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isChecking ? null : _checkVerified,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF6C47FF),
                ),
                child: Text(
                  _isChecking ? 'Checking...' : 'I\'ve verified my email',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _isResending ? null : _resendEmail,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _isResending ? 'Sending...' : 'Resend verification email',
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Not now',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
