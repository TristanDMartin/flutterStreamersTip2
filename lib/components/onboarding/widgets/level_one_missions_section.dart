import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/gamification/gamification_providers.dart';
import '../../../features/gamification/models/user_progress_bundle.dart';
import '../onboarding_service.dart';
import 'mission_banner_widget.dart';

/// Level 1 starter missions card for the Progression tab.
class LevelOneMissionsSection extends ConsumerStatefulWidget {
  const LevelOneMissionsSection({
    super.key,
    this.onViewAll,
  });

  final VoidCallback? onViewAll;

  @override
  ConsumerState<LevelOneMissionsSection> createState() =>
      _LevelOneMissionsSectionState();
}

class _LevelOneMissionsSectionState
    extends ConsumerState<LevelOneMissionsSection> {
  final OnboardingService _onboardingService = OnboardingService();
  bool _isVisible = false;
  bool _checkedVisibility = false;
  bool _markedSeen = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadVisibility());
  }

  Future<void> _loadVisibility() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final state = await _onboardingService.fetchOnboarding(user.uid);
    if (!mounted) {
      return;
    }
    setState(() {
      _isVisible = state.completed && !state.missionBannerDismissed;
      _checkedVisibility = true;
    });
    if (_isVisible && !_markedSeen) {
      _markedSeen = true;
      unawaited(_onboardingService.markMissionBannerSeenOnHome(user.uid));
    }
  }

  Future<void> _dismissBanner() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    await _onboardingService.dismissMissionBanner(user.uid);
    if (mounted) {
      setState(() => _isVisible = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checkedVisibility || !_isVisible) {
      return const SizedBox.shrink();
    }
    final AsyncValue<UserProgressBundle> bundleAsync =
        ref.watch(userProgressBundleProvider);
    return bundleAsync.when(
      data: (UserProgressBundle bundle) {
        return MissionBannerWidget(
          missions: bundle.missions,
          showDismiss: true,
          onDismiss: _dismissBanner,
          onViewAll: widget.onViewAll,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
