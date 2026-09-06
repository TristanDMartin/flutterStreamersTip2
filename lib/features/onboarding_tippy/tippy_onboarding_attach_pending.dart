import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../components/onboarding/onboarding_service.dart';
import 'tippy_onboarding_attach_service.dart';
import 'tippy_onboarding_contract.dart';
import 'tippy_onboarding_session.dart';

/// If a guest Tippy onboarding session exists after auth, attach once.
/// Skips attach for already-complete accounts so Google sign-in does not
/// restart Tippy / classic onboarding.
Future<void> attachPendingTippyOnboardingIfNeeded() async {
  final User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return;
  }
  final TippyOnboardingSessionStore store = TippyOnboardingSessionStore();
  final TippyOnboardingGuestSession? session = await store.loadActive();
  if (session == null || session.answers.isEmpty) {
    return;
  }
  try {
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final Map<String, dynamic>? data = snap.data();
    if (shouldSkipPendingTippyAttach(
      userData: data,
      sessionStage: session.stage,
    )) {
      await store.clear();
      return;
    }
    if (!TippyOnboardingStages.isPostQuizStage(session.stage) &&
        !session.hasCompletedQuestions) {
      return;
    }
  } catch (error) {
    debugPrint('Tippy attach pre-check skipped: $error');
  }
  // Own the gate before attach so classic creator-focus cannot appear.
  try {
    await OnboardingService().markTippyFunnelInProgress(user.uid);
  } catch (error) {
    debugPrint('Tippy funnel mark deferred: $error');
  }
  final TippyOnboardingAttachService attach = TippyOnboardingAttachService();
  try {
    final bool startedFromWelcome = await store.peekStartedFromWelcome();
    await attach.attach(
      session,
      startedFromWelcome: startedFromWelcome,
    );
  } catch (error) {
    debugPrint('Tippy onboarding attach deferred: $error');
  } finally {
    attach.dispose();
  }
}

/// True when this auth should continue inside Tippy (not classic onboarding).
Future<bool> userNeedsTippyFunnelContinuation(String uid) async {
  try {
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final Map<String, dynamic>? data = snap.data();
    if (data == null) {
      return false;
    }
    final Map<String, dynamic> onboarding =
        (data['onboarding'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    if (onboarding['tippyFunnelCompleted'] == true ||
        onboarding['landingChoice'] != null) {
      return false;
    }
    return onboarding['tippyOnboardingV1Attached'] == true ||
        onboarding['slim7Completed'] == true;
  } catch (_) {
    return false;
  }
}

bool _isTippyCompleteOnThisUid(Map<String, dynamic> onboarding) {
  return onboarding['tippyFunnelCompleted'] == true &&
      (onboarding['essentialProfileComplete'] == true ||
          onboarding['creatorCardCompleted'] == true);
}

Map<String, dynamic> _onboardingMap(Map<String, dynamic>? data) {
  return (data?['onboarding'] as Map?)?.cast<String, dynamic>() ??
      <String, dynamic>{};
}

/// Recycled identities are never "returning complete" until THIS uid
/// finishes Tippy. Username leftover / legacy flags must not skip Meet Tippy.
bool isReturningCompleteTippyUserFromData(Map<String, dynamic>? data) {
  if (data == null) {
    return false;
  }
  final Map<String, dynamic> onboarding = _onboardingMap(data);
  if (data['identityRecycled'] == true) {
    return _isTippyCompleteOnThisUid(onboarding);
  }
  final bool alreadyDone = onboarding['tippyFunnelCompleted'] == true ||
      onboarding['landingChoice'] != null ||
      onboarding['completed'] == true ||
      data['hasCompletedOnboarding'] == true ||
      data['onboardingComplete'] == true;
  if (alreadyDone) {
    return true;
  }
  final String username = (data['username'] as String?)?.trim() ?? '';
  if (username.isEmpty) {
    return false;
  }
  final bool midTippy = onboarding['tippyOnboardingV1Attached'] == true ||
      onboarding['slim7Completed'] == true;
  return !midTippy;
}

bool shouldSkipPendingTippyAttach({
  required Map<String, dynamic>? userData,
  required String sessionStage,
}) {
  if (userData == null) {
    return false;
  }
  final Map<String, dynamic> onboarding = _onboardingMap(userData);
  if (userData['identityRecycled'] == true) {
    return _isTippyCompleteOnThisUid(onboarding);
  }
  final bool alreadyDone = onboarding['tippyFunnelCompleted'] == true ||
      onboarding['landingChoice'] != null ||
      onboarding['completed'] == true ||
      userData['hasCompletedOnboarding'] == true ||
      userData['onboardingComplete'] == true;
  if (alreadyDone) {
    return true;
  }
  final String username = (userData['username'] as String?)?.trim() ?? '';
  final bool existingCreatorIdentity = username.isNotEmpty &&
      (onboarding['creatorCardCompleted'] == true ||
          onboarding['essentialProfileComplete'] == true);
  if (existingCreatorIdentity &&
      !TippyOnboardingStages.isPostQuizStage(sessionStage)) {
    return true;
  }
  final bool midTippy = onboarding['tippyOnboardingV1Attached'] == true ||
      onboarding['slim7Completed'] == true;
  return username.isNotEmpty && !midTippy;
}

/// Existing account chosen via Continue with Google/Apple — do not treat as new.
Future<bool> isReturningCompleteTippyUser(String uid) async {
  try {
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return isReturningCompleteTippyUserFromData(snap.data());
  } catch (_) {
    return false;
  }
}

bool tippySessionNeedsResume(
  TippyOnboardingGuestSession? session, {
  DateTime? now,
}) {
  if (session == null || session.landingChoice != null) {
    return false;
  }
  return TippyOnboardingStages.isPostQuizStage(session.stage) ||
      session.hasMeaningfulProgress;
}
