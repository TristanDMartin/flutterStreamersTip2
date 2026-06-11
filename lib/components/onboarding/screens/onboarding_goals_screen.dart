import 'package:flutter/material.dart';

import '../onboarding_style.dart';
import '../onboarding_v1_constants.dart';
import '../widgets/onboarding_progress_header.dart';
import '../widgets/onboarding_selectable_chip.dart';

class OnboardingGoalsScreen extends StatefulWidget {
  const OnboardingGoalsScreen({
    super.key,
    required this.initialGoals,
    required this.onContinue,
    required this.onBack,
  });

  final List<String> initialGoals;
  final ValueChanged<List<String>> onContinue;
  final VoidCallback onBack;

  @override
  State<OnboardingGoalsScreen> createState() => _OnboardingGoalsScreenState();
}

class _OnboardingGoalsScreenState extends State<OnboardingGoalsScreen> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialGoals.toSet();
  }

  void _toggle(String goal) {
    setState(() {
      if (_selected.contains(goal)) {
        _selected.remove(goal);
      } else {
        _selected.add(goal);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool canContinue = _selected.isNotEmpty;
    return Container(
      color: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            OnboardingProgressHeader(
              step: 2,
              totalSteps: OnboardingV1Constants.totalSteps,
              showBack: true,
              onBack: widget.onBack,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Text(
                'What are you here to accomplish?',
                style: TextStyle(
                  color: OnboardingStyle.textPrimaryFor(context),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                'Pick all that apply — we\'ll personalize your experience.',
                style: TextStyle(
                  color: OnboardingStyle.textSecondaryFor(context),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                itemCount: OnboardingCreatorGoals.all.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (BuildContext context, int index) {
                  final String goal = OnboardingCreatorGoals.all[index];
                  return OnboardingSelectableChip(
                    label: OnboardingCreatorGoals.labels[goal] ?? goal,
                    emoji: OnboardingCreatorGoals.emojis[goal],
                    selected: _selected.contains(goal),
                    onTap: () => _toggle(goal),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: SizedBox(
                width: double.infinity,
                child: GradientPillButton(
                  label: 'Continue',
                  onPressed: canContinue
                      ? () => widget.onContinue(_selected.toList())
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
