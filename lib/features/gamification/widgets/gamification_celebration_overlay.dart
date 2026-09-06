import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../components/onboarding/onboarding_style.dart';
import '../../../services/progression_service.dart';
import '../../../providers/current_user_provider.dart';
import '../achievements/achievement_catalog.dart';
import '../achievements/achievement_definition.dart';
import '../achievements/achievement_hex_badge.dart';
import '../achievements/acknowledge_result.dart';
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
  AchievementDefinition? _achievementCelebration;
  final Set<String> _locallyAcknowledged = <String>{};
  Map<String, String> _previousMissionStatus = <String, String>{};
  bool _levelUpDismissInFlight = false;
  bool _achievementAckInFlight = false;
  String? _achievementAckError;
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
    final AchievementSnapshot? achievements =
        ref.read(achievementSnapshotProvider).valueOrNull;
    if (achievements != null) {
      _onAchievementsUpdated(achievements);
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
    ref.listen<AsyncValue<AchievementSnapshot>>(
      achievementSnapshotProvider,
      (AsyncValue<AchievementSnapshot>? _, AsyncValue<AchievementSnapshot> next) {
        next.whenData(_onAchievementsUpdated);
      },
    );
    ref.listen<AsyncValue<String?>>(
      authUserIdStreamProvider,
      (AsyncValue<String?>? previous, AsyncValue<String?> next) {
        final String? prevUid = previous?.valueOrNull;
        final String? nextUid = next.valueOrNull;
        if (prevUid == nextUid) {
          return;
        }
        _locallyAcknowledged.clear();
        _achievementAckInFlight = false;
        if (!mounted) {
          return;
        }
        setState(() {
          _achievementCelebration = null;
          _achievementAckError = null;
        });
      },
    );
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        if (_achievementCelebration != null)
          _AchievementCelebrationModal(
            definition: _achievementCelebration!,
            isBusy: _achievementAckInFlight,
            errorMessage: _achievementAckError,
            onContinue: _acknowledgeCurrentAchievement,
          )
        else if (_levelUpCelebration != null)
          _LevelUpCelebrationModal(
            celebration: _levelUpCelebration!,
            onClose: _dismissLevelUp,
          )
        else if (_missionCelebration != null)
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
    if (celebration.showLevelUpModal &&
        _levelUpCelebration == null &&
        _achievementCelebration == null) {
      setState(() => _levelUpCelebration = celebration);
      unawaited(HapticFeedback.mediumImpact());
    }
    await _detectMissionCompletion(bundle.missions);
  }

  void _onAchievementsUpdated(AchievementSnapshot snapshot) {
    if (!mounted) {
      return;
    }
    _locallyAcknowledged.removeWhere(
      (String key) => !snapshot.pendingKeys.contains(key),
    );
    final List<String> pending = snapshot.pendingKeys
        .where((String key) => !_locallyAcknowledged.contains(key))
        .toList();
    if (pending.isEmpty) {
      if (_achievementCelebration != null) {
        setState(() => _achievementCelebration = null);
      }
      return;
    }
    final AchievementDefinition? next =
        AchievementCatalog.definitionFor(pending.first);
    if (next == null || next.key == _achievementCelebration?.key) {
      return;
    }
    setState(() => _achievementCelebration = next);
    unawaited(
      next.rarity == AchievementRarity.common
          ? HapticFeedback.lightImpact()
          : HapticFeedback.mediumImpact(),
    );
  }

  Future<void> _acknowledgeCurrentAchievement() async {
    final AchievementDefinition? current = _achievementCelebration;
    if (current == null || _achievementAckInFlight) {
      return;
    }
    setState(() {
      _achievementAckInFlight = true;
      _achievementAckError = null;
    });
    final AchievementAcknowledgeResult result =
        await ref.read(achievementRepositoryProvider).acknowledge(current.key);
    if (!mounted) {
      return;
    }
    if (result is AchievementAcknowledgeSuccess) {
      _locallyAcknowledged.add(current.key);
      setState(() {
        _achievementAckInFlight = false;
        _achievementAckError = null;
        _achievementCelebration = null;
      });
      final AchievementSnapshot? snapshot =
          ref.read(achievementSnapshotProvider).valueOrNull;
      if (snapshot != null) {
        _onAchievementsUpdated(snapshot);
      }
      return;
    }
    final AchievementAcknowledgeFailure failure =
        result as AchievementAcknowledgeFailure;
    setState(() {
      _achievementAckInFlight = false;
      _achievementAckError = failure.userMessage;
    });
  }

  Future<void> _detectMissionCompletion(
      List<DailyMissionModel> missions) async {
    if (_achievementCelebration != null ||
        _levelUpCelebration != null ||
        _missionCelebration != null) {
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

class _AchievementCelebrationModal extends StatelessWidget {
  const _AchievementCelebrationModal({
    required this.definition,
    required this.onContinue,
    required this.isBusy,
    this.errorMessage,
  });

  final AchievementDefinition definition;
  final VoidCallback onContinue;
  final bool isBusy;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey<String>('gamification-achievement-${definition.key}'),
      color: Colors.black.withValues(alpha: 0.54),
      child: Center(
        child: Container(
          width: MediaQuery.sizeOf(context).width.clamp(0, 380).toDouble(),
          margin: const EdgeInsets.all(18),
          padding: const EdgeInsets.all(22),
          decoration: OnboardingStyle.cardDecoration(context: context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Achievement Unlocked',
                style: OnboardingStyle.tipLabelFor(context),
              ),
              const SizedBox(height: 16),
              AchievementHexBadge(
                definition: definition,
                unlocked: true,
                size: 112,
                animated: true,
              ),
              const SizedBox(height: 16),
              Text(
                definition.title,
                textAlign: TextAlign.center,
                style: OnboardingStyle.titleFor(context, fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(
                definition.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: OnboardingStyle.textSecondaryFor(context),
                  height: 1.35,
                ),
              ),
              if (definition.xpReward > 0) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  '+${definition.xpReward} XP',
                  style: TextStyle(
                    color: OnboardingStyle.textPrimaryFor(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              if (errorMessage != null && errorMessage!.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              GradientPillButton(
                label: isBusy ? 'Continuing…' : 'Continue',
                icon: Icons.check_rounded,
                onPressed: isBusy ? null : onContinue,
              ),
            ],
          ),
        ),
      ),
    );
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
