import 'package:flutter/material.dart';

import 'onboarding_style.dart';

class OnboardingIntroModal extends StatefulWidget {
  const OnboardingIntroModal({
    super.key,
    required this.onComplete,
    this.onSkip,
    this.onWatchQuickTour,
  });

  final ValueChanged<String> onComplete;
  final VoidCallback? onSkip;
  final ValueChanged<String>? onWatchQuickTour;

  @override
  State<OnboardingIntroModal> createState() => _OnboardingIntroModalState();
}

class _OnboardingIntroModalState extends State<OnboardingIntroModal> {
  String? _creatorGoal;

  static const Map<String, String> _goals = <String, String>{
    'grow_audience': 'Grow my audience',
    'stay_consistent': 'Stay consistent',
    'improve_content': 'Improve my content',
    'network': 'Network with creators',
    'monetize': 'Get ready to monetize',
  };

  void _startExploring() {
    final String selected = _creatorGoal ?? 'grow_audience';
    widget.onComplete(selected);
  }

  void _watchQuickTour() {
    final String selected = _creatorGoal ?? 'grow_audience';
    widget.onWatchQuickTour?.call(selected);
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final double width = size.width.clamp(0, 420).toDouble();
    final bool compact = size.height < 720 || size.width < 380;
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final double maxSheetHeight =
        size.height - padding.top - padding.bottom - 44;
    return Material(
      key: const Key('onboarding-intro-modal'),
      color: Colors.transparent,
      child: Container(
        width: width,
        decoration: OnboardingStyle.cardDecoration(context: context),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxSheetHeight.clamp(340.0, 520.0),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  compact ? 18 : 24,
                  compact ? 16 : 22,
                  compact ? 18 : 24,
                  12,
                ),
                child: Column(
                  children: <Widget>[
                    const _WelcomeMark(),
                    SizedBox(height: compact ? 14 : 18),
                    Text(
                      'Create. Share. Grow with creators.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: OnboardingStyle.textPrimaryFor(context),
                        fontSize: compact ? 24 : 29,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tap around. We will guide you as you explore.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: OnboardingStyle.textSecondaryFor(context),
                        fontSize: compact ? 14 : 16,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: compact ? 16 : 20),
                    _GoalScreen(
                      goals: _goals,
                      selectedGoal: _creatorGoal,
                      onSelected: (String value) {
                        setState(() => _creatorGoal = value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 16,
                0,
                compact ? 12 : 16,
                compact ? 10 : 14,
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: <Widget>[
                  if (widget.onWatchQuickTour != null)
                    TextButton(
                      onPressed: _watchQuickTour,
                      child: Text(
                        'Watch Quick Tour',
                        style: TextStyle(
                          color: OnboardingStyle.textSecondaryFor(context),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (widget.onSkip != null)
                    TextButton(
                      onPressed: widget.onSkip,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: OnboardingStyle.textSecondaryFor(context),
                        ),
                      ),
                    ),
                  GradientPillButton(
                    key: const Key('onboarding-start-button'),
                    label: 'Start Exploring',
                    onPressed: _startExploring,
                    icon: Icons.explore_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeMark extends StatelessWidget {
  const _WelcomeMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        gradient: OnboardingStyle.primaryGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF9248D2).withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 34,
      ),
    );
  }
}

class _GoalScreen extends StatelessWidget {
  const _GoalScreen({
    required this.goals,
    required this.selectedGoal,
    required this.onSelected,
  });

  final Map<String, String> goals;
  final String? selectedGoal;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final bool compact = size.height < 720 || size.width < 380;
    final bool light = OnboardingStyle.isLight(context);
    final Color textPrimary = OnboardingStyle.textPrimaryFor(context);
    final Color textSecondary = OnboardingStyle.textSecondaryFor(context);
    final Color border = OnboardingStyle.borderFor(context);
    final Color chipBackground =
        light ? const Color(0xFFF8FAFC) : Colors.white.withValues(alpha: 0.08);
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'What are you focused on right now?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textPrimary,
              fontSize: compact ? 21 : 26,
              fontWeight: FontWeight.w900,
              height: 1.08,
            ),
          ),
          SizedBox(height: compact ? 5 : 7),
          Text(
            'Pick one focus for smarter tips.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textSecondary,
              fontSize: compact ? 13 : 14,
              height: 1.35,
            ),
          ),
          SizedBox(height: compact ? 14 : 20),
          Wrap(
            spacing: compact ? 8 : 10,
            runSpacing: compact ? 8 : 10,
            alignment: WrapAlignment.center,
            children: goals.entries.map((MapEntry<String, String> entry) {
              final bool selected = selectedGoal == entry.key;
              return ChoiceChip(
                key: entry.key == 'grow_audience'
                    ? const Key('creator-goal-grow-audience')
                    : Key('creator-goal-${entry.key}'),
                selected: selected,
                showCheckmark: true,
                checkmarkColor: Colors.white,
                onSelected: (_) => onSelected(entry.key),
                backgroundColor: chipBackground,
                selectedColor: const Color(0xFF4897D2),
                side: BorderSide(
                  color:
                      selected ? Colors.white.withValues(alpha: 0.35) : border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                labelPadding: EdgeInsets.symmetric(
                  horizontal: compact ? 9 : 12,
                  vertical: compact ? 6 : 8,
                ),
                label: Text(
                  entry.value,
                  style: TextStyle(
                    color: selected ? Colors.white : textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 12.5 : 14,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
