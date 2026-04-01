import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/forum_author.dart';
import '../models/user.dart' as app_user;

class DiscussionAuthorService {
  static final DiscussionAuthorService _instance =
      DiscussionAuthorService._internal();
  factory DiscussionAuthorService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DiscussionAuthorService._internal();

  Future<Map<String, dynamic>?> loadUserData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists || userDoc.data() == null) {
        return null;
      }
      return userDoc.data();
    } catch (_) {
      return null;
    }
  }

  Future<ForumAuthor> loadForumAuthor(String userId) async {
    final data = await loadUserData(userId);
    if (data == null) {
      throw Exception('User profile not found');
    }
    return ForumAuthor.fromUserData(userId, data);
  }

  Future<app_user.User> enrichCommentUser(app_user.User user) async {
    final data = await loadUserData(user.id);
    if (data == null) return user;

    final onlineStatus = data['status'] as String? ??
        data['userStatus'] as String? ??
        data['onlineStatus'] as String? ??
        (data['isOnline'] == true ? 'online' : 'offline');

    return app_user.User(
      id: user.id,
      username: (data['username'] as String?) ?? user.username,
      displayName: (data['displayName'] as String?) ?? user.displayName,
      bio: (data['bio'] as String?) ?? user.bio,
      avatarURL: (data['avatarURL'] as String?) ??
          (data['avatarUrl'] as String?) ??
          user.avatarURL,
      onlineStatus: onlineStatus,
      hashtags: user.hashtags,
      aiSelf: user.aiSelf,
      postCount: user.postCount,
      followerCount: user.followerCount,
      followingCount: user.followingCount,
      calendarEvents: user.calendarEvents,
    );
  }

  Future<String?> loadAvatarUrl(String userId) async {
    final data = await loadUserData(userId);
    if (data == null) return null;
    final avatarUrl =
        (data['avatarURL'] as String?) ?? (data['avatarUrl'] as String?);
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    return avatarUrl;
  }
}
