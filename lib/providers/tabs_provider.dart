import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

class TabsNotifier extends StateNotifier<int> {
  TabsNotifier() : super(0);

  void setSelectedTab(int index) {
    state = index;
  }

  int get selectedTab => state;
}

final tabsProvider = StateNotifierProvider<TabsNotifier, int>((ref) {
  return TabsNotifier();
});

// Alternative implementation using ChangeNotifier if you prefer
class TabsViewModel extends ChangeNotifier {
  int _selectedTab = 0;

  int get selectedTab => _selectedTab;

  void setSelectedTab(int index) {
    if (_selectedTab != index) {
      _selectedTab = index;
      notifyListeners();
    }
  }
}

// Provider for the ChangeNotifier version
final tabsViewModelProvider = ChangeNotifierProvider<TabsViewModel>((ref) {
  return TabsViewModel();
});

// Usage examples:
// 
// In a ConsumerWidget:
// final selectedTab = ref.watch(tabsProvider);
// ref.read(tabsProvider.notifier).setSelectedTab(1);
//
// In a ChangeNotifier version:
// final tabsViewModel = ref.watch(tabsViewModelProvider);
// tabsViewModel.setSelectedTab(1);
