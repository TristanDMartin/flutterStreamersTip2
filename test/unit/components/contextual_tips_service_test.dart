import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/components/onboarding/contextual_tips_service.dart';

void main() {
  group('ContextualTipsService', () {
    test('markTipSeen persists tippy and planner flags independently', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final ContextualTipsService service =
          ContextualTipsService(firestore: firestore);
      await service.markTipSeen('user-1', 'tippySeen');
      final ContextualTipsState state = await service.fetchTips('user-1');
      expect(state.tippySeen, isTrue);
      expect(state.contentPlannerSeen, isFalse);
    });

    test('resetAllTips clears feature tips', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('user-1').set(
        <String, dynamic>{
          'tooltips': <String, dynamic>{
            'tippySeen': true,
            'contentPlannerSeen': true,
          },
        },
      );
      final ContextualTipsService service =
          ContextualTipsService(firestore: firestore);
      await service.resetAllTips('user-1');
      final ContextualTipsState state = await service.fetchTips('user-1');
      expect(state.tippySeen, isFalse);
      expect(state.contentPlannerSeen, isFalse);
    });
  });
}
