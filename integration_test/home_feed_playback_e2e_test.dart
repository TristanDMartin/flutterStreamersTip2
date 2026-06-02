import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:streamers_tip/constants/playback_owners.dart';
import 'package:streamers_tip/main.dart' as app;
import 'package:streamers_tip/qa/qa_keys.dart';
import 'package:streamers_tip/services/global_playback_manager.dart';

const bool _runMobileFeedE2e = bool.fromEnvironment('RUN_MOBILE_FEED_E2E');
const String _qaEmailOrUsername =
    String.fromEnvironment('QA_EMAIL_OR_USERNAME');
const String _qaPassword = String.fromEnvironment('QA_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'home feed cold start, swipes, overlay, tab away, and resume',
    (WidgetTester tester) async {
      app.main();
      await _signInAndOpenHomeFeedIfNeeded(tester);
      await _pumpFor(tester, const Duration(seconds: 3));

      final GlobalPlaybackManager playback = GlobalPlaybackManager.instance;
      await _waitUntilPlaybackReady(
        tester,
        playback,
        timeout: const Duration(seconds: 90),
      );

      expect(playback.activeOwner, PlaybackOwners.home);
      expect(_isHomeColdStartPlaybackReady(playback), isTrue);
      expect(playback.activeVideoId, isNotNull);
      expect(playback.isPlaybackBlocked, isFalse);

      for (var i = 0; i < 10; i++) {
        await tester.fling(
          find.byKey(QaKeys.homeFeedPageView),
          const Offset(0, -700),
          1200,
        );
        await _pumpFor(tester, const Duration(milliseconds: 900));
      }

      await _scrollHomeFeedTowardTop(tester);
      await _openCommandCenterOrFeedDropdown(tester);
      expect(GlobalPlaybackManager.instance.isPlaybackBlocked, isTrue);

      if (find.byKey(QaKeys.commandCenterOverlay).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(QaKeys.commandCenterDismiss).first);
      } else {
        await tester.tap(find.byKey(QaKeys.feedSelectorBarrier));
      }

      await _pumpFor(tester, const Duration(seconds: 2));
      expect(find.byKey(QaKeys.homeFeedPageView), findsOneWidget);
      expect(GlobalPlaybackManager.instance.isPlaybackBlocked, isFalse);

      await tester.tap(
        find.byKey(QaKeys.bottomNavNetwork),
        warnIfMissed: false,
      );
      await _pumpFor(tester, const Duration(seconds: 2));
      expect(
        GlobalPlaybackManager.instance.activeOwner,
        PlaybackOwners.network,
      );

      await tester.tap(find.byKey(QaKeys.bottomNavHome), warnIfMissed: false);
      await _waitFor(
        tester,
        find.byKey(QaKeys.homeFeedPageView),
        timeout: const Duration(seconds: 20),
      );
      await _pumpFor(tester, const Duration(seconds: 2));
      expect(find.byKey(QaKeys.homeFeedPageView), findsOneWidget);
      expect(GlobalPlaybackManager.instance.isPlaybackBlocked, isFalse);
      expect(GlobalPlaybackManager.instance.activeOwner, PlaybackOwners.home);
    },
    timeout: const Timeout(Duration(minutes: 8)),
    skip: !_runMobileFeedE2e,
  );
}

Future<void> _signInAndOpenHomeFeedIfNeeded(WidgetTester tester) async {
  await _waitForAny(
    tester,
    <Finder>[
      find.byKey(QaKeys.homeFeedPageView),
      find.byKey(QaKeys.homeFeedSurface),
      find.byKey(QaKeys.authEmailUsernameOption),
      find.text('Sign in with Email/Username'),
      find.byKey(QaKeys.authLoginEmailOrUsername),
    ],
    timeout: const Duration(seconds: 120),
  );

  if (_hasAuthMethodChooser(tester)) {
    await _openEmailUsernameLogin(tester);
    await _waitFor(
      tester,
      find.byKey(QaKeys.authLoginEmailOrUsername),
      timeout: const Duration(seconds: 20),
    );
  }

  if (find.byKey(QaKeys.authLoginEmailOrUsername).evaluate().isNotEmpty) {
    if (_qaEmailOrUsername.isEmpty || _qaPassword.isEmpty) {
      fail(
        'QA credentials are required when the app starts signed out. '
        'Pass --dart-define=QA_EMAIL_OR_USERNAME=... and '
        '--dart-define=QA_PASSWORD=...',
      );
    }
    await tester.ensureVisible(find.byKey(QaKeys.authLoginEmailOrUsername));
    await tester.enterText(
      find.byKey(QaKeys.authLoginEmailOrUsername),
      _qaEmailOrUsername,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byKey(QaKeys.authLoginPassword));
    await tester.enterText(find.byKey(QaKeys.authLoginPassword), _qaPassword);
    await _pumpFor(tester, const Duration(seconds: 1));
    await tester.ensureVisible(find.byKey(QaKeys.authLoginSubmit));
    await tester.tap(find.byKey(QaKeys.authLoginSubmit));
    await _pumpFor(tester, const Duration(seconds: 5));
  }

  await _waitForHomeFeedReady(tester);
  expect(find.byKey(QaKeys.homeFeedPageView), findsOneWidget);
  await _pumpFor(tester, const Duration(seconds: 4));
}

Future<void> _waitForHomeFeedReady(WidgetTester tester) async {
  final DateTime end = DateTime.now().add(const Duration(seconds: 120));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.byKey(QaKeys.homeFeedPageView).evaluate().isNotEmpty) {
      return;
    }
    final GlobalPlaybackManager playback = GlobalPlaybackManager.instance;
    if (playback.activeOwner == PlaybackOwners.home &&
        playback.activeVideoId != null &&
        find.byKey(QaKeys.homeFeedSurface).evaluate().isNotEmpty) {
      await _pumpFor(tester, const Duration(seconds: 2));
      if (find.byKey(QaKeys.homeFeedPageView).evaluate().isNotEmpty) {
        return;
      }
    }
  }
  fail(
    'Timed out waiting for home feed '
    '(surface=${find.byKey(QaKeys.homeFeedSurface).evaluate().length}, '
    'pageView=${find.byKey(QaKeys.homeFeedPageView).evaluate().length}, '
    'activeVideoId=${GlobalPlaybackManager.instance.activeVideoId})',
  );
}

Future<void> _waitUntilPlaybackReady(
  WidgetTester tester,
  GlobalPlaybackManager playback, {
  required Duration timeout,
}) async {
  final DateTime end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (_isHomeColdStartPlaybackReady(playback)) {
      return;
    }
  }
  fail(
    'Timed out waiting for cold-start playback '
    '(activeVideoId=${playback.activeVideoId}, '
    'currentFeedIndex=${playback.currentFeedIndex}, '
    'activeOwner=${playback.activeOwner})',
  );
}

bool _hasAuthMethodChooser(WidgetTester tester) {
  return find.byKey(QaKeys.authEmailUsernameOption).evaluate().isNotEmpty ||
      find.text('Sign in with Email/Username').evaluate().isNotEmpty;
}

Future<void> _openEmailUsernameLogin(WidgetTester tester) async {
  final Finder label = find.text('Sign in with Email/Username');
  if (label.evaluate().isEmpty) {
    fail('Email/username sign-in option not found on auth screen');
  }
  final Finder target = label.first;
  await _scrollIntoViewIfNeeded(tester, target);
  await tester.tap(target);
  await _pumpFor(tester, const Duration(seconds: 3));
}

Future<void> _scrollIntoViewIfNeeded(WidgetTester tester, Finder finder) async {
  try {
    await tester.scrollUntilVisible(
      finder,
      80,
      scrollable: find.byType(Scrollable).first,
    );
  } catch (_) {
    await tester.ensureVisible(finder);
  }
}

Future<void> _scrollHomeFeedTowardTop(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.fling(
      find.byKey(QaKeys.homeFeedPageView),
      const Offset(0, 700),
      1200,
    );
    await _pumpFor(tester, const Duration(milliseconds: 350));
  }
  await _pumpFor(tester, const Duration(seconds: 1));
}

Future<void> _openCommandCenterOrFeedDropdown(WidgetTester tester) async {
  await _pumpFor(tester, const Duration(seconds: 1));

  final Finder triggers = find.byKey(QaKeys.commandCenterTrigger);
  if (triggers.evaluate().isNotEmpty) {
    final Finder target =
        triggers.evaluate().length == 1 ? triggers : triggers.last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await _pumpFor(tester, const Duration(milliseconds: 500));
    if (await _tryWaitFor(
      tester,
      find.byKey(QaKeys.commandCenterOverlay),
      timeout: const Duration(seconds: 8),
    )) {
      return;
    }
  }

  await tester.ensureVisible(find.byKey(QaKeys.feedSelectorButton));
  await tester.tap(find.byKey(QaKeys.feedSelectorButton));
  await _waitFor(
    tester,
    find.byKey(QaKeys.feedSelectorOverlay),
    timeout: const Duration(seconds: 15),
  );
}

Future<bool> _tryWaitFor(
  WidgetTester tester,
  Finder finder, {
  required Duration timeout,
}) async {
  final DateTime end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) {
      return true;
    }
  }
  return false;
}

Future<void> _pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  required Duration timeout,
}) async {
  final DateTime end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

Future<void> _waitForAny(
  WidgetTester tester,
  List<Finder> finders, {
  required Duration timeout,
}) async {
  final DateTime end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finders.any((finder) => finder.evaluate().isNotEmpty)) return;
  }
  fail('Timed out waiting for any of: ${finders.join(', ')}');
}

bool _isHomeColdStartPlaybackReady(GlobalPlaybackManager playback) {
  if (playback.activeOwner != PlaybackOwners.home) {
    return false;
  }
  if (playback.activeVideoId == null || playback.isPlaybackBlocked) {
    return false;
  }
  final int? index = playback.currentFeedIndex;
  return index == null || index == 0;
}
