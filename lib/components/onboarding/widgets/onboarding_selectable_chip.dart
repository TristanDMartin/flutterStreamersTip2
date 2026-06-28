import 'package:flutter/material.dart';

import '../onboarding_style.dart';

class OnboardingSelectableChip extends StatelessWidget {
  const OnboardingSelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.emoji,
    this.leading,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? emoji;
  final Widget? leading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = selected
        ? const Color(0xFF9248D2)
        : OnboardingStyle.borderFor(context);
    final Color fillColor = selected
        ? const Color(0xFF9248D2).withValues(alpha: 0.18)
        : const Color(0xFF1E293B);
    final EdgeInsets chipPadding = compact
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 14);
    return AnimatedScale(
      scale: selected ? 1.02 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(compact ? 999 : 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: chipPadding,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(compact ? 999 : 16),
              border: Border.all(
                color: borderColor,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
              children: <Widget>[
                if (leading != null) ...<Widget>[
                  leading!,
                  SizedBox(width: compact ? 6 : 10),
                ] else if (emoji != null) ...<Widget>[
                  Text(emoji!, style: const TextStyle(fontSize: 16)),
                  SizedBox(width: compact ? 6 : 10),
                ],
                if (compact)
                  Text(
                    label,
                    style: TextStyle(
                      color: OnboardingStyle.textPrimaryFor(context),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 14,
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: OnboardingStyle.textPrimaryFor(context),
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                if (selected && !compact)
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
