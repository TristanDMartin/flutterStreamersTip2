import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/activity/activity_notification_rules.dart';

void main() {
  group('isSyntheticTestVideoId', () {
    test('keeps real video_ prefixed production ids', () {
      expect(
        isSyntheticTestVideoId('video_1781812811116-7a9102de-aa03'),
        isFalse,
      );
      expect(isSyntheticTestVideoId('vid_776d8a14cfb6445f'), isFalse);
    });

    test('drops short seed ids and explicit test prefixes', () {
      expect(isSyntheticTestVideoId('video_1'), isTrue);
      expect(isSyntheticTestVideoId('test_video_abc'), isTrue);
      expect(isSyntheticTestVideoId('mock_video_1'), isTrue);
    });

    test('does not false-positive on substring test', () {
      expect(
        isSyntheticTestVideoId('video_abctest12_long_enough_id'),
        isFalse,
      );
    });
  });

  group('isActivityNotificationDocUnread', () {
    test('treats isRead false as unread', () {
      expect(
        isActivityNotificationDocUnread(<String, dynamic>{'isRead': false}),
        isTrue,
      );
    });

    test('treats isRead true or read true as read', () {
      expect(
        isActivityNotificationDocUnread(<String, dynamic>{'isRead': true}),
        isFalse,
      );
      expect(
        isActivityNotificationDocUnread(<String, dynamic>{'read': true}),
        isFalse,
      );
    });
  });

  group('shouldHideFromActivityUnreadBadge', () {
    test('hides content_plan_expired like website', () {
      expect(
        shouldHideFromActivityUnreadBadge('content_plan_expired'),
        isTrue,
      );
      expect(shouldHideFromActivityFeed('content_plan_expired'), isTrue);
      expect(shouldHideFromActivityUnreadBadge('LIKE_VIDEO'), isFalse);
      expect(shouldHideFromActivityFeed('tippy_coach'), isFalse);
    });
  });

  group('tippy and planner notification helpers', () {
    test('maps tippy_coach and content_plan_queue as system types', () {
      expect(isTippyCoachNotificationType('tippy_coach'), isTrue);
      expect(isContentPlanNotificationType('content_plan_queue'), isTrue);
      expect(isGlobalSystemNotificationType('tippy_coach'), isTrue);
    });

    test('builds website-style title and body message', () {
      final String actual = activityNotificationDisplayMessage(
        <String, dynamic>{
          'type': 'tippy_coach',
          'title': 'A trend matches your niche',
          'body':
              '“Ranked climb live” looks like a strong fit. Open Trend Discovery.',
        },
      );
      expect(actual, contains('A trend matches your niche'));
      expect(actual, contains('Ranked climb live'));
    });

    test('parses epoch millis timestamps from retention writers', () {
      final DateTime actual = readActivityTimestamp(<String, dynamic>{
        'timestamp': 1722460800000,
      });
      expect(actual.millisecondsSinceEpoch, 1722460800000);
    });

    test('resolves Trend Discovery website action urls', () {
      expect(
        resolveActivityWebsiteActionUrl('/dashboard/trending'),
        'https://streamerstip.com/dashboard/trending',
      );
      expect(
        resolveActivityWebsiteActionUrl(
          '/dashboard/trending?category=platform_updates',
        ),
        contains('category=platform_updates'),
      );
      expect(
        tippyPromptFromActivityNotification(
          titleAndBody: 'A trend matches your niche\nRanked climb live',
          actionUrl: '/dashboard/trending',
        ),
        contains('Ranked climb live'),
      );
    });
  });
}
