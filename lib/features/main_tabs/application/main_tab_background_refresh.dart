import 'dart:async';

/// Debounces per-tab background refresh so rapid tab switches do not stack work.
class MainTabBackgroundRefreshScheduler {
  MainTabBackgroundRefreshScheduler({
    this.debounce = const Duration(milliseconds: 700),
  });

  final Duration debounce;
  final Map<int, Timer> _timers = <int, Timer>{};

  void schedule({
    required int tabIndex,
    required int currentTabIndex,
    required bool Function() isMounted,
    required Future<void> Function() refresh,
  }) {
    _timers[tabIndex]?.cancel();
    _timers[tabIndex] = Timer(debounce, () {
      if (!isMounted() || currentTabIndex != tabIndex) {
        return;
      }
      unawaited(refresh());
    });
  }

  void cancelAll() {
    for (final Timer timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  void dispose() {
    cancelAll();
  }
}
