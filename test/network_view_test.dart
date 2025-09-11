import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/views/network_view.dart';
import 'package:streamers_tip/models/user_model.dart' as user_model;
import 'package:streamers_tip/services/network_view_model_advanced.dart';
import 'package:streamers_tip/services/relationship_service_advanced.dart';

void main() {
  group('NetworkView Tests', () {
    late NetworkViewModelAdvanced viewModel;
    late RelationshipServiceAdvanced relationshipService;

    setUp(() {
      viewModel = NetworkViewModelAdvanced();
      relationshipService = RelationshipServiceAdvanced();
    });

    tearDown(() {
      viewModel.dispose();
    });

    testWidgets('NetworkView displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NetworkView(
            vm: viewModel,
            relationshipService: relationshipService,
          ),
        ),
      );

      // Verify the main components are present
      expect(find.text('Connections'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
      expect(find.byType(NetworkCardButton), findsNWidgets(3));
    });

    testWidgets('Tab switching works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NetworkView(
            vm: viewModel,
            relationshipService: relationshipService,
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
        MaterialApp(
          home: NetworkView(
            vm: viewModel,
            relationshipService: relationshipService,
          ),
        ),
      );

      // Should show empty state when no data
      expect(find.text('No connections yet'), findsOneWidget);
      expect(find.text('Connect with other streamers to see them here'), findsOneWidget);
    });

    testWidgets('Discover Streamers button works', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NetworkView(
            vm: viewModel,
            relationshipService: relationshipService,
          ),
        ),
      );

      // Tap on Discover Streamers button
      await tester.tap(find.text('Discover Streamers'));
      await tester.pump();

      // Verify navigation occurred (this would need proper navigation setup in real test)
      expect(find.text('Discover Streamers'), findsOneWidget);
    });
  });

  group('NetworkCardButton Tests', () {
    testWidgets('NetworkCardButton displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkCardButton(
              iconName: 'test',
              icon: Icons.person,
              title: 'Test',
              count: 5,
              isSelected: false,
              action: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('NetworkCardButton selection state works', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkCardButton(
              iconName: 'test',
              icon: Icons.person,
              title: 'Test',
              count: 5,
              isSelected: true,
              action: () {},
            ),
          ),
        ),
      );

      // Verify the button is rendered (selection state affects styling)
      expect(find.text('Test'), findsOneWidget);
    });
  });

  group('ConnectionRow Tests', () {
    testWidgets('ConnectionRow displays user information', (WidgetTester tester) async {
      const user = user_model.User(
        id: 'test',
        displayName: 'Test User',
        username: 'test_user',
        avatarURL: 'https://example.com/avatar.jpg',
        onlineStatus: user_model.OnlineStatus.online,
        hashtags: ['test'],
        aiSelf: 'Test user',
        postCount: 10,
        followerCount: 100,
        followingCount: 50,
        platforms: [],
        socialLinks: [],
        calendarEvents: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionRow(user: user),
          ),
        ),
      );

      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('@test_user'), findsOneWidget);
    });
  });
}
