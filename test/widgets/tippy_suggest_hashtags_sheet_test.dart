import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/tippy/tippy_publish_caption_helpers.dart';
import 'package:streamers_tip/features/tippy/widgets/tippy_suggest_hashtags_sheet.dart';

void main() {
  testWidgets('Add Selected returns only checked hashtags', (
    WidgetTester tester,
  ) async {
    TippySuggestHashtagsResult? actual;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  actual = await TippySuggestHashtagsSheet.show(
                    context,
                    hashtags: const <String>['#apex', '#fyp', '#clips'],
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#fyp'));
    await tester.pump();
    await tester.tap(find.text('Add Selected (2)'));
    await tester.pumpAndSettle();
    expect(actual, isNotNull);
    expect(actual!.mode, TippyHashtagApplyMode.addSelected);
    expect(actual!.selectedHashtags, <String>['#apex', '#clips']);
    expect(actual!.allHashtags, <String>['#apex', '#fyp', '#clips']);
  });

  testWidgets('Replace returns replace mode with selected tags', (
    WidgetTester tester,
  ) async {
    TippySuggestHashtagsResult? actual;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  actual = await TippySuggestHashtagsSheet.show(
                    context,
                    hashtags: const <String>['#gaming', '#live'],
                    creditsRemaining: 12,
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('12 Tippy credits left'), findsOneWidget);
    await tester.tap(find.text('Replace hashtags'));
    await tester.pumpAndSettle();
    expect(actual?.mode, TippyHashtagApplyMode.replace);
    expect(actual?.selectedHashtags, <String>['#gaming', '#live']);
  });
}
