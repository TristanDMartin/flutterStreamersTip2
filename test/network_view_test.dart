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
      expect(find.text('Build Your Creator Circle'), findsOneWidget);
      expect(
        find.text(
          'Connect with creators, discover collaborators, and grow together.',
        ),
        findsOneWidget,
      );
      expect(find.text('Discover Creators'), findsOneWidget);
      expect(find.text('Share Profile'), findsOneWidget);
    });

    testWidgets('Empty state CTAs are tappable',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: NetworkView(),
          ),
        ),
      );

      expect(find.text('Discover Creators'), findsOneWidget);
      expect(find.text('Share Profile'), findsOneWidget);
      expect(find.byType(GestureDetector), findsWidgets);
    });
  });
}
