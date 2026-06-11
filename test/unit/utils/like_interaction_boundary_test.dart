import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/utils/like_interaction_boundary.dart';

void main() {
  tearDown(LikeInteractionBoundary.resetForTest);

  test('shouldDeferHeavyWork stays true during scroll settle window', () async {
    LikeInteractionBoundary.beginPageScroll();
    expect(LikeInteractionBoundary.shouldDeferHeavyWork, isTrue);
    LikeInteractionBoundary.endPageScroll();
    expect(LikeInteractionBoundary.shouldDeferHeavyWork, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(LikeInteractionBoundary.shouldDeferHeavyWork, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(LikeInteractionBoundary.shouldDeferHeavyWork, isFalse);
  });

  test('runOrQueue executes task after scroll settles', () async {
    var executed = false;
    LikeInteractionBoundary.beginPageScroll();
    LikeInteractionBoundary.runOrQueue(
      () => executed = true,
      reason: 'test',
    );
    expect(executed, isFalse);
    LikeInteractionBoundary.endPageScroll();
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    expect(executed, isTrue);
  });

  test('runAfterFirstInteraction runs task on markFirstUserInteraction', () async {
    var executed = false;
    LikeInteractionBoundary.runAfterFirstInteraction(() {
      executed = true;
    });
    expect(executed, isFalse);
    LikeInteractionBoundary.markFirstUserInteraction();
    await Future<void>.delayed(Duration.zero);
    expect(executed, isTrue);
  });

  test('lightweight like tap still arms post-gesture defer window', () {
    LikeInteractionBoundary.beginLikeTap();
    LikeInteractionBoundary.endLikeTap(lightweight: true);
    expect(LikeInteractionBoundary.shouldDeferHeavyWork, isTrue);
    expect(LikeInteractionBoundary.isActive, isTrue);
  });

  test('waitUntilIdle returns when scroll ends and settles', () async {
    LikeInteractionBoundary.beginPageScroll();
    final Future<void> idleFuture = LikeInteractionBoundary.waitUntilIdle(
      timeout: const Duration(seconds: 2),
    );
    LikeInteractionBoundary.endPageScroll();
    await idleFuture;
    expect(LikeInteractionBoundary.shouldDeferHeavyWork, isFalse);
  });
}
