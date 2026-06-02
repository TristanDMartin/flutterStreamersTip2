import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../components/onboarding/onboarding_style.dart';
import '../../../services/progression_service.dart';
import '../gamification_providers.dart';
import '../models/daily_mission_model.dart';
import '../models/gamification_celebration_state.dart';
import '../models/user_progress_bundle.dart';
import '../utils/gamification_constants.dart';

/// App-wide level-up and mission-complete celebrations from server state.
class GamificationCelebrationOverlay extends ConsumerStatefulWidget {
  const GamificationCelebrationOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<GamificationCelebrationOverlay> createState() =>
      _GamificationCelebrationOverlayState();
}

class _GamificationCelebrationOverlayState
    extends ConsumerState<GamificationCelebrationOverlay> {
  static const String _missionPrefsPrefix = 'gamification_celebrated_mission_';

  GamificationCelebrationState? _levelUpCelebration;
  DailyMissionModel? _missionCelebration;
  Map<String, String> _previousMissionStatus = <String, String>{};
  bool _levelUpDismissInFlight = false;
  bool _initializedBundle = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedBundle) {
      return;
    }
    _initializedBundle = true;
    final UserProgressBundle? bundle =
        ref.read(userProgressBundleProvider).valueOrNull;
    if (bundle != null) {
      unawaited(_onBundleUpdated(bundle));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UserProgressBundle>>(
      userProgressBundleProvider,
      (AsyncValue<UserProgressBundle>? _, AsyncValue<UserProgressBundle> next) {
        next.whenData(_onBundleUpdated);
      },
    );
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        if (_levelUpCelebration != null)
          _LevelUpCelebrationModal(
            celebration: _levelUpCelebration!,
            onClose: _dismissLevelUp,
          ),
        if (_levelUpCelebration == null && _missionCelebration != null)
          _MissionCelebrationModal(
            mission: _missionCelebration!,
            onClose: () => setState(() => _missionCelebration = null),
          ),
      ],
    );
  }

  Future<void> _onBundleUpdated(UserProgressBundle bundle) async {
    if (!mounted) {
      return;
    }
    final GamificationCelebrationState celebration = bundle.celebration;
    if (celebration.showLevelUpModal && _levelUpCelebration == null) {
      setState(() => _levelUpCelebration = celebration);
      unawaited(HapticFeedback.mediumImpact());
    }
    await _detectMissionCompletion(bundle.missions);
  }

  Future<void> _detectMissionCompletion(
      List<DailyMissionModel> missions) async {
    if (_levelUpCelebration != null || _missionCelebration != null) {
      _syncMissionStatuses(missions);
      return;
    }
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    for (final DailyMissionModel mission in missions) {
      final String id = mission.missionId.isNotEmpty
          ? mission.missionId
          : mission.templateId ?? mission.title;
      if (id.isEmpty) {
        continue;
      }
      final String prev = _previousMissionStatus[id] ?? '';
      final bool nowComplete = mission.isCompleted;
      final bool wasComplete =
          prev == 'completed' || prev == 'claimed' || prev == 'rewarded';
      if (nowComplete && !wasComplete && prev.isNotEmpty) {
        final String prefsKey = '$_missionPrefsPrefix${user.uid}_$id';
        if (prefs.getBool(prefsKey) != true) {
          await prefs.setBool(prefsKey, true);
          if (mounted) {
            setState(() => _missionCelebration = mission);
            unawaited(HapticFeedback.lightImpact());
          }
          break;
        }
      }
    }
    _syncMissionStatuses(missions);
  }

  void _syncMissionStatuses(List<DailyMissionModel> missions) {
    final Map<String, String> next = <String, String>{};
    for (final DailyMissionModel mission in missions) {
      final String id = mission.missionId.isNotEmpty
          ? mission.missionId
          : mission.templateId ?? mission.title;
      if (id.isNotEmpty) {
        next[id] = mission.status;
      }
    }
    _previousMissionStatus = next;
  }

  Future<void> _dismissLevelUp() async {
    if (_levelUpDismissInFlight) {
      return;
    }
    _levelUpDismissInFlight = true;
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await ProgressionService.instance.dismissLevelUpModal(user.uid);
    }
    if (mounted) {
      setState(() => _levelUpCelebration = null);
    }
    _levelUpDismissInFlight = false;
  }
}

class _LevelUpCelebrationModal extends StatelessWidget {
  const _LevelUpCelebrationModal({
    required this.celebration,
    required this.onClose,
  });

  final GamificationCelebrationState celebration;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final String rank =
        GamificationConstants.rankTitleForLevel(celebration.level);
    return Material(
      key: const Key('gamification-level-up-modal'),
      color: Colors.black.withValues(alpha: 0.62),
      child: Center(
        child: Container(
          width: MediaQuery.sizeOf(context).width.clamp(0, 380).toDouble(),
          margin: const EdgeInsets.all(18),
          padding: const EdgeInsets.all(22),
          decoration: OnboardingStyle.cardDecoration(context: context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFFFBBF24),
                size: 56,
              ),
              const SizedBox(height: 12),
              Text(
                'Level ${celebration.level}!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: OnboardingStyle.textPrimaryFor(context),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You reached $rank. Keep your streak and missions going.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: OnboardingStyle.textSecondaryFor(context),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              GradientPillButton(
                label: 'Keep Leveling Up',
                icon: Icons.bolt_rounded,
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionCelebrationModal extends StatelessWidget {
  const _MissionCelebrationModal({
    required this.mission,
    required this.onClose,
  });

  final DailyMissionModel mission;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('gamification-mission-complete-modal'),
      color: Colors.black.withValues(alpha: 0.62),
      child: Center(
        child: Container(
          width: MediaQuery.sizeOf(context).width.clamp(0, 380).toDouble(),
          margin: const EdgeInsets.all(18),
          padding: const EdgeInsets.all(22),
          decoration: OnboardingStyle.cardDecoration(context: context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFFFBBF24),
                size: 56,
              ),
              const SizedBox(height: 12),
              Text(
                'Mission Complete',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: OnboardingStyle.textPrimaryFor(context),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${mission.title} — +${mission.rewardXp} XP',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: OnboardingStyle.textSecondaryFor(context),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              GradientPillButton(
                label: 'Nice',
                icon: Icons.check_rounded,
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
