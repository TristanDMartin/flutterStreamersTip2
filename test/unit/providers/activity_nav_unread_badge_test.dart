import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/providers/activity_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ActivityNavUnreadBadge', () {
    test('stays cleared for same unread count after viewing Activity', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          unreadActivityCountProvider.overrideWith(
            (Ref ref) => Stream<int>.value(3),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(activityNavUnreadCountProvider.notifier);
      await pumpEventQueue();
      expect(container.read(activityNavUnreadCountProvider), 3);

      container
          .read(activityNavUnreadCountProvider.notifier)
          .clearAfterActivityViewed();
      expect(container.read(activityNavUnreadCountProvider), 0);

      // Same count should not revive the badge.
      await pumpEventQueue();
      expect(container.read(activityNavUnreadCountProvider), 0);
    });

    test('revives only when unread grows past acknowledged', () async {
      final StreamController<int> counts = StreamController<int>.broadcast();
      addTearDown(counts.close);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          unreadActivityCountProvider.overrideWith(
            (Ref ref) => counts.stream,
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(activityNavUnreadCountProvider.notifier);
      counts.add(2);
      await pumpEventQueue();
      expect(container.read(activityNavUnreadCountProvider), 2);

      container
          .read(activityNavUnreadCountProvider.notifier)
          .clearAfterActivityViewed();
      expect(container.read(activityNavUnreadCountProvider), 0);

      counts.add(2);
      await pumpEventQueue();
      expect(container.read(activityNavUnreadCountProvider), 0);

      counts.add(3);
      await pumpEventQueue();
      expect(container.read(activityNavUnreadCountProvider), 3);
    });

    test('lifts suppression when firestore reaches zero', () async {
      final StreamController<int> counts = StreamController<int>.broadcast();
      addTearDown(counts.close);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          unreadActivityCountProvider.overrideWith(
            (Ref ref) => counts.stream,
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(activityNavUnreadCountProvider.notifier);
      counts.add(4);
      await pumpEventQueue();
      container
          .read(activityNavUnreadCountProvider.notifier)
          .clearAfterActivityViewed();
      expect(container.read(activityNavUnreadCountProvider), 0);

      counts.add(0);
      await pumpEventQueue();
      expect(container.read(activityNavUnreadCountProvider), 0);

      counts.add(1);
      await pumpEventQueue();
      expect(container.read(activityNavUnreadCountProvider), 1);
    });
  });
}
