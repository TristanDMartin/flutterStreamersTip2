import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../account_status_client.dart';
import '../complete_verified_activation.dart';
import 'birthday_locked_screen.dart';
import 'date_of_birth_selects.dart';
import 'onboarding_login_footer.dart';

/// Mirrors web `/onboarding/birthday`. The DOB is private and written once.
class BirthdayStepView extends StatefulWidget {
  const BirthdayStepView({
    super.key,
    required this.onCompleted,
    this.isReturningAccount = false,
    this.isLocked = false,
  });

  final VoidCallback onCompleted;
  final bool isReturningAccount;
  final bool isLocked;

  @override
  State<BirthdayStepView> createState() => _BirthdayStepViewState();
}

class _BirthdayStepViewState extends State<BirthdayStepView> {
  DateOfBirthParts _parts = const DateOfBirthParts();
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.isLocked) {
      unawaited(signOutWithBirthdayLockedNotice());
    }
  }

  bool get _canSubmit =>
      !_isSaving && (_parts.validation?.canSubmit ?? false);

  Future<void> _submit() async {
    final String? iso = _parts.validation?.isoDate;
    if (!_canSubmit || iso == null) {
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await saveDateOfBirth(iso);
      final AccountStatusSnapshot status = await fetchAccountStatus(force: true);
      final fa.User? user = fa.FirebaseAuth.instance.currentUser;
      if (!status.provisioned && user != null && user.emailVerified) {
        await completeVerifiedActivation(intendedUid: user.uid);
      }
      if (mounted) {
        widget.onCompleted();
      }
    } on DateOfBirthSaveException catch (err) {
      if (err.isAgeLocked) {
        await signOutWithBirthdayLockedNotice();
        return;
      }
      _showError(err.message);
    } catch (_) {
      _showError('Could not save your birthday. Please try again.');
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLocked) {
      return const ColoredBox(color: AppColors.tippyBackground);
    }
    return Material(
      color: AppColors.tippyBackground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: _BirthdayForm(
                      isReturningAccount: widget.isReturningAccount,
                      parts: _parts,
                      isSaving: _isSaving,
                      error: _error,
                      onChanged: (DateOfBirthParts next) => setState(() {
                        _parts = next;
                        _error = null;
                      }),
                      onSubmit:
                          _canSubmit ? () => unawaited(_submit()) : null,
                    ),
                  ),
                ),
              ),
              if (!widget.isReturningAccount)
                OnboardingLoginFooter(
                  onLogIn: () => unawaited(fa.FirebaseAuth.instance.signOut()),
                  isDisabled: _isSaving,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BirthdayForm extends StatelessWidget {
  const _BirthdayForm({
    required this.isReturningAccount,
    required this.parts,
    required this.isSaving,
    required this.error,
    required this.onChanged,
    required this.onSubmit,
  });

  final bool isReturningAccount;
  final DateOfBirthParts parts;
  final bool isSaving;
  final String? error;
  final ValueChanged<DateOfBirthParts> onChanged;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          isReturningAccount ? 'ONE QUICK THING' : 'SIGN UP',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "When's your birthday?",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 28),
        DateOfBirthSelects(
          value: parts,
          onChanged: onChanged,
          isEnabled: !isSaving,
        ),
        const SizedBox(height: 12),
        Text(
          "Your birthday won't be shown publicly.",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: 12),
          SelectableText.rich(
            TextSpan(
              text: error,
              style: const TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
        ],
        const SizedBox(height: 28),
        _BirthdayNextButton(isBusy: isSaving, onPressed: onSubmit),
      ],
    );
  }
}

class _BirthdayNextButton extends StatelessWidget {
  const _BirthdayNextButton({required this.isBusy, required this.onPressed});

  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFF6B3AA0), Color(0xFF4A2570)],
          ),
        ),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            foregroundColor: Colors.white,
          ),
          child: Text(
            isBusy ? 'Saving…' : 'Next',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
