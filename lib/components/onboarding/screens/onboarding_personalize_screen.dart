import 'package:flutter/material.dart';

import '../../../widgets/brand_icons.dart';
import '../onboarding_style.dart';
import '../onboarding_v1_constants.dart';
import '../widgets/onboarding_full_screen_shell.dart';
import '../widgets/onboarding_progress_header.dart';
import '../widgets/onboarding_selectable_chip.dart';

abstract final class OnboardingPersonalizeLabels {
  static const Map<String, String> goalLabels = <String, String>{
    'growth': 'Grow my audience',
    'monetization': 'Monetize',
    'ai_assistance': 'Get AI coaching',
    'networking': 'Connect with creators',
    'content_creation': 'Plan my content',
    'streaming': 'Find community',
  };
}

class OnboardingPersonalizeScreen extends StatefulWidget {
  const OnboardingPersonalizeScreen({
    super.key,
    required this.initialGoals,
    required this.initialPlatforms,
    required this.onContinue,
    required this.onSkip,
    required this.onBack,
  });

  final List<String> initialGoals;
  final List<String> initialPlatforms;
  final ValueChanged<({List<String> goals, List<String> platforms})> onContinue;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  @override
  State<OnboardingPersonalizeScreen> createState() =>
      _OnboardingPersonalizeScreenState();
}

class _OnboardingPersonalizeScreenState
    extends State<OnboardingPersonalizeScreen> {
  late Set<String> _selectedGoals;
  late Set<String> _selectedPlatforms;

  @override
  void initState() {
    super.initState();
    _selectedGoals = widget.initialGoals.toSet();
    _selectedPlatforms = widget.initialPlatforms.toSet();
  }

  void _toggleGoal(String goal) {
    setState(() {
      if (_selectedGoals.contains(goal)) {
        _selectedGoals.remove(goal);
      } else {
        _selectedGoals.add(goal);
      }
    });
  }

  void _togglePlatform(String platform) {
    setState(() {
      if (_selectedPlatforms.contains(platform)) {
        _selectedPlatforms.remove(platform);
      } else {
        _selectedPlatforms.add(platform);
      }
    });
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: OnboardingStyle.plainTextStyle(
        TextStyle(
          color: OnboardingStyle.textSecondaryFor(context),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildChipWrap({
    required Iterable<String> items,
    required Set<String> selected,
    required ValueChanged<String> onToggle,
    required String? Function(String id) labelFor,
    String? Function(String id)? emojiFor,
    Widget? Function(String id)? leadingFor,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((String id) {
        return OnboardingSelectableChip(
          compact: true,
          label: labelFor(id) ?? id,
          emoji: emojiFor?.call(id),
          leading: leadingFor?.call(id),
          selected: selected.contains(id),
          onTap: () => onToggle(id),
        );
      }).toList(growable: false),
    );
  }

  Widget _platformBrandIcon(String platformId) {
    return BrandIcon(
      platformType: OnboardingPlatforms.brandIconPlatformKey(platformId),
      size: 20,
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScreenLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const OnboardingProgressHeader(
            step: 2,
            totalSteps: OnboardingV1Constants.totalSteps,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
              children: <Widget>[
                Text(
                  'STEP 2 OF 4',
                  style: OnboardingStyle.plainTextStyle(
                    TextStyle(
                      color: const Color(0xFF9248D2).withValues(alpha: 0.95),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'What\'s your creator focus?',
                  style: OnboardingStyle.titleFor(context, fontSize: 30),
                ),
                const SizedBox(height: 10),
                Text(
                  'Pick what fits — this personalises your experience.',
                  style: OnboardingStyle.bodyFor(context, fontSize: 15),
                ),
                const SizedBox(height: 28),
                _buildSectionLabel('I\'M HERE TO...'),
                const SizedBox(height: 12),
                _buildChipWrap(
                  items: OnboardingCreatorGoals.all,
                  selected: _selectedGoals,
                  onToggle: _toggleGoal,
                  labelFor: (String id) =>
                      OnboardingPersonalizeLabels.goalLabels[id] ??
                      OnboardingCreatorGoals.labels[id],
                  emojiFor: (String id) => OnboardingCreatorGoals.emojis[id],
                ),
                const SizedBox(height: 28),
                _buildSectionLabel('I CREATE ON...'),
                const SizedBox(height: 12),
                _buildChipWrap(
                  items: OnboardingPlatforms.all,
                  selected: _selectedPlatforms,
                  onToggle: _togglePlatform,
                  labelFor: (String id) => OnboardingPlatforms.labels[id],
                  leadingFor: _platformBrandIcon,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: SizedBox(
              width: double.infinity,
              child: GradientPillButton(
                useSolidPurple: true,
                label:
                    'Continue → +${OnboardingV1Constants.personalizeRewardXp} XP',
                onPressed: () => widget.onContinue((
                  goals: _selectedGoals.toList(),
                  platforms: _selectedPlatforms.toList(),
                )),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: Center(
              child: TextButton(
                onPressed: widget.onSkip,
                child: Text(
                  'Skip for now',
                  style: TextStyle(
                    color: OnboardingStyle.textSecondaryFor(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
