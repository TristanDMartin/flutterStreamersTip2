import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/billing/mobile_billing_setup_status_banner.dart';

void main() {
  testWidgets('shows setup card when verify URL is not set in test env', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MobileBillingSetupStatusBanner(),
        ),
      ),
    );
    expect(find.textContaining('Backend URL not in this build'), findsOneWidget);
    expect(find.textContaining('verifyMobilePurchase'), findsWidgets);
  });
}
