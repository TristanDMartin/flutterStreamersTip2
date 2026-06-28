import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/tippy/tippy_legal_service.dart';

void main() {
  group('TippyLegalService', () {
    test('hasConsent returns false when consent missing', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final TippyLegalService service = TippyLegalService(
        firestore: firestore,
        userIdResolver: () => 'user_1',
      );
      final bool actual = await service.hasConsent();
      expect(actual, isFalse);
    });

    test('recordConsent and hasConsent round-trip', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final TippyLegalService service = TippyLegalService(
        firestore: firestore,
        userIdResolver: () => 'user_1',
      );
      await service.recordConsent();
      final bool actual = await service.hasConsent();
      expect(actual, isTrue);
      final DocumentSnapshot<Map<String, dynamic>> doc = await firestore
          .collection('users')
          .doc('user_1')
          .collection('privacySettings')
          .doc('main')
          .get();
      expect(doc.data()?['tippyAiConsentVersion'], TippyLegalService.consentVersion);
    });

    test('isTippyEnabled defaults true when flag missing', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final TippyLegalService service = TippyLegalService(firestore: firestore);
      final bool actual = await service.isTippyEnabled();
      expect(actual, isTrue);
    });

    test('isTippyEnabled returns false when flag disabled', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore.collection('system').doc('feature_flags').set(
        <String, dynamic>{'tippyEnabled': false},
      );
      final TippyLegalService service = TippyLegalService(firestore: firestore);
      final bool actual = await service.isTippyEnabled();
      expect(actual, isFalse);
    });

    test('deleteAllPromptHistory removes saved conversations', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await firestore
          .collection('users')
          .doc('user_1')
          .collection('tippyConversations')
          .doc('c1')
          .set(<String, dynamic>{'title': 'Test'});
      final TippyLegalService service = TippyLegalService(
        firestore: firestore,
        userIdResolver: () => 'user_1',
        remoteHistoryDeleter: () async {},
      );
      await service.deleteAllPromptHistory();
      final QuerySnapshot<Map<String, dynamic>> snap = await firestore
          .collection('users')
          .doc('user_1')
          .collection('tippyConversations')
          .get();
      expect(snap.docs, isEmpty);
    });
  });
}
