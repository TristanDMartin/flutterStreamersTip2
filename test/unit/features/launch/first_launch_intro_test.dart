import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamers_tip/features/launch/first_launch_intro.dart';
import 'package:streamers_tip/features/launch/first_launch_intro_store.dart';

void main() {
  test('first launch plays only when nothing has been seen', () {
    expect(
      decideFirstLaunchIntro(
        alreadySeen: false,
        hasPriorSession: false,
        hasPendingDeepLink: false,
      ).play,
      isTrue,
    );
  });

  test('returning session, seen flag, and deep links skip the intro', () {
    expect(
      decideFirstLaunchIntro(
        alreadySeen: true,
        hasPriorSession: false,
        hasPendingDeepLink: false,
      ).play,
      isFalse,
    );
    expect(
      decideFirstLaunchIntro(
        alreadySeen: false,
        hasPriorSession: true,
        hasPendingDeepLink: false,
      ).play,
      isFalse,
    );
    expect(
      decideFirstLaunchIntro(
        alreadySeen: false,
        hasPriorSession: false,
        hasPendingDeepLink: true,
      ).play,
      isFalse,
    );
  });

  testWidgets('skip ends the sequence once', (WidgetTester tester) async {
    var finishes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: FirstLaunchSequence(
          tippyDuration: const Duration(seconds: 5),
          logoDuration: const Duration(seconds: 5),
          onFinished: () => finishes += 1,
        ),
      ),
    );
    expect(find.byKey(const Key('first_launch_tippy')), findsOneWidget);
    await tester.tap(find.byKey(const Key('first_launch_skip')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('first_launch_skip')));
    await tester.pump();
    expect(finishes, 1);
  });

  testWidgets('reduced motion shows the logo without waiting on Tippy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FirstLaunchSequence(
          reduceMotion: true,
          reducedMotionDuration: const Duration(seconds: 5),
          onFinished: () {},
        ),
      ),
    );
    expect(find.byKey(const Key('first_launch_logo')), findsOneWidget);
    expect(find.byKey(const Key('first_launch_tippy')), findsNothing);
  });

  test('the intro flag is stored and read back', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final SharedPrefsFirstLaunchIntroStore store =
        SharedPrefsFirstLaunchIntroStore(preferences: prefs);
    expect(await store.hasSeen(), isFalse);
    await store.markSeen();
    expect(await store.hasSeen(), isTrue);
  });
}
