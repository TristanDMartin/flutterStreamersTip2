import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/gamification/models/gamification_summary_model.dart';
import 'package:streamers_tip/features/gamification/models/subscription_plan.dart';
import 'package:streamers_tip/features/gamification/models/user_entitlements_model.dart';
import 'package:streamers_tip/features/gamification/models/user_progress_bundle.dart';
import 'package:streamers_tip/features/gamification/models/user_subscription_model.dart';
import 'package:streamers_tip/features/billing/models/subscription_snapshot.dart';
import 'package:streamers_tip/features/tippy/tippy_access.dart';

void main() {
  group('resolveTippyEnabled', () {
    test('true when entitlement flag set', () {
      final UserProgressBundle bundle = UserProgressBundle(
        progress: const GamificationSummaryModel(
          level: 1,
          totalXp: 0,
          streakDays: 0,
          creatorScore: 0,
          rankTitle: 'Rookie',
        ),
        subscription: const UserSubscriptionModel(
          plan: SubscriptionPlan.starter,
          status: 'active',
        ),
        entitlements: const UserEntitlementsModel(tippyAi: true),
        missions: const [],
      );
      expect(resolveTippyEnabled(bundle), isTrue);
    });

    test('true for Pro active without entitlement flag', () {
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
        entitlements: const UserEntitlementsModel(tippyAi: false),
        missions: const [],
      );
      expect(resolveTippyEnabled(bundle), isTrue);
    });

    test('true for Studio active without entitlement flag', () {
      final UserProgressBundle bundle = UserProgressBundle(
        progress: const GamificationSummaryModel(
          level: 1,
          totalXp: 0,
          streakDays: 0,
          creatorScore: 0,
          rankTitle: 'Rookie',
        ),
        subscription: const UserSubscriptionModel(
          plan: SubscriptionPlan.studio,
          status: 'active',
        ),
        entitlements: const UserEntitlementsModel(tippyAi: false),
        missions: const [],
      );
      expect(resolveTippyEnabled(bundle), isTrue);
    });

    test('true for Starter active without entitlement flag', () {
      final UserProgressBundle bundle = UserProgressBundle(
        progress: const GamificationSummaryModel(
          level: 1,
          totalXp: 0,
          streakDays: 0,
          creatorScore: 0,
          rankTitle: 'Rookie',
        ),
        subscription: const UserSubscriptionModel(
          plan: SubscriptionPlan.starter,
          status: 'active',
        ),
        entitlements: const UserEntitlementsModel(tippyAi: false),
        missions: const [],
      );
      expect(resolveTippyEnabled(bundle), isTrue);
    });

    test('true when paid subscription inactive (starter Tippy access)', () {
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
          status: 'canceled',
        ),
        entitlements: const UserEntitlementsModel(tippyAi: false),
        missions: const [],
      );
      expect(resolveTippyEnabled(bundle), isTrue);
    });
  });

  group('resolveTippyEnabledFromSnapshot', () {
    test('true for starter when canUseTippy is set', () {
      final SubscriptionSnapshot snapshot = SubscriptionSnapshot.fromResponseJson(
        <String, dynamic>{
          'tier': 'starter',
          'tippyAi': <String, dynamic>{'enabled': true, 'monthlyCredits': 25},
          'limits': <String, dynamic>{
            'contentPlans': 1,
            'aiCreditsPerMonth': 25,
          },
          'features': <String, dynamic>{'tippyPremium': false},
        },
      );
      expect(resolveTippyEnabledFromSnapshot(snapshot), isTrue);
      expect(snapshot.tippyAi.enabled, isTrue);
    });
  });
}
