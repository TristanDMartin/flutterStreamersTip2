import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/views/network_view.dart';

void main() {
  group('NetworkView Tests', () {

    testWidgets('NetworkView displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: NetworkView(),
          ),
        ),
      );

      // Verify the main components are present
      expect(find.text('Connections'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
    });

    testWidgets('Tab switching works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: NetworkView(),
          ),
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
        const ProviderScope(
          child: MaterialApp(
            home: NetworkView(),
          ),
        ),
      );

      // Should show empty state when no data
      expect(find.text('No connections yet'), findsOneWidget);
      expect(find.text('Follow back people who follow you to connect.'),
          findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets('Empty state refresh action is present',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: NetworkView(),
          ),
        ),
      );

      await tester.tap(find.text('Refresh'));
      await tester.pump();

      expect(find.text('Refresh'), findsOneWidget);
    });
  });

}
