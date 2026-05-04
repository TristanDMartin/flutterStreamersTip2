import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/models/feed_tab.dart';
import 'package:streamers_tip/widgets/home_view_components/feed_selector_widget.dart';

Widget _buildSelector({
  FeedTab activeTab = FeedTab.forYou,
  ValueChanged<FeedTab>? onTabSelected,
  VoidCallback? onDiscoverTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: FeedSelectorWidget(
        activeTab: activeTab,
        onTabSelected: onTabSelected ?? (_) {},
        onDiscoverTap: onDiscoverTap ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets('opens and closes the feed dropdown from the anchored selector', (
    tester,
  ) async {
    await tester.pumpWidget(_buildSelector());

    expect(find.text('Progression'), findsNothing);

    await tester.tap(find.text('For You'));
    await tester.pumpAndSettle();

    expect(find.text('Progression'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('feed-selector-overlay-barrier')),
      findsOneWidget,
    );

    await tester
        .tap(find.byKey(const ValueKey('feed-selector-overlay-barrier')));
    await tester.pumpAndSettle();

    expect(find.text('Progression'), findsNothing);
  });

  testWidgets('selecting a tab closes the dropdown and reports the tab', (
    tester,
  ) async {
    FeedTab? selected;
    await tester.pumpWidget(
      _buildSelector(
        onTabSelected: (tab) {
          selected = tab;
        },
      ),
    );

    await tester.tap(find.text('For You'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Threads'));
    await tester.pumpAndSettle();

    expect(selected, FeedTab.threads);
    expect(find.text('Progression'), findsNothing);
  });
}
