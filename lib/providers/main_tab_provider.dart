import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Index of the visible main tab (Home=0, Network=1, Create=2, Inbox=3, Profile=4).
class MainTabActiveIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    if (state == index) {
      return;
    }
    state = index;
  }
}

final NotifierProvider<MainTabActiveIndexNotifier, int> mainTabActiveIndexProvider =
    NotifierProvider<MainTabActiveIndexNotifier, int>(
  MainTabActiveIndexNotifier.new,
);

bool isMainTabHomeVisible(int tabIndex) => tabIndex == 0;

bool isMainTabNetworkVisible(int tabIndex) => tabIndex == 1;

bool isMainTabInboxVisible(int tabIndex) => tabIndex == 3;

/// Incremented by [MainTabView] after debounce when a tab becomes active.
class MainTabBackgroundRefreshTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void requestRefresh() {
    state++;
  }
}

final NotifierProvider<MainTabBackgroundRefreshTickNotifier, int>
    networkTabBackgroundRefreshProvider =
    NotifierProvider<MainTabBackgroundRefreshTickNotifier, int>(
  MainTabBackgroundRefreshTickNotifier.new,
);

final NotifierProvider<MainTabBackgroundRefreshTickNotifier, int>
    inboxTabBackgroundRefreshProvider =
    NotifierProvider<MainTabBackgroundRefreshTickNotifier, int>(
  MainTabBackgroundRefreshTickNotifier.new,
);
