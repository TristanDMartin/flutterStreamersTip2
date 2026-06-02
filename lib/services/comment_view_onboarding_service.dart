import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CommentViewOnboardingService {
  CommentViewOnboardingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _prefThreadsTooltip =
      'streamerstip.comments.threads_tooltip';

  DocumentReference<Map<String, dynamic>> _userRef(String userId) {
    return _firestore.collection('users').doc(userId);
  }

  Future<void> markCommentViewOpened(String userId) async {
    await _userRef(userId).set(
      <String, dynamic>{
        'onboarding': <String, dynamic>{
          'commentViewOpened': true,
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
      SetOptions(merge: true),
    );
  }

  Future<bool> shouldShowThreadsTooltip(String userId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String prefKey = '$_prefThreadsTooltip.$userId';
    if (prefs.getBool(prefKey) == true) {
      return false;
    }
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await _userRef(userId).get();
    final Map<String, dynamic>? onboarding =
        (snap.data()?['onboarding'] as Map?)?.cast<String, dynamic>();
    if (onboarding?['threadsTooltipShown'] == true) {
      await prefs.setBool(prefKey, true);
      return false;
    }
    return true;
  }

  Future<void> markThreadsTooltipShown(String userId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefThreadsTooltip.$userId', true);
    await _userRef(userId).set(
      <String, dynamic>{
        'onboarding': <String, dynamic>{
          'commentViewOpened': true,
          'threadsTooltipShown': true,
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
      SetOptions(merge: true),
    );
  }

  Future<void> markCreatedFirstThread(String userId) async {
    await _userRef(userId).set(
      <String, dynamic>{
        'onboarding': <String, dynamic>{
          'createdFirstThread': true,
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
      SetOptions(merge: true),
    );
  }
}
