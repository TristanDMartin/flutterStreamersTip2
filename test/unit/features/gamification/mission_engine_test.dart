import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/gamification/missions/mission_engine.dart';
import 'package:streamers_tip/features/gamification/models/daily_mission_model.dart';
import 'package:streamers_tip/features/gamification/models/gamification_summary_model.dart';
import 'package:streamers_tip/features/gamification/models/user_entitlements_model.dart';
import 'package:streamers_tip/features/gamification/models/user_progress_bundle.dart';

void main() {
  group('MissionEngine', () {
    const uid = 'user-123';
    final now = DateTime.utc(2026, 4, 3, 12);

    test('returns placeholder sections when no server missions exist', () {
      final sections = MissionEngine.resolveSections(
        UserProgressBundle(
          progress: const GamificationSummaryModel(
            level: 1,
            totalXp: 0,
            streakDays: 0,
            creatorScore: 0,
            rankTitle: 'Rookie',
          ),
          entitlements: const UserEntitlementsModel(),
          missions: const <DailyMissionModel>[],
        ),
        uid,
        now,
      );

      expect(sections, isNotEmpty);
      expect(sections.first.missions, isNotEmpty);
    });

    test('orders active missions before completed missions', () {
      final sections = MissionEngine.resolveSections(
        UserProgressBundle(
          progress: const GamificationSummaryModel(
            level: 2,
            totalXp: 120,
            streakDays: 2,
            creatorScore: 14,
            rankTitle: 'Starter',
          ),
          entitlements: const UserEntitlementsModel(),
          missions: <DailyMissionModel>[
            DailyMissionModel(
              missionId: 'done-1',
              type: 'daily',
              status: 'completed',
              title: 'Completed mission',
              description: '',
              objectiveType: 'count',
              target: 1,
              progress: 1,
              rewardXp: 50,
              startsAt: now,
              expiresAt: now.add(const Duration(days: 1)),
              completedAt: now,
            ),
            DailyMissionModel(
              missionId: 'active-1',
              type: 'daily',
              status: 'active',
              title: 'Active mission',
              description: '',
              objectiveType: 'count',
              target: 10,
              progress: 8,
              rewardXp: 25,
              startsAt: now,
              expiresAt: now.add(const Duration(days: 1)),
            ),
          ],
        ),
        uid,
        now,
      );

      final today = sections.firstWhere((section) => section.title == 'Today');
      expect(today.missions.first.missionId, 'active-1');
      expect(today.missions.last.missionId, 'done-1');
    });
  });
}
