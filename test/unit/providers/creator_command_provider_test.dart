import 'package:flutter_test/flutter_test.dart';

import 'package:streamers_tip/features/content_planning/content_planning_models.dart';
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
              'scheduledAtUtc':
                  DateTime.now().subtract(const Duration(hours: 1)),
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
      expect(snapshot.alertCount, 1);
      expect(snapshot.scheduledQueueCount, 1);
      expect(snapshot.nextPostOverdue, isTrue);
      expect(snapshot.growthPercent, 12);
    });

    test('falls back to recent videos for consistency and omits missing growth',
        () {
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
          <String, dynamic>{
            'createdAt': now.subtract(const Duration(days: 11))
          },
          <String, dynamic>{
            'createdAt': now.subtract(const Duration(days: 18))
          },
        ],
      );

      expect(snapshot.growthPercent, isNull);
      expect(snapshot.alertCount, 0);
      expect(snapshot.consistencyScorePercent, greaterThan(0));
      expect(snapshot.collapsedSummary, contains('solo'));
    });

    test('merges Tippy content-plan item schedules into next due and queue', () {
      final DateTime soon = DateTime.now().add(const Duration(hours: 5));
      final DateTime later = DateTime.now().add(const Duration(days: 2));
      final snapshot = buildCreatorCommandSnapshot(
        userData: <String, dynamic>{
          'id': 'user-1',
          'username': 'technqs',
          'displayName': 'TechnQs',
        },
        bundle: UserProgressBundle.fallback(),
        scheduledPosts: const <Map<String, dynamic>>[],
        contentPlans: <ContentPlan>[
          ContentPlan(
            id: 'plan-1',
            title: 'Launch week',
            itemCount: 2,
            userId: 'user-1',
            status: 'draft',
            source: 'tippy',
            items: <ContentPlanItem>[
              ContentPlanItem(
                id: 'item-1',
                title: 'Hook clip A',
                status: 'scheduled',
                platforms: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'platform': 'tiktok',
                    'scheduledAt': soon,
                    'status': 'scheduled',
                  },
                ],
              ),
              ContentPlanItem(
                id: 'item-2',
                title: 'Stream recap',
                status: 'scheduled',
                platforms: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'platform': 'youtube',
                    'scheduledAt': later,
                    'status': 'scheduled',
                  },
                ],
              ),
            ],
          ),
        ],
        draftCount: 0,
        metrics: null,
        recentVideos: const <Map<String, dynamic>>[],
      );

      expect(snapshot.scheduledQueueCount, 2);
      expect(snapshot.nextPostOverdue, isFalse);
      expect(snapshot.nextPostTitle, 'Hook clip A');
      expect(snapshot.nextPostPlanTitle, 'Launch week');
      expect(snapshot.nextPostDueAt, isNotNull);
      expect(
        snapshot.nextPostDueAt!.difference(soon).inSeconds.abs(),
        lessThan(2),
      );
    });

    test('counts overdue content-plan items as due alerts', () {
      final DateTime overdue = DateTime.now().subtract(const Duration(hours: 3));
      final snapshot = buildCreatorCommandSnapshot(
        userData: <String, dynamic>{
          'id': 'user-1',
          'username': 'technqs',
          'displayName': 'TechnQs',
        },
        bundle: UserProgressBundle.fallback(),
        scheduledPosts: const <Map<String, dynamic>>[],
        contentPlans: <ContentPlan>[
          ContentPlan(
            id: 'plan-2',
            title: 'Recovery plan',
            itemCount: 1,
            userId: 'user-1',
            status: 'draft',
            items: <ContentPlanItem>[
              ContentPlanItem(
                id: 'item-overdue',
                title: 'Missed Short',
                status: 'scheduled',
                platforms: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'platform': 'instagram',
                    'scheduledAt': overdue,
                  },
                ],
              ),
            ],
          ),
        ],
        draftCount: 0,
        metrics: null,
        recentVideos: const <Map<String, dynamic>>[],
      );

      expect(snapshot.scheduledQueueCount, 1);
      expect(snapshot.nextPostOverdue, isTrue);
      expect(snapshot.alertCount, 1);
      expect(snapshot.nextPostTitle, 'Missed Short');
    });

    test('enables Tippy for active Studio without entitlement flag', () {
      final snapshot = buildCreatorCommandSnapshot(
        userData: <String, dynamic>{
          'id': 'user-3',
          'username': 'studio_user',
          'displayName': 'Studio User',
        },
        bundle: UserProgressBundle(
          progress: const GamificationSummaryModel(
            level: 10,
            totalXp: 5000,
            streakDays: 3,
            creatorScore: 90,
            rankTitle: 'Pro',
          ),
          subscription: const UserSubscriptionModel(
            plan: SubscriptionPlan.studio,
            status: 'active',
          ),
          entitlements: const UserEntitlementsModel(tippyAi: false),
          missions: const [],
        ),
        scheduledPosts: const <Map<String, dynamic>>[],
        draftCount: 0,
        metrics: null,
        recentVideos: const <Map<String, dynamic>>[],
      );
      expect(snapshot.tippyAiEnabled, isTrue);
    });
  });
}
