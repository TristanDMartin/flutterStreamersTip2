import 'package:cloud_firestore/cloud_firestore.dart';

/// Contextual one-time tips — separate from onboarding (never restarts onboarding).
class ContextualTipsService {
  ContextualTipsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userRef(String userId) {
    return _firestore.collection('users').doc(userId);
  }

  Stream<ContextualTipsState> watchTips(String userId) {
    return _userRef(userId)
        .snapshots()
        .map(
          (DocumentSnapshot<Map<String, dynamic>> snapshot) =>
              ContextualTipsState.fromUserMap(snapshot.data()),
        )
        .distinct();
  }

  Future<ContextualTipsState> fetchTips(String userId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _userRef(userId).get();
    return ContextualTipsState.fromUserMap(snapshot.data());
  }

  Future<void> markTipSeen(String userId, String tipKey) async {
    try {
      await _userRef(userId).set(
        <String, dynamic>{
          'tooltips': <String, dynamic>{
            tipKey: true,
          },
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return;
      }
      rethrow;
    }
  }

  Future<void> resetAllTips(String userId) async {
    const Map<String, bool> cleared = <String, bool>{
      'homeFeedSeen': false,
      'uploadSeen': false,
      'tippySeen': false,
      'creatorCardSeen': false,
      'contentPlannerSeen': false,
      'networkSeen': false,
      'inboxSeen': false,
      'profileSeen': false,
    };
    try {
      await _userRef(userId).set(
        <String, dynamic>{'tooltips': cleared},
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return;
      }
      rethrow;
    }
  }
}

class ContextualTipsState {
  const ContextualTipsState({
    required this.homeFeedSeen,
    required this.uploadSeen,
    required this.tippySeen,
    required this.creatorCardSeen,
    required this.contentPlannerSeen,
    required this.networkSeen,
    required this.inboxSeen,
    required this.profileSeen,
  });

  factory ContextualTipsState.initial() {
    return const ContextualTipsState(
      homeFeedSeen: false,
      uploadSeen: false,
      tippySeen: false,
      creatorCardSeen: false,
      contentPlannerSeen: false,
      networkSeen: false,
      inboxSeen: false,
      profileSeen: false,
    );
  }

  factory ContextualTipsState.fromUserMap(Map<String, dynamic>? data) {
    if (data == null) {
      return ContextualTipsState.initial();
    }
    final Map<String, dynamic> tips =
        (data['tooltips'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    return ContextualTipsState(
      homeFeedSeen: tips['homeFeedSeen'] == true,
      uploadSeen: tips['uploadSeen'] == true,
      tippySeen: tips['tippySeen'] == true,
      creatorCardSeen: tips['creatorCardSeen'] == true,
      contentPlannerSeen: tips['contentPlannerSeen'] == true,
      networkSeen: tips['networkSeen'] == true,
      inboxSeen: tips['inboxSeen'] == true,
      profileSeen: tips['profileSeen'] == true,
    );
  }

  final bool homeFeedSeen;
  final bool uploadSeen;
  final bool tippySeen;
  final bool creatorCardSeen;
  final bool contentPlannerSeen;
  final bool networkSeen;
  final bool inboxSeen;
  final bool profileSeen;

  bool hasSeen(String tipKey) {
    switch (tipKey) {
      case 'homeFeedSeen':
        return homeFeedSeen;
      case 'uploadSeen':
        return uploadSeen;
      case 'tippySeen':
        return tippySeen;
      case 'creatorCardSeen':
        return creatorCardSeen;
      case 'contentPlannerSeen':
        return contentPlannerSeen;
      case 'networkSeen':
        return networkSeen;
      case 'inboxSeen':
        return inboxSeen;
      case 'profileSeen':
        return profileSeen;
      default:
        return true;
    }
  }
}
