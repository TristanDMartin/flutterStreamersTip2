import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/widgets/screen_feedback_state.dart';

void main() {
  testWidgets('ScreenErrorState shows selectable message and retry',
      (WidgetTester tester) async {
    bool retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScreenErrorState(
            title: 'Load failed',
            message: 'Network unavailable',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    expect(find.text('Load failed'), findsOneWidget);
    expect(find.text('Network unavailable'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('ScreenInlineErrorBanner supports dismiss',
      (WidgetTester tester) async {
    bool dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScreenInlineErrorBanner(
            message: 'Action failed',
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );
    expect(find.text('Action failed'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    expect(dismissed, isTrue);
  });
}
