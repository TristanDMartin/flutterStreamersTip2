import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/tippy/widgets/tippy_caption_accept_bar.dart';
import 'package:streamers_tip/features/tippy/widgets/tippy_publish_assist_row.dart';

void main() {
  testWidgets('TippyCaptionAcceptBar Accept and Undo fire callbacks', (
    WidgetTester tester,
  ) async {
    bool didAccept = false;
    bool didUndo = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TippyCaptionAcceptBar(
            creditsRemaining: 20,
            onAccept: () => didAccept = true,
            onUndo: () => didUndo = true,
          ),
        ),
      ),
    );
    expect(find.textContaining('20 credits left'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pump();
    expect(didAccept, isTrue);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(didUndo, isTrue);
  });

  testWidgets('TippyPublishAssistRow shows Improving progress label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TippyPublishAssistRow(
            enabled: true,
            busyKind: TippyPublishAssistBusyKind.improving,
            onImproveCaption: null,
            onSuggestHashtags: null,
          ),
        ),
      ),
    );
    expect(find.text('Improving…'), findsOneWidget);
    expect(find.text('Suggest hashtags'), findsOneWidget);
  });
}
