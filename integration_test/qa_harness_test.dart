import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Verifies the integration_test binding and CI harness. Expand with device
/// suites that sign in via [QaKeys] when staging credentials are available.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('integration harness initializes', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TextField(key: Key('qa_harness_anchor')),
        ),
      ),
    );
    expect(find.byKey(const Key('qa_harness_anchor')), findsOneWidget);
  });
}
