import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:streamers_tip/features/gamification/models/subscription_plan.dart';
import 'package:streamers_tip/models/creator_command_snapshot.dart';
import 'package:streamers_tip/models/creator_command_snapshot.dart'
    as command_model;
import 'package:streamers_tip/routing/app_routes.dart';
import 'package:streamers_tip/providers/creator_command_provider.dart';
import 'package:streamers_tip/widgets/creator_command_center_overlay.dart';

import '../test_support/firebase_test_setup.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTests();
  });

  final CreatorCommandSnapshot unlockedSnapshot = CreatorCommandSnapshot(
    userId: 'user-1',
    username: 'technqs',
    displayName: 'TechnQs',
    level: 7,
    streakDays: 5,
    subscriptionPlan: SubscriptionPlan.pro,
    tippyAiEnabled: true,
    draftCount: 2,
    consistencyScorePercent: 82,
    alertCount: 1,
    requiresAttentionCount: 1,
    pendingWorkCount: 2,
    scheduledQueueCount: 0,
  );

  final CreatorCommandSnapshot lockedSnapshot = CreatorCommandSnapshot(
    userId: 'user-1',
    username: 'technqs',
    displayName: 'TechnQs',
    level: 7,
    streakDays: 5,
    subscriptionPlan: SubscriptionPlan.starter,
    tippyAiEnabled: false,
    draftCount: 0,
    consistencyScorePercent: 82,
    alertCount: 0,
    requiresAttentionCount: 0,
    pendingWorkCount: 0,
    scheduledQueueCount: 0,
  );

  Future<List<RouteSettings>> pumpHarness(
    WidgetTester tester, {
    required CreatorCommandSnapshot snapshot,
  }) async {
    final List<RouteSettings> seenRoutes = <RouteSettings>[];
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          creatorCommandSnapshotProvider.overrideWithValue(
            AsyncValue<CreatorCommandSnapshot?>.data(snapshot),
          ),
        ],
        child: MaterialApp(
          key: UniqueKey(),
          onGenerateRoute: (RouteSettings settings) {
            seenRoutes.add(settings);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Scaffold(body: Text(settings.name ?? 'unknown')),
            );
          },
          home: Scaffold(
            body: Stack(
              children: <Widget>[
                CreatorCommandCenterOverlay(
                  state: command_model.CreatorCommandCenterState.expanded,
                  onDismiss: () {},
                  onExpand: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    seenRoutes.clear();
    return seenRoutes;
  }

  testWidgets('tippy routes to upgrade when locked and chat when unlocked',
      (WidgetTester tester) async {
    List<RouteSettings> seenRoutes = await pumpHarness(
      tester,
      snapshot: lockedSnapshot,
    );

    await tester.tap(find.text('Tippy (locked)'));
    await tester.pumpAndSettle();
    expect(seenRoutes.single.name, AppRoutes.upgrade);

    seenRoutes = await pumpHarness(
      tester,
      snapshot: unlockedSnapshot,
    );
    await tester.tap(find.text('Tippy'));
    await tester.pumpAndSettle();
    expect(seenRoutes.single.name, AppRoutes.tippyChat);
  });
}
