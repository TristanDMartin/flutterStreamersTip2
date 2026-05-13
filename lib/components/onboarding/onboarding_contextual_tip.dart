import 'package:flutter/material.dart';

import 'onboarding_style.dart';

class OnboardingContextualTip extends StatelessWidget {
  const OnboardingContextualTip({
    super.key,
    required this.title,
    required this.body,
    required this.onDismiss,
  });

  final String title;
  final String body;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: OnboardingStyle.cardDecoration(context: context, radius: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: OnboardingStyle.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(8),
              child:
                  Icon(Icons.lightbulb_rounded, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    color: OnboardingStyle.textPrimaryFor(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: OnboardingStyle.textSecondaryFor(context),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: onDismiss,
            icon: Icon(
              Icons.close_rounded,
              color: OnboardingStyle.textSecondaryFor(context),
            ),
          ),
        ],
      ),
    );
  }
}
