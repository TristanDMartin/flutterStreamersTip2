import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/components/onboarding/account_enforcement.dart';
import 'package:streamers_tip/views/banned_account_view.dart';
import 'package:streamers_tip/views/deactivated_account_view.dart';

void main() {
  testWidgets('banned screen shows appeal and sign out', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: BannedAccountView()),
      ),
    );
    expect(find.text(kBannedAccountTitle), findsOneWidget);
    expect(find.text(kBannedAccountBody), findsOneWidget);
    expect(find.text('Get Help / Appeal'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(find.text('For You'), findsNothing);
    expect(find.text('Tippy'), findsNothing);
  });

  testWidgets('deactivated screen shows reactivate and sign out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DeactivatedAccountView()),
      ),
    );
    expect(find.text(kDeactivatedAccountTitle), findsOneWidget);
    expect(find.text('Reactivate'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(find.text('Post'), findsNothing);
  });
}
