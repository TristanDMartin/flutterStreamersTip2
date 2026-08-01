import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/activity/pulse/activity_pulse_logic.dart';
import 'package:streamers_tip/features/gamification/models/user_progress_bundle.dart';
import 'package:streamers_tip/models/activity_notification.dart';
import 'package:streamers_tip/models/user.dart';

void main() {
  group('ActivityPulseLogic.insightsFromBundle', () {
    test('does not invent client-only coaching rows', () {
      expect(
        ActivityPulseLogic.insightsFromBundle(UserProgressBundle.fallback()),
        isEmpty,
      );
    });
  });

  group('ActivityPulseLogic.processGrouped', () {
    test('keeps only real notifications in Today', () {
      final ActivityNotification like = ActivityNotification(
        id: 'n1',
        type: ActivityNotificationType.like,
        user: const User(
          id: 'u1',
          username: 'a',
          displayName: 'A',
          bio: '',
          hashtags: <String>[],
        ),
        timestamp: DateTime(2026, 7, 30, 12),
        status: 'pending',
        videoId: 'v1',
      );
      final Map<String, List<ActivityPulseEntry>> actual =
          ActivityPulseLogic.processGrouped(
        grouped: <String, List<ActivityNotification>>{
          'Today': <ActivityNotification>[like],
        },
        filter: ActivityPulseFilter.all,
        bundle: UserProgressBundle.fallback(),
      );
      expect(actual['Today'], hasLength(1));
      expect(actual['Today']!.single, isA<ActivityPulseSingle>());
    });
  });
}
