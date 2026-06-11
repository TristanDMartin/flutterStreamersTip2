import 'package:flutter/material.dart';

import '../onboarding_style.dart';
import '../onboarding_v1_constants.dart';
import '../widgets/onboarding_progress_header.dart';
import '../widgets/onboarding_selectable_chip.dart';

class OnboardingPlatformsScreen extends StatefulWidget {
  const OnboardingPlatformsScreen({
    super.key,
    required this.initialPlatforms,
    required this.onContinue,
    required this.onBack,
  });

  final List<String> initialPlatforms;
  final ValueChanged<List<String>> onContinue;
  final VoidCallback onBack;

  @override
  State<OnboardingPlatformsScreen> createState() =>
      _OnboardingPlatformsScreenState();
}

class _OnboardingPlatformsScreenState extends State<OnboardingPlatformsScreen> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialPlatforms.toSet();
  }

  void _toggle(String platform) {
    setState(() {
      if (_selected.contains(platform)) {
        _selected.remove(platform);
      } else {
        _selected.add(platform);
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
              step: 3,
              totalSteps: OnboardingV1Constants.totalSteps,
              showBack: true,
              onBack: widget.onBack,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Text(
                'Where do you create?',
                style: TextStyle(
                  color: OnboardingStyle.textPrimaryFor(context),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                'Select all platforms you use.',
                style: TextStyle(
                  color: OnboardingStyle.textSecondaryFor(context),
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                itemCount: OnboardingPlatforms.all.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (BuildContext context, int index) {
                  final String platform = OnboardingPlatforms.all[index];
                  return OnboardingSelectableChip(
                    label: OnboardingPlatforms.labels[platform] ?? platform,
                    selected: _selected.contains(platform),
                    onTap: () => _toggle(platform),
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
