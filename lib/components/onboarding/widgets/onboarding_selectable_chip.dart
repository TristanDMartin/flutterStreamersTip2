import 'package:flutter/material.dart';

import '../onboarding_style.dart';

class OnboardingSelectableChip extends StatelessWidget {
  const OnboardingSelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.emoji,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = selected
        ? const Color(0xFF9248D2)
        : OnboardingStyle.borderFor(context);
    final Color fillColor = selected
        ? const Color(0xFF9248D2).withValues(alpha: 0.18)
        : OnboardingStyle.surfaceFor(context);
    return AnimatedScale(
      scale: selected ? 1.02 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                if (emoji != null) ...<Widget>[
                  Text(emoji!, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: OnboardingStyle.textPrimaryFor(context),
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF9248D2),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
