import 'package:flutter_riverpod/flutter_riverpod.dart';

class TabsNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setSelectedTab(int index) => state = index;
}

final NotifierProvider<TabsNotifier, int> tabsProvider =
    NotifierProvider<TabsNotifier, int>(TabsNotifier.new);
