import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/gamification/gamification_providers.dart';
import 'package:streamers_tip/features/gamification/models/gamification_summary_model.dart';
import 'package:streamers_tip/features/gamification/models/subscription_plan.dart';
import 'package:streamers_tip/features/gamification/models/user_entitlements_model.dart';
import 'package:streamers_tip/features/entitlements/me_entitlements_models.dart';
import 'package:streamers_tip/features/entitlements/me_entitlements_provider.dart';
import 'package:streamers_tip/features/gamification/models/user_progress_bundle.dart';
import 'package:streamers_tip/features/gamification/models/user_subscription_model.dart';
import 'package:streamers_tip/features/tippy/tippy_chat_page.dart';
import 'package:streamers_tip/features/tippy/tippy_chat_service.dart';

class FakeTippyChatService extends TippyChatService {
  FakeTippyChatService({
    this.failWith,
    this.delay = const Duration(milliseconds: 10),
    this.blocker,
  }) : super(
          apiBase: 'https://staging.example.com',
          tokenProvider: _tokenProvider,
        );

  static Future<String?> _tokenProvider() async => 'token_123';

  final TippyChatException? failWith;
  final Duration delay;
  final Completer<void>? blocker;
  int sendCount = 0;
  int planCount = 0;
  List<TippyChatMessage> planMessages = const <TippyChatMessage>[];
  String? planPrompt;

  @override
  Future<TippyCreditsInfo> fetchCreditsInfo() async {
    return const TippyCreditsInfo(
      greeting: 'hello',
      creditsRemaining: 10,
      tier: 'pro',
    );
  }

  @override
  Future<String?> fetchNudge() async => null;

  @override
  Future<TippyChatResult> sendMessage({
    required List<TippyChatMessage> messages,
  }) async {
    sendCount++;
    if (blocker != null) {
      await blocker!.future;
    }
    await Future<void>.delayed(delay);
    if (failWith != null) {
      throw failWith!;
    }
    return const TippyChatResult(
      message: 'assistant reply',
      creditsRemaining: 9,
    );
  }

  @override
  Future<TippyPlanResult> createPlan({
    required List<TippyChatMessage> messages,
    String? prompt,
  }) async {
    planCount++;
    planMessages = messages;
    planPrompt = prompt;
    return const TippyPlanResult(
      planId: 'plan_123',
      itemCount: 3,
      message: 'Created a custom content plan.',
      creditsRemaining: 8,
    );
  }
}

void main() {
  const MeEntitlementsData kMe = MeEntitlementsData(
    uid: 'test-uid',
    email: 't@test.com',
    tier: 'pro',
    tierSource: 'test',
    subscriptionStatus: 'active',
    tippyAi: TippyAiEntitlementPayload(
      enabled: true,
      monthlyCredits: 250,
      remainingCredits: 10,
      usedCredits: 240,
      plan: 'pro',
    ),
  );

  final UserProgressBundle bundle = UserProgressBundle(
    progress: const GamificationSummaryModel(
      level: 1,
      totalXp: 0,
      streakDays: 0,
      creatorScore: 0,
      rankTitle: 'Rookie',
    ),
    subscription: const UserSubscriptionModel(
      plan: SubscriptionPlan.pro,
      status: 'active',
    ),
    entitlements: const UserEntitlementsModel(tippyAi: true),
    missions: const [],
  );

  Widget buildApp(FakeTippyChatService service) {
    return ProviderScope(
      overrides: <Override>[
        userProgressBundleProvider.overrideWith(
          (Ref ref) => Stream<UserProgressBundle>.value(bundle),
        ),
        meEntitlementsProvider.overrideWith(
          (Ref ref) async {
            return kMe;
          },
        ),
      ],
      child: MaterialApp(
        home: TippyChatPage(chatService: service),
      ),
    );
  }

  testWidgets('send button disables while request in progress',
      (WidgetTester tester) async {
    final Completer<void> blocker = Completer<void>();
    final FakeTippyChatService service = FakeTippyChatService(
      blocker: blocker,
    );
    await tester.pumpWidget(buildApp(service));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    final FilledButton button = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(button.onPressed, isNull);
    blocker.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('retry button appears and input preserved on network failure',
      (WidgetTester tester) async {
    final FakeTippyChatService service = FakeTippyChatService(
      failWith: const TippyNetworkException(),
    );
    await tester.pumpWidget(buildApp(service));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'keep me');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Retry last request'), findsOneWidget);
    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'keep me');
  });

  testWidgets('renders success message and avoids duplicate sends',
      (WidgetTester tester) async {
    final FakeTippyChatService service = FakeTippyChatService(
      delay: const Duration(milliseconds: 1),
    );
    service.sendCount = 0;
    await tester.pumpWidget(buildApp(service));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(service.sendCount, 1);
    expect(find.text('assistant reply'), findsOneWidget);
  });

  testWidgets('create plan sends current conversation context',
      (WidgetTester tester) async {
    final FakeTippyChatService service = FakeTippyChatService(
      delay: const Duration(milliseconds: 1),
    );
    await tester.pumpWidget(buildApp(service));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Build a launch week plan for my coffee podcast',
    );
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create + Sync Plan').last);
    await tester.pumpAndSettle();

    expect(service.planCount, 1);
    expect(
      service.planMessages.map((TippyChatMessage message) => message.content),
      contains('Build a launch week plan for my coffee podcast'),
    );
    expect(
      find.textContaining('Created a custom content plan.'),
      findsOneWidget,
    );
    expect(find.text('Open content plan'), findsOneWidget);
  });
}
