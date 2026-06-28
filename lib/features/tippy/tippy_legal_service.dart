import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'tippy_chat_service.dart';

typedef TippyUserIdResolver = String? Function();

/// Consent, kill-switch, and prompt-history deletion for Tippy AI.
class TippyLegalService {
  TippyLegalService({
    FirebaseFirestore? firestore,
    TippyChatService? chatService,
    Future<void> Function()? remoteHistoryDeleter,
    TippyUserIdResolver? userIdResolver,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _chatService = chatService,
        _remoteHistoryDeleter = remoteHistoryDeleter,
        _userIdResolver = userIdResolver ??
            (() => FirebaseAuth.instance.currentUser?.uid);

  static const String consentVersion = '1';
  static const String featureFlagDoc = 'feature_flags';
  static const String tippyEnabledFlag = 'tippyEnabled';

  final FirebaseFirestore _firestore;
  final TippyChatService? _chatService;
  final Future<void> Function()? _remoteHistoryDeleter;
  final TippyUserIdResolver _userIdResolver;

  DocumentReference<Map<String, dynamic>>? _privacyDoc() {
    final String? uid = _userIdResolver();
    if (uid == null) {
      return null;
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('privacySettings')
        .doc('main');
  }

  Future<bool> hasConsent() async {
    final DocumentReference<Map<String, dynamic>>? docRef = _privacyDoc();
    if (docRef == null) {
      return false;
    }
    final DocumentSnapshot<Map<String, dynamic>> snap = await docRef.get();
    final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
    return _consentGranted(data);
  }

  Future<void> recordConsent() async {
    final DocumentReference<Map<String, dynamic>>? docRef = _privacyDoc();
    if (docRef == null) {
      throw StateError('Sign in required to accept Tippy consent.');
    }
    await docRef.set(
      <String, dynamic>{
        'tippyAiConsentAt': FieldValue.serverTimestamp(),
        'tippyAiConsentVersion': consentVersion,
      },
      SetOptions(merge: true),
    );
  }

  Stream<bool> watchTippyEnabled() {
    return _firestore
        .collection('system')
        .doc(featureFlagDoc)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> snap) {
      final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
      if (data[tippyEnabledFlag] == false) {
        return false;
      }
      return true;
    });
  }

  Future<bool> isTippyEnabled() async {
    final DocumentSnapshot<Map<String, dynamic>> snap = await _firestore
        .collection('system')
        .doc(featureFlagDoc)
        .get();
    final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
    return data[tippyEnabledFlag] != false;
  }

  Future<void> deleteAllPromptHistory() async {
    final String? uid = _userIdResolver();
    if (uid == null) {
      throw StateError('Sign in required.');
    }
    final CollectionReference<Map<String, dynamic>> conversations =
        _firestore
            .collection('users')
            .doc(uid)
            .collection('tippyConversations');
    await _deleteCollectionBatch(conversations);
    if (_remoteHistoryDeleter != null) {
      await _remoteHistoryDeleter!();
      return;
    }
    final TippyChatService service = _chatService ?? TippyChatService();
    try {
      await service.deletePromptHistory();
    } finally {
      if (_chatService == null) {
        service.dispose();
      }
    }
  }

  Future<void> _deleteCollectionBatch(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    const int pageSize = 200;
    while (true) {
      final QuerySnapshot<Map<String, dynamic>> snap =
          await collection.limit(pageSize).get();
      if (snap.docs.isEmpty) {
        return;
      }
      final WriteBatch batch = _firestore.batch();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  bool _consentGranted(Map<String, dynamic> data) {
    if (data['tippyAiConsentAt'] == null) {
      return false;
    }
    final String version =
        (data['tippyAiConsentVersion'] ?? '').toString().trim();
    if (version.isEmpty) {
      return false;
    }
    return version == consentVersion;
  }
}
