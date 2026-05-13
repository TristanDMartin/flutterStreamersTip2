import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/billing/mobile_billing_setup_status_banner.dart';

void main() {
  testWidgets('shows configured state when verify URL has a default endpoint', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MobileBillingSetupStatusBanner(),
        ),
      ),
    );
    expect(
        find.textContaining('Server verification is enabled'), findsOneWidget);
    expect(find.textContaining('Backend URL not in this build'), findsNothing);
  });
}
