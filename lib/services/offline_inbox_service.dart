import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat.dart' as app_chat;
import '../models/shared_draft.dart';
import '../models/user.dart' as app_user;
import '../models/user_count_fields.dart';
import '../utils/avatar_url_resolver.dart';
import 'logging_service.dart';

class OfflineInboxService {
  static final OfflineInboxService _instance = OfflineInboxService._internal();
  factory OfflineInboxService() => _instance;
  OfflineInboxService._internal();

  static const String _chatsKey = 'cached_chats';
  static const String _draftsKey = 'cached_drafts';
  static const String _usersKey = 'cached_users';
  static const String _unreadCountsKey = 'cached_unread_counts';
  static const String _onlineStatusKey = 'cached_online_status';
  static const String _lastSyncKey = 'last_sync_time';

  /// Cache chats offline
  Future<void> cacheChats(List<app_chat.Chat> chats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatsJson = chats.map((chat) => {
        'id': chat.id,
        'participants': chat.participants,
        'lastMessage': chat.lastMessage,
        'lastTimestamp': chat.lastTimestamp.toIso8601String(),
        'chatType': chat.chatType,
      }).toList();
      
      await prefs.setString(_chatsKey, jsonEncode(chatsJson));
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      
      LoggingService.instance.info('Cached ${chats.length} chats offline');
    } catch (e) {
      LoggingService.instance.error('Error caching chats: $e');
    }
  }

  /// Cache drafts offline
  Future<void> cacheDrafts(List<SharedDraft> drafts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftsJson = drafts.map((draft) => {
        'id': draft.id,
        'draftId': draft.draftId,
        'senderId': draft.senderId,
        'receiverId': draft.receiverId,
        'senderName': draft.senderName,
        'senderAvatar': draft.senderAvatar,
        'draftTitle': draft.draftTitle,
        'draftThumbnailUrl': draft.draftThumbnailUrl,
        'draftDuration': draft.draftDuration,
        'message': draft.message,
        'status': draft.status.name,
        'sharedAt': draft.sharedAt.toIso8601String(),
        'viewedAt': draft.viewedAt?.toIso8601String(),
      }).toList();
      
      await prefs.setString(_draftsKey, jsonEncode(draftsJson));
      
      LoggingService.instance.info('Cached ${drafts.length} drafts offline');
    } catch (e) {
      LoggingService.instance.error('Error caching drafts: $e');
    }
  }

  /// Cache user profiles offline
  Future<void> cacheUserProfiles(Map<String, app_user.User> userProfiles) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = userProfiles.map((userId, user) => MapEntry(userId, {
        'id': user.id,
        'displayName': user.displayName,
        'username': user.username,
        'bio': user.bio,
        'avatarURL': user.avatarURL,
        'onlineStatus': user.onlineStatus,
        'hashtags': user.hashtags,
        'aiSelf': user.aiSelf,
        'postCount': user.postCount,
        'followerCount': user.followerCount,
        'followingCount': user.followingCount,
      }));
      
      await prefs.setString(_usersKey, jsonEncode(usersJson));
      
      LoggingService.instance.info('Cached ${userProfiles.length} user profiles offline');
    } catch (e) {
      LoggingService.instance.error('Error caching user profiles: $e');
    }
  }

  /// Cache unread counts offline
  Future<void> cacheUnreadCounts(Map<String, int> unreadCounts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_unreadCountsKey, jsonEncode(unreadCounts));
      
      LoggingService.instance.info('Cached unread counts offline');
    } catch (e) {
      LoggingService.instance.error('Error caching unread counts: $e');
    }
  }

  /// Cache online status offline
  Future<void> cacheOnlineStatus(Map<String, bool> onlineStatus) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_onlineStatusKey, jsonEncode(onlineStatus));
      
      LoggingService.instance.info('Cached online status offline');
    } catch (e) {
      LoggingService.instance.error('Error caching online status: $e');
    }
  }

  /// Get cached chats
  Future<List<app_chat.Chat>> getCachedChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatsJsonString = prefs.getString(_chatsKey);
      
      if (chatsJsonString == null) return [];
      
      final List<dynamic> chatsJson = jsonDecode(chatsJsonString);
      return chatsJson.map((json) => app_chat.Chat(
        id: json['id'],
        participants: List<String>.from(json['participants']),
        lastMessage: json['lastMessage'],
        lastTimestamp: DateTime.parse(json['lastTimestamp']),
        chatType: json['chatType'],
      )).toList();
    } catch (e) {
      LoggingService.instance.error('Error getting cached chats: $e');
      return [];
    }
  }

  /// Get cached drafts
  Future<List<SharedDraft>> getCachedDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftsJsonString = prefs.getString(_draftsKey);
      
      if (draftsJsonString == null) return [];
      
      final List<dynamic> draftsJson = jsonDecode(draftsJsonString);
      return draftsJson.map((json) => SharedDraft(
        id: json['id'],
        draftId: json['draftId'],
        senderId: json['senderId'],
        receiverId: json['receiverId'],
        senderName: json['senderName'],
        senderAvatar: json['senderAvatar'],
        draftTitle: json['draftTitle'],
        draftThumbnailUrl: json['draftThumbnailUrl'],
        draftDuration: json['draftDuration'],
        message: json['message'],
        status: SharedDraftStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => SharedDraftStatus.pending,
        ),
        sharedAt: DateTime.parse(json['sharedAt']),
        viewedAt: json['viewedAt'] != null ? DateTime.parse(json['viewedAt']) : null,
      )).toList();
    } catch (e) {
      LoggingService.instance.error('Error getting cached drafts: $e');
      return [];
    }
  }

  /// Get cached user profiles
  Future<Map<String, app_user.User>> getCachedUserProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJsonString = prefs.getString(_usersKey);
      
      if (usersJsonString == null) return {};
      
      final Map<String, dynamic> usersJson = jsonDecode(usersJsonString);
      return usersJson.map((userId, userData) => MapEntry(userId, app_user.User(
        id: userData['id'],
        displayName: userData['displayName'],
        username: userData['username'],
        bio: userData['bio'],
        avatarURL: resolveAvatarUrl(Map<String, dynamic>.from(userData)),
        onlineStatus: userData['onlineStatus'],
        hashtags: List<String>.from(userData['hashtags']),
        aiSelf: userData['aiSelf'],
        postCount: userData['postCount'],
        followerCount: UserCountFields.readFollowersCount(userData),
        followingCount: UserCountFields.readFollowingCount(userData),
      )));
    } catch (e) {
      LoggingService.instance.error('Error getting cached user profiles: $e');
      return {};
    }
  }

  /// Get cached unread counts
  Future<Map<String, int>> getCachedUnreadCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unreadCountsJsonString = prefs.getString(_unreadCountsKey);
      
      if (unreadCountsJsonString == null) return {};
      
      final Map<String, dynamic> unreadCountsJson = jsonDecode(unreadCountsJsonString);
      return unreadCountsJson.map((key, value) => MapEntry(key, value as int));
    } catch (e) {
      LoggingService.instance.error('Error getting cached unread counts: $e');
      return {};
    }
  }

  /// Get cached online status
  Future<Map<String, bool>> getCachedOnlineStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final onlineStatusJsonString = prefs.getString(_onlineStatusKey);
      
      if (onlineStatusJsonString == null) return {};
      
      final Map<String, dynamic> onlineStatusJson = jsonDecode(onlineStatusJsonString);
      return onlineStatusJson.map((key, value) => MapEntry(key, value as bool));
    } catch (e) {
      LoggingService.instance.error('Error getting cached online status: $e');
      return {};
    }
  }

  /// Check if data is stale (older than 1 hour)
  Future<bool> isDataStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncString = prefs.getString(_lastSyncKey);
      
      if (lastSyncString == null) return true;
      
      final lastSync = DateTime.parse(lastSyncString);
      final now = DateTime.now();
      final difference = now.difference(lastSync);
      
      return difference.inHours >= 1;
    } catch (e) {
      LoggingService.instance.error('Error checking data staleness: $e');
      return true;
    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chatsKey);
      await prefs.remove(_draftsKey);
      await prefs.remove(_usersKey);
      await prefs.remove(_unreadCountsKey);
      await prefs.remove(_onlineStatusKey);
      await prefs.remove(_lastSyncKey);
      
      LoggingService.instance.info('Cleared all offline cache');
    } catch (e) {
      LoggingService.instance.error('Error clearing cache: $e');
    }
  }
}
