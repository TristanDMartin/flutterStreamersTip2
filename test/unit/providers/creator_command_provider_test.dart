import 'package:flutter_test/flutter_test.dart';

import 'package:streamers_tip/features/gamification/models/gamification_summary_model.dart';
import 'package:streamers_tip/features/gamification/models/subscription_plan.dart';
import 'package:streamers_tip/features/gamification/models/user_entitlements_model.dart';
import 'package:streamers_tip/features/gamification/models/user_progress_bundle.dart';
import 'package:streamers_tip/features/gamification/models/user_subscription_model.dart';
import 'package:streamers_tip/providers/creator_command_provider.dart';

void main() {
  group('buildCreatorCommandSnapshot', () {
    test('composes identity, progress, due work, alerts, and consistency', () {
      final snapshot = buildCreatorCommandSnapshot(
        userData: <String, dynamic>{
          'id': 'user-1',
          'username': 'technqs',
          'displayName': 'TechnQs',
        },
        bundle: UserProgressBundle(
          progress: const GamificationSummaryModel(
            level: 7,
            totalXp: 1200,
            streakDays: 5,
            creatorScore: 82,
            rankTitle: 'Builder',
          ),
          subscription: const UserSubscriptionModel(
            plan: SubscriptionPlan.pro,
            status: 'active',
          ),
          entitlements: const UserEntitlementsModel(tippyAi: true),
          missions: const [],
        ),
        scheduledPosts: <Map<String, dynamic>>[
          <String, dynamic>{
            'authorId': 'user-1',
            'status': 'scheduled',
            'schedule': <String, dynamic>{
              'scheduledAtUtc': DateTime.now().subtract(const Duration(hours: 1)),
            },
          },
          <String, dynamic>{
            'authorId': 'user-1',
            'status': 'published',
            'metadata': <String, dynamic>{'requiresCreatorAttention': true},
          },
        ],
        draftCount: 3,
        metrics: <String, dynamic>{
          'uploadConsistency': 0.82,
          'growthVelocity': 0.12,
        },
        recentVideos: const <Map<String, dynamic>>[],
      );

      expect(snapshot.username, 'technqs');
      expect(snapshot.displayName, 'TechnQs');
      expect(snapshot.level, 7);
      expect(snapshot.streakDays, 5);
      expect(snapshot.tippyAiEnabled, isTrue);
      expect(snapshot.draftCount, 3);
      expect(snapshot.consistencyScorePercent, 82);
      expect(snapshot.alertCount, 2);
      expect(snapshot.nextPostOverdue, isTrue);
      expect(snapshot.growthPercent, 12);
    });

    test('falls back to recent videos for consistency and omits missing growth', () {
      final DateTime now = DateTime.now();
      final snapshot = buildCreatorCommandSnapshot(
        userData: <String, dynamic>{
          'id': 'user-2',
          'username': 'solo',
          'displayName': '',
        },
        bundle: UserProgressBundle.fallback(),
        scheduledPosts: const <Map<String, dynamic>>[],
        draftCount: 0,
        metrics: null,
        recentVideos: <Map<String, dynamic>>[
          <String, dynamic>{'createdAt': now.subtract(const Duration(days: 3))},
          <String, dynamic>{'createdAt': now.subtract(const Duration(days: 11))},
          <String, dynamic>{'createdAt': now.subtract(const Duration(days: 18))},
        ],
      );

      expect(snapshot.growthPercent, isNull);
      expect(snapshot.alertCount, 0);
      expect(snapshot.consistencyScorePercent, greaterThan(0));
      expect(snapshot.collapsedSummary, contains('solo'));
    });
  });
}
