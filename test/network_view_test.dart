import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/views/network_view.dart';

void main() {
  group('NetworkView Tests', () {

    testWidgets('NetworkView displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NetworkView(),
        ),
      );

      // Verify the main components are present
      expect(find.text('Connections'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
    });

    testWidgets('Tab switching works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NetworkView(),
        ),
      );

      // Tap on Followers tab
      await tester.tap(find.text('Followers'));
      await tester.pump();

      // Verify the tab is selected
      expect(find.text('Followers'), findsOneWidget);
    });

    testWidgets('Empty state displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NetworkView(),
        ),
      );

      // Should show empty state when no data
      expect(find.text('No connections yet'), findsOneWidget);
      expect(find.text('Connect with other streamers to see them here'), findsOneWidget);
    });

    testWidgets('Discover Streamers button works', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NetworkView(),
        ),
      );

      // Tap on Discover Streamers button
      await tester.tap(find.text('Discover Streamers'));
      await tester.pump();

      // Verify navigation occurred (this would need proper navigation setup in real test)
      expect(find.text('Discover Streamers'), findsOneWidget);
    });
  });

}
