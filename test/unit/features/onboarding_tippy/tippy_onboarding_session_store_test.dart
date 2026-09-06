import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:streamers_tip/features/onboarding_tippy/tippy_onboarding_contract.dart';
import 'package:streamers_tip/features/onboarding_tippy/tippy_onboarding_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await TippyOnboardingSessionStore().clear();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(kTippyForceFreshAfterAccountDeletionKey);
    await prefs.remove(kTippyStartedFromWelcomeAfterDeletionKey);
    await prefs.remove(kTippySignupClosedFloorKey);
    await prefs.remove(kTippyReservedSignupUsernameKey);
    await prefs.remove(kTippyVerifyFloorReleasedKey);
  });

  test('recovers DNA answers from SharedPreferences after a cache miss',
      () async {
    final TippyOnboardingGuestSession input =
        TippyOnboardingGuestSession.empty().copyWith(
      stage: TippyOnboardingStages.bio,
      answers: <String, dynamic>{
        'creator_type': 'streamer',
        'niche': <String>['gaming'],
        'goals': <String>['build_audience'],
      },
    );
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kTippyOnboardingSessionStorageKey,
      jsonEncode(input.toJson()),
    );
    final TippyOnboardingGuestSession? actualX =
        await TippyOnboardingSessionStore().load();
    expect(actualX, isNotNull);
    expect(actualX!.answers['creator_type'], 'streamer');
    expect(actualX.answers['niche'], <String>['gaming']);
    expect(actualX.stage, TippyOnboardingStages.bio);
  });

  test('invalidateAfterAccountDeletion forces a fresh Meet Tippy session',
      () async {
    final TippyOnboardingGuestSession input =
        TippyOnboardingGuestSession.empty().copyWith(
      stage: TippyOnboardingStages.bio,
      answers: <String, dynamic>{'creator_type': 'streamer'},
      hasSeenTippyIntro: true,
    );
    await TippyOnboardingSessionStore().save(input);
    await TippyOnboardingSessionStore().invalidateAfterAccountDeletion();
    final TippyOnboardingGuestSession? actualX =
        await TippyOnboardingSessionStore().load();
    expect(actualX, isNull);
    final TippyOnboardingGuestSession created =
        await TippyOnboardingSessionStore().loadOrCreate();
    expect(created.stage, TippyOnboardingStages.welcome);
    expect(created.answers, isEmpty);
    expect(created.hasSeenTippyIntro, isFalse);
  });

  test('peekStartedFromWelcome does not clear the sticky flag', () async {
    final TippyOnboardingSessionStore store = TippyOnboardingSessionStore();
    await store.markStartedFromWelcome();
    expect(await store.peekStartedFromWelcome(), isTrue);
    expect(await store.consumeStartedFromWelcomeAfterDeletion(), isTrue);
    expect(await store.peekStartedFromWelcome(), isTrue);
    await store.clearStartedFromWelcomeAfterDeletion();
    expect(await store.peekStartedFromWelcome(), isFalse);
  });

  test('lockSignupAtVerifyEmail floors a live session to verify_email',
      () async {
    final TippyOnboardingSessionStore store = TippyOnboardingSessionStore();
    final TippyOnboardingGuestSession input =
        TippyOnboardingGuestSession.empty().copyWith(
      stage: TippyOnboardingStages.signup,
      answers: <String, dynamic>{'creator_type': 'streamer'},
      hasSeenTippyIntro: true,
    );
    await store.save(input);
    await store.lockSignupAtVerifyEmail(uid: 'uid-verify');
    expect(await store.peekSignupClosedFloor(), TippyOnboardingStages.verifyEmail);
    final TippyOnboardingGuestSession? actualX = await store.load();
    expect(actualX, isNotNull);
    expect(actualX!.stage, TippyOnboardingStages.verifyEmail);
    expect(actualX.answers['creator_type'], 'streamer');
  });

  test('lockSignupAtVerifyEmail stores the typed signup username', () async {
    final TippyOnboardingSessionStore store = TippyOnboardingSessionStore();
    final TippyOnboardingGuestSession input =
        TippyOnboardingGuestSession.empty().copyWith(
      stage: TippyOnboardingStages.signup,
      answers: <String, dynamic>{'creator_type': 'streamer'},
      hasSeenTippyIntro: true,
    );
    await store.save(input);
    await store.lockSignupAtVerifyEmail(
      uid: 'uid-verify',
      username: 'Beacon1606',
    );
    expect(await store.peekSignupUsername(), 'beacon1606');
    final TippyOnboardingGuestSession? actualX = await store.load();
    expect(actualX, isNotNull);
    expect(actualX!.profileDraft.username, 'beacon1606');
    expect(actualX.profileDraft.displayName, 'beacon1606');
  });

  test('save does not wipe a reserved signup username', () async {
    final TippyOnboardingSessionStore store = TippyOnboardingSessionStore();
    final TippyOnboardingGuestSession input =
        TippyOnboardingGuestSession.empty().copyWith(
      stage: TippyOnboardingStages.signup,
      hasSeenTippyIntro: true,
    );
    await store.save(input);
    await store.lockSignupAtVerifyEmail(
      uid: 'uid-verify',
      username: 'tester0505',
    );
    final TippyOnboardingGuestSession? locked = await store.load();
    expect(locked, isNotNull);
    await store.save(
      locked!.copyWith(
        stage: TippyOnboardingStages.verifyEmail,
        profileDraft: locked.profileDraft.copyWith(username: ''),
      ),
    );
    expect(await store.peekSignupUsername(), 'tester0505');
    final TippyOnboardingGuestSession? actualX = await store.load();
    expect(actualX, isNotNull);
    expect(actualX!.profileDraft.username, 'tester0505');
  });

  test('reserved signup username survives floor and session clear', () async {
    final TippyOnboardingSessionStore store = TippyOnboardingSessionStore();
    await store.lockSignupAtVerifyEmail(
      uid: 'uid-verify',
      username: 'tester0505',
    );
    await store.clearSignupClosedFloor();
    await store.clear();
    expect(
      await store.peekSignupUsername(uid: 'uid-verify'),
      'tester0505',
    );
    expect(
      await store.peekSignupUsername(uid: 'other-uid'),
      isNull,
    );
  });

  test('peekSignupClosedFloorUid returns the signup uid', () async {
    final TippyOnboardingSessionStore store = TippyOnboardingSessionStore();
    await store.lockSignupAtVerifyEmail(uid: 'uid-verify');
    expect(await store.peekSignupClosedFloorUid(), 'uid-verify');
  });

  test('releasing verify floor lets signup persist without rewind', () async {
    final TippyOnboardingSessionStore store = TippyOnboardingSessionStore();
    final TippyOnboardingGuestSession input =
        TippyOnboardingGuestSession.empty().copyWith(
      stage: TippyOnboardingStages.signup,
      answers: <String, dynamic>{'creator_type': 'streamer'},
      hasSeenTippyIntro: true,
    );
    await store.save(input);
    await store.lockSignupAtVerifyEmail(uid: 'uid-verify');
    await store.persistVerifyFloorReleased();
    expect(await store.peekSignupClosedFloor(), isNull);
    expect(await store.peekVerifyFloorReleased(), isTrue);
    await store.save(
      input.copyWith(stage: TippyOnboardingStages.signup),
    );
    final TippyOnboardingGuestSession? actualX = await store.load();
    expect(actualX, isNotNull);
    expect(actualX!.stage, TippyOnboardingStages.signup);
    expect(actualX.answers['creator_type'], 'streamer');
  });
}
