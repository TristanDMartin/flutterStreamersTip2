import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../account_status_client.dart';
import '../complete_verified_activation.dart';
import '../date_of_birth.dart';
import 'onboarding_login_footer.dart';

const String _kLockedMessage = "Sorry, you're not eligible to use StreamersTip.";

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
  int? _month;
  int? _day;
  int? _year;
  bool _isSaving = false;
  bool _isLocked = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isLocked = widget.isLocked;
  }

  DateOfBirthValidation? get _validation {
    if (_month == null || _day == null || _year == null) {
      return null;
    }
    return validateDateOfBirth(year: _year!, month: _month!, day: _day!);
  }

  bool get _canSubmit => !_isSaving && (_validation?.canSubmit ?? false);

  void _updateParts({int? month, int? day, int? year}) {
    setState(() {
      _month = month ?? _month;
      _year = year ?? _year;
      _day = day ?? _day;
      if (_month != null &&
          _day != null &&
          _day! > daysInDobMonth(month: _month!, year: _year ?? 2000)) {
        _day = null;
      }
      _error = null;
    });
  }

  Future<void> _submit() async {
    final String? iso = _validation?.isoDate;
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
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _isLocked = err.isAgeLocked;
        _error = err.isAgeLocked ? null : err.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _error = 'Could not save your birthday. Please try again.';
      });
    }
  }

  Future<void> _signOut() => fa.FirebaseAuth.instance.signOut();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.tippyBackground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: _isLocked ? _buildLocked() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildLocked() {
    return _BirthdayLockedPanel(onDone: () => unawaited(_signOut()));
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    widget.isReturningAccount ? 'ONE QUICK THING' : 'SIGN UP',
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
                  _BirthdaySelects(
                    month: _month,
                    day: _day,
                    year: _year,
                    isEnabled: !_isSaving,
                    onChanged: _updateParts,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Your birthday won't be shown publicly.",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 12),
                    SelectableText.rich(
                      TextSpan(
                        text: _error,
                        style: const TextStyle(color: Color(0xFFFF6B6B)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  _BirthdayNextButton(
                    isBusy: _isSaving,
                    onPressed: _canSubmit ? () => unawaited(_submit()) : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!widget.isReturningAccount)
          OnboardingLoginFooter(
            onLogIn: () => unawaited(_signOut()),
            isDisabled: _isSaving,
          ),
      ],
    );
  }
}

class _BirthdaySelects extends StatelessWidget {
  const _BirthdaySelects({
    required this.month,
    required this.day,
    required this.year,
    required this.isEnabled,
    required this.onChanged,
  });

  final int? month;
  final int? day;
  final int? year;
  final bool isEnabled;
  final void Function({int? month, int? day, int? year}) onChanged;

  @override
  Widget build(BuildContext context) {
    final int dayCount = daysInDobMonth(month: month ?? 1, year: year ?? 2000);
    return Row(
      children: <Widget>[
        Expanded(
          flex: 4,
          child: _BirthdayDropdown(
            hint: 'Month',
            value: month,
            isEnabled: isEnabled,
            items: List<int>.generate(12, (int i) => i + 1),
            labelFor: (int value) => kDobMonthLabels[value - 1].substring(0, 3),
            onChanged: (int? value) => onChanged(month: value),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: _BirthdayDropdown(
            hint: 'Day',
            value: day,
            isEnabled: isEnabled,
            items: List<int>.generate(dayCount, (int i) => i + 1),
            labelFor: (int value) => '$value',
            onChanged: (int? value) => onChanged(day: value),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: _BirthdayDropdown(
            hint: 'Year',
            value: year,
            isEnabled: isEnabled,
            items: dobYearOptions(),
            labelFor: (int value) => '$value',
            onChanged: (int? value) => onChanged(year: value),
          ),
        ),
      ],
    );
  }
}

class _BirthdayDropdown extends StatelessWidget {
  const _BirthdayDropdown({
    required this.hint,
    required this.value,
    required this.isEnabled,
    required this.items,
    required this.labelFor,
    required this.onChanged,
  });

  final String hint;
  final int? value;
  final bool isEnabled;
  final List<int> items;
  final String Function(int value) labelFor;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: items.contains(value) ? value : null,
      isExpanded: true,
      dropdownColor: const Color(0xFF1E293B),
      iconEnabledColor: Colors.white70,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      hint: Text(hint, style: const TextStyle(color: Colors.white54)),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xCC1E293B),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF475569)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF475569)),
        ),
      ),
      items: items
          .map(
            (int item) => DropdownMenuItem<int>(
              value: item,
              child: Text(labelFor(item)),
            ),
          )
          .toList(),
      onChanged: isEnabled ? onChanged : null,
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

class _BirthdayLockedPanel extends StatelessWidget {
  const _BirthdayLockedPanel({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          "You can't sign up right now",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _kLockedMessage,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 28),
        OutlinedButton(
          onPressed: onDone,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFF475569)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Back'),
        ),
      ],
    );
  }
}
