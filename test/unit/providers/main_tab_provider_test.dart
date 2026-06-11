import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamers_tip/providers/main_tab_provider.dart';

void main() {
  group('mainTabActiveIndexProvider', () {
    test('starts at home and updates index', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(mainTabActiveIndexProvider), 0);
      expect(isMainTabHomeVisible(0), isTrue);
      expect(isMainTabNetworkVisible(1), isTrue);

      container.read(mainTabActiveIndexProvider.notifier).setIndex(1);
      expect(container.read(mainTabActiveIndexProvider), 1);
      expect(isMainTabHomeVisible(1), isFalse);

      container.read(mainTabActiveIndexProvider.notifier).setIndex(1);
      expect(container.read(mainTabActiveIndexProvider), 1);
    });
  });

  group('tab background refresh providers', () {
    test('network and inbox ticks increment independently', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(networkTabBackgroundRefreshProvider), 0);
      expect(container.read(inboxTabBackgroundRefreshProvider), 0);

      container
          .read(networkTabBackgroundRefreshProvider.notifier)
          .requestRefresh();
      expect(container.read(networkTabBackgroundRefreshProvider), 1);
      expect(container.read(inboxTabBackgroundRefreshProvider), 0);

      container.read(inboxTabBackgroundRefreshProvider.notifier).requestRefresh();
      expect(container.read(inboxTabBackgroundRefreshProvider), 1);
    });
  });
}
