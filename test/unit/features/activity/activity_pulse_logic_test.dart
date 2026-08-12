import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/activity/pulse/activity_pulse_logic.dart';
import 'package:streamers_tip/features/gamification/models/user_progress_bundle.dart';
import 'package:streamers_tip/models/activity_notification.dart';
import 'package:streamers_tip/models/user.dart';

ActivityNotification _notif({
  required String id,
  required ActivityNotificationType type,
  String? actionType,
  String? videoId,
  String? threadId,
  String? postId,
}) {
  return ActivityNotification(
    id: id,
    type: type,
    user: const User(
      id: 'u1',
      username: 'a',
      displayName: 'A',
      bio: '',
      hashtags: <String>[],
    ),
    timestamp: DateTime(2026, 7, 30, 12),
    status: 'pending',
    actionType: actionType,
    videoId: videoId,
    threadId: threadId,
    postId: postId,
  );
}

void main() {
  group('ActivityPulseFilter contract', () {
    test('matches website ACTIVITY_PAGE_TABS order and labels', () {
      expect(
        ActivityPulseLogic.filters.map((ActivityPulseFilter f) => f.label),
        <String>[
          'All',
          'Follows',
          'Likes',
          'Comments',
          'Mentions',
          'Threads',
          'Global',
        ],
      );
    });
  });

  group('ActivityPulseLogic.insightsFromBundle', () {
    test('does not invent client-only coaching rows', () {
      expect(
        ActivityPulseLogic.insightsFromBundle(UserProgressBundle.fallback()),
        isEmpty,
      );
    });
  });

  group('matchesFilter website parity', () {
    test('routes content plan and tippy to Global', () {
      final ActivityNotification queue = _notif(
        id: 'q',
        type: ActivityNotificationType.adminBroadcast,
        actionType: 'content_plan_queue',
      );
      final ActivityNotification tippy = _notif(
        id: 't',
        type: ActivityNotificationType.adminBroadcast,
        actionType: 'tippy_coach',
      );
      expect(queue.matchesFilter(ActivityPulseFilter.global), isTrue);
      expect(queue.matchesFilter(ActivityPulseFilter.likes), isFalse);
      expect(tippy.matchesFilter(ActivityPulseFilter.global), isTrue);
      expect(tippy.matchesFilter(ActivityPulseFilter.threads), isFalse);
    });

    test('splits video comments vs thread comments', () {
      final ActivityNotification videoComment = _notif(
        id: 'c',
        type: ActivityNotificationType.comment,
        actionType: 'COMMENT_VIDEO',
        videoId: 'v1',
      );
      final ActivityNotification threadComment = _notif(
        id: 'tc',
        type: ActivityNotificationType.comment,
        actionType: 'COMMENT_THREAD',
        threadId: 'th1',
      );
      expect(videoComment.matchesFilter(ActivityPulseFilter.comments), isTrue);
      expect(videoComment.matchesFilter(ActivityPulseFilter.threads), isFalse);
      expect(threadComment.matchesFilter(ActivityPulseFilter.threads), isTrue);
      expect(threadComment.matchesFilter(ActivityPulseFilter.comments), isFalse);
    });

    test('collab invites land in Threads not Follows', () {
      final ActivityNotification invite = _notif(
        id: 'i',
        type: ActivityNotificationType.follow,
        actionType: 'COLLAB_INVITE',
      );
      expect(invite.matchesFilter(ActivityPulseFilter.threads), isTrue);
      expect(invite.matchesFilter(ActivityPulseFilter.follows), isFalse);
    });
  });

  group('ActivityPulseLogic.processGrouped', () {
    test('keeps only real notifications in Today', () {
      final ActivityNotification like = _notif(
        id: 'n1',
        type: ActivityNotificationType.like,
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
