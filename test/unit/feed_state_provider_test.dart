import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/models/feed_tab.dart';
import 'package:streamers_tip/providers/feed_state_provider.dart';

void main() {
  group('feed state providers', () {
    test('activeFeedProvider defaults to For You and can be updated', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(activeFeedProvider), FeedTab.forYou);

      container
          .read(activeFeedProvider.notifier)
          .setActiveFeed(FeedTab.threads);

      expect(container.read(activeFeedProvider), FeedTab.threads);
    });

    test('homeViewReactivateProvider toggles and clears', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(homeViewReactivateProvider), isFalse);

      container.read(homeViewReactivateProvider.notifier).triggerReactivation();
      expect(container.read(homeViewReactivateProvider), isTrue);

      container.read(homeViewReactivateProvider.notifier).clearReactivation();
      expect(container.read(homeViewReactivateProvider), isFalse);
    });
  });
}
