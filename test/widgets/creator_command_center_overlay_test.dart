import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:streamers_tip/features/gamification/models/subscription_plan.dart';
import 'package:streamers_tip/models/creator_command_snapshot.dart';
import 'package:streamers_tip/providers/creator_command_provider.dart';
import 'package:streamers_tip/widgets/creator_command_center_overlay.dart';

void main() {
  final CreatorCommandSnapshot snapshot = CreatorCommandSnapshot(
    userId: 'user-1',
    username: 'technqs',
    displayName: 'TechnQs',
    level: 7,
    streakDays: 5,
    subscriptionPlan: SubscriptionPlan.pro,
    tippyAiEnabled: true,
    draftCount: 3,
    consistencyScorePercent: 82,
    alertCount: 2,
    requiresAttentionCount: 2,
    pendingWorkCount: 3,
    scheduledQueueCount: 2,
    growthPercent: 12,
    nextPostDueAt: DateTime(2026, 4, 23, 18),
  );

  Future<void> pumpOverlay(
    WidgetTester tester, {
    required CreatorCommandCenterState state,
    VoidCallback? onDismiss,
    VoidCallback? onExpand,
  }) async {
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
          home: Scaffold(
            body: Stack(
              children: <Widget>[
                CreatorCommandCenterOverlay(
                  state: state,
                  onDismiss: onDismiss ?? () {},
                  onExpand: onExpand ?? () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders expanded panel with live values', (WidgetTester tester) async {
    await pumpOverlay(tester, state: CreatorCommandCenterState.expanded);

    expect(find.text('TechnQs • Level 7'), findsOneWidget);
    expect(find.text('Tippy'), findsOneWidget);
    expect(find.text('Consistency 82%'), findsOneWidget);
    expect(find.text('Due alerts'), findsOneWidget);
    expect(find.text('2 scheduled'), findsOneWidget);
  });

  testWidgets('tapping outside expanded panel dismisses it', (WidgetTester tester) async {
    int dismissCount = 0;
    await pumpOverlay(
      tester,
      state: CreatorCommandCenterState.expanded,
      onDismiss: () => dismissCount++,
    );

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(dismissCount, 1);
  });

  testWidgets('collapsed bar re-expands on tap', (WidgetTester tester) async {
    int expandCount = 0;
    await pumpOverlay(
      tester,
      state: CreatorCommandCenterState.collapsed,
      onExpand: () => expandCount++,
    );

    expect(find.textContaining('TechnQs'), findsOneWidget);
    await tester.tap(find.textContaining('TechnQs'));
    await tester.pumpAndSettle();

    expect(expandCount, 1);
  });
}
