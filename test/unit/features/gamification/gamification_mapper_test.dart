import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/gamification/gamification_mapper.dart';

void main() {
  group('GamificationMapper', () {
    test('parses fallback-friendly user doc values', () {
      final bundle = GamificationMapper.userDocToBundle(
        <String, dynamic>{
          'gamification': <String, dynamic>{
            'creatorLevel': '4',
            'total_xp': 320,
            'streak_days': 6,
            // Stale legacy map score must not win over Worker state.
            'creator_score': '90',
            'rank_title': 'Momentum Builder',
            'next_action': 'Post one more clip today',
          },
          'entitlements': <String, dynamic>{
            'tippyAi': true,
            'advancedAnalytics': true,
          },
          'usage': <String, dynamic>{
            'aiCreditsUsed': 2,
            'aiCreditsLimit': 10,
          },
        },
        gamificationState: <String, dynamic>{
          'creatorScore': 87.5,
          'totalXp': 320,
          'level': 4,
        },
      );

      expect(bundle.progress.level, 4);
      expect(bundle.progress.totalXp, 320);
      expect(bundle.progress.streakDays, 6);
      expect(bundle.progress.creatorScore, 87.5);
      expect(bundle.progress.rankTitle, 'Momentum Builder');
      expect(bundle.progress.nextActionHint, 'Post one more clip today');
      expect(bundle.entitlements.tippyAi, isTrue);
      expect(bundle.entitlements.advancedAnalytics, isTrue);
      expect(bundle.usage?.aiCreditsUsed, 2);
      expect(bundle.usage?.aiCreditsLimit, 10);
    });

    test('deduplicates identical missions coming from multiple arrays', () {
      final data = <String, dynamic>{
        'dailyMissions': <Map<String, dynamic>>[
          <String, dynamic>{
            'missionId': 'mission-1',
            'templateId': 'daily_post_once',
            'type': 'daily',
            'title': 'Post once',
            'target': 1,
            'progress': 0,
            'rewardXp': 25,
          },
        ],
        'missions': <Map<String, dynamic>>[
          <String, dynamic>{
            'missionId': 'mission-1',
            'templateId': 'daily_post_once',
            'type': 'daily',
            'title': 'Post once',
            'target': 1,
            'progress': 0,
            'rewardXp': 25,
          },
        ],
      };

      final bundle = GamificationMapper.userDocToBundle(data);

      expect(bundle.missions, hasLength(1));
      expect(bundle.missions.single.missionId, 'mission-1');
    });

    test('derives historical progression when gamification data is missing',
        () {
      final bundle = GamificationMapper.userDocToBundle(<String, dynamic>{
        'displayName': 'Tristan',
        'bio': 'Creator and streamer',
        'avatarURL': 'https://example.com/avatar.png',
        'postCount': 5,
        'followerCount': 40,
        'followingCount': 8,
        'platforms': <Map<String, dynamic>>[
          <String, dynamic>{'type': 'youtube'},
        ],
      });

      expect(bundle.progress.totalXp, greaterThan(0));
      expect(bundle.progress.level, greaterThanOrEqualTo(1));
      expect(bundle.missions, isNotEmpty);
      expect(
        bundle.missions.where((mission) => mission.isCompleted),
        isNotEmpty,
      );
    });

    test(
        'uses historical fallback when gamification map is present but empty in practice',
        () {
      final bundle = GamificationMapper.userDocToBundle(<String, dynamic>{
        'gamification': <String, dynamic>{
          'level': 1,
          'totalXp': 0,
          'creatorScore': 0,
          'rankTitle': 'New Creator',
        },
        'displayName': 'technqs',
        'bio': 'Streamer',
        'avatarURL': 'https://example.com/avatar.png',
        'postCount': 6,
        'followerCount': 25,
        'followingCount': 7,
        'platforms': <Map<String, dynamic>>[
          <String, dynamic>{'type': 'youtube'},
        ],
      });

      expect(bundle.progress.totalXp, greaterThan(0));
      expect(bundle.progress.level, greaterThan(1));
      expect(bundle.progress.rankTitle, isNot('New Creator'));
    });
  });
}
