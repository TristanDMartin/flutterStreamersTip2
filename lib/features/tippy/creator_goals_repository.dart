import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'tippy_chat_service.dart';
import 'models/creator_goal_model.dart';

class CreatorGoalsRepository {
  CreatorGoalsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    TippyChatService? chatService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _chatService = chatService ?? TippyChatService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final TippyChatService _chatService;

  Stream<List<CreatorGoalModel>> watchActiveGoals() {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream<List<CreatorGoalModel>>.value(const <CreatorGoalModel>[]);
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('creatorGoals')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
      final List<CreatorGoalModel> goals = snapshot.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                CreatorGoalModel.fromFirestore(doc.id, doc.data()),
          )
          .toList(growable: false)
        ..sort(
          (CreatorGoalModel a, CreatorGoalModel b) =>
              a.priority.compareTo(b.priority),
        );
      return goals;
    });
  }

  Future<CreatorGoalModel> saveGoal(CreatorGoalModel goal) async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in to save goals.');
    }
    final Map<String, dynamic> payload = goal.toWritePayload();
    payload['uid'] = uid;
    if (goal.id.isNotEmpty) {
      payload['goalId'] = goal.id;
    }
    final Map<String, dynamic> response =
        await _chatService.saveCreatorGoal(payload);
    final String goalId =
        (response['goalId'] as String?) ?? goal.id;
    final Map<String, dynamic>? goalMap =
        response['goal'] is Map<String, dynamic>
            ? response['goal'] as Map<String, dynamic>
            : null;
    if (goalMap != null) {
      return CreatorGoalModel.fromFirestore(goalId, goalMap);
    }
    return CreatorGoalModel(
      id: goalId,
      uid: uid,
      type: goal.type,
      title: goal.title,
      platform: goal.platform,
      targetValue: goal.targetValue,
      currentValue: goal.currentValue,
      unit: goal.unit,
      deadlineAt: goal.deadlineAt,
      status: goal.status,
      priority: goal.priority,
    );
  }
}
