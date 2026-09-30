import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';

/// "Already have an account? Log in" — pinned at the bottom of signup steps.
class OnboardingLoginFooter extends StatelessWidget {
  const OnboardingLoginFooter({
    super.key,
    required this.onLogIn,
    this.isDisabled = false,
  });

  final VoidCallback onLogIn;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          'Already have an account?',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
        TextButton(
          onPressed: isDisabled ? null : onLogIn,
          child: const Text(
            'Log in',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
