import '../models/forum_author.dart';
import '../models/user.dart' as app_user;
import '../utils/avatar_url_resolver.dart';
import 'public_profile_firestore.dart';

class DiscussionAuthorService {
  static final DiscussionAuthorService _instance =
      DiscussionAuthorService._internal();
  factory DiscussionAuthorService() => _instance;

  DiscussionAuthorService._internal();

  Future<Map<String, dynamic>?> loadUserData(String userId) async {
    return PublicProfileFirestore.instance.getProfileMap(userId);
  }

  Future<ForumAuthor> loadForumAuthor(String userId) async {
    final data = await loadUserData(userId);
    if (data == null) {
      throw Exception('User profile not found');
    }
    return ForumAuthor.fromUserData(userId, data);
  }

  Stream<ForumAuthor?> watchForumAuthor(String userId) {
    return PublicProfileFirestore.instance.watchProfile(userId).map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) {
        return null;
      }
      return ForumAuthor.fromUserData(userId, data);
    });
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
      avatarURL: resolveAvatarUrl(data) ?? user.avatarURL,
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
    final avatarUrl = resolveAvatarUrl(data);
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    return avatarUrl;
  }
}
