import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat.dart' as app_chat;
import '../models/shared_draft.dart';
import '../models/user.dart' as app_user;
import '../models/user_count_fields.dart';
import '../utils/avatar_url_resolver.dart';
import 'logging_service.dart';

class InboxOfflineSnapshot {
  const InboxOfflineSnapshot({
    required this.chats,
    required this.drafts,
    required this.userProfiles,
    required this.unreadCounts,
    required this.onlineStatus,
  });

  final List<app_chat.Chat> chats;
  final List<SharedDraft> drafts;
  final Map<String, app_user.User> userProfiles;
  final Map<String, int> unreadCounts;
  final Map<String, bool> onlineStatus;

  bool get hasChats => chats.isNotEmpty;
}

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

  InboxOfflineSnapshot? _memorySnapshot;
  String? _memoryUserId;

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  String _scopedKey(String base, String? userId) {
    if (userId == null || userId.isEmpty) {
      return base;
    }
    return '${base}_$userId';
  }

  /// Instant in-session peek for Inbox paint.
  InboxOfflineSnapshot? peekMemory({String? userId}) {
    final String? uid = userId ?? _currentUserId;
    if (uid == null ||
        uid.isEmpty ||
        _memorySnapshot == null ||
        _memoryUserId != uid) {
      return null;
    }
    return _memorySnapshot;
  }

  void _rememberSnapshot({
    required String userId,
    List<app_chat.Chat>? chats,
    List<SharedDraft>? drafts,
    Map<String, app_user.User>? userProfiles,
    Map<String, int>? unreadCounts,
    Map<String, bool>? onlineStatus,
  }) {
    final InboxOfflineSnapshot previous =
        (_memoryUserId == userId ? _memorySnapshot : null) ??
            const InboxOfflineSnapshot(
              chats: <app_chat.Chat>[],
              drafts: <SharedDraft>[],
              userProfiles: <String, app_user.User>{},
              unreadCounts: <String, int>{},
              onlineStatus: <String, bool>{},
            );
    _memoryUserId = userId;
    _memorySnapshot = InboxOfflineSnapshot(
      chats: chats ?? previous.chats,
      drafts: drafts ?? previous.drafts,
      userProfiles: userProfiles ?? previous.userProfiles,
      unreadCounts: unreadCounts ?? previous.unreadCounts,
      onlineStatus: onlineStatus ?? previous.onlineStatus,
    );
  }

  /// Cache chats offline
  Future<void> cacheChats(List<app_chat.Chat> chats) async {
    try {
      final String? userId = _currentUserId;
      if (userId != null) {
        _rememberSnapshot(userId: userId, chats: chats);
      }
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> chatsJson = chats
          .map(
            (app_chat.Chat chat) => <String, dynamic>{
              'id': chat.id,
              'participants': chat.participants,
              'lastMessage': chat.lastMessage,
              'lastTimestamp': chat.lastTimestamp.toIso8601String(),
              'chatType': chat.chatType,
            },
          )
          .toList();

      await prefs.setString(
        _scopedKey(_chatsKey, userId),
        jsonEncode(chatsJson),
      );
      await prefs.setString(
        _scopedKey(_lastSyncKey, userId),
        DateTime.now().toIso8601String(),
      );

      LoggingService.instance.info('Cached ${chats.length} chats offline');
    } catch (e) {
      LoggingService.instance.error('Error caching chats: $e');
    }
  }

  /// Cache drafts offline
  Future<void> cacheDrafts(List<SharedDraft> drafts) async {
    try {
      final String? userId = _currentUserId;
      if (userId != null) {
        _rememberSnapshot(userId: userId, drafts: drafts);
      }
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> draftsJson = drafts
          .map(
            (SharedDraft draft) => <String, dynamic>{
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
            },
          )
          .toList();

      await prefs.setString(
        _scopedKey(_draftsKey, userId),
        jsonEncode(draftsJson),
      );

      LoggingService.instance.info('Cached ${drafts.length} drafts offline');
    } catch (e) {
      LoggingService.instance.error('Error caching drafts: $e');
    }
  }

  /// Cache user profiles offline
  Future<void> cacheUserProfiles(
    Map<String, app_user.User> userProfiles,
  ) async {
    try {
      final String? userId = _currentUserId;
      if (userId != null) {
        _rememberSnapshot(userId: userId, userProfiles: userProfiles);
      }
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Map<String, Map<String, dynamic>> usersJson = userProfiles.map(
        (String profileUserId, app_user.User user) => MapEntry(
          profileUserId,
          <String, dynamic>{
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
          },
        ),
      );

      await prefs.setString(
        _scopedKey(_usersKey, userId),
        jsonEncode(usersJson),
      );

      LoggingService.instance
          .info('Cached ${userProfiles.length} user profiles offline');
    } catch (e) {
      LoggingService.instance.error('Error caching user profiles: $e');
    }
  }

  /// Cache unread counts offline
  Future<void> cacheUnreadCounts(Map<String, int> unreadCounts) async {
    try {
      final String? userId = _currentUserId;
      if (userId != null) {
        _rememberSnapshot(userId: userId, unreadCounts: unreadCounts);
      }
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _scopedKey(_unreadCountsKey, userId),
        jsonEncode(unreadCounts),
      );

      LoggingService.instance.info('Cached unread counts offline');
    } catch (e) {
      LoggingService.instance.error('Error caching unread counts: $e');
    }
  }

  /// Cache online status offline
  Future<void> cacheOnlineStatus(Map<String, bool> onlineStatus) async {
    try {
      final String? userId = _currentUserId;
      if (userId != null) {
        _rememberSnapshot(userId: userId, onlineStatus: onlineStatus);
      }
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _scopedKey(_onlineStatusKey, userId),
        jsonEncode(onlineStatus),
      );

      LoggingService.instance.info('Cached online status offline');
    } catch (e) {
      LoggingService.instance.error('Error caching online status: $e');
    }
  }

  Future<String?> _readScopedOrLegacy(
    SharedPreferences prefs,
    String base,
    String? userId,
  ) async {
    final String scoped = prefs.getString(_scopedKey(base, userId)) ?? '';
    if (scoped.isNotEmpty) {
      return scoped;
    }
    return prefs.getString(base);
  }

  /// Full snapshot for instant Inbox hydrate (always prefers cache over empty).
  Future<InboxOfflineSnapshot> loadSnapshot({String? userId}) async {
    final String? uid = userId ?? _currentUserId;
    final InboxOfflineSnapshot? memory = peekMemory(userId: uid);
    if (memory != null && memory.hasChats) {
      return memory;
    }
    final List<app_chat.Chat> chats = await getCachedChats(userId: uid);
    final List<SharedDraft> drafts = await getCachedDrafts(userId: uid);
    final Map<String, app_user.User> users =
        await getCachedUserProfiles(userId: uid);
    final Map<String, int> unread =
        await getCachedUnreadCounts(userId: uid);
    final Map<String, bool> online =
        await getCachedOnlineStatus(userId: uid);
    final InboxOfflineSnapshot snapshot = InboxOfflineSnapshot(
      chats: chats,
      drafts: drafts,
      userProfiles: users,
      unreadCounts: unread,
      onlineStatus: online,
    );
    if (uid != null && snapshot.hasChats) {
      _rememberSnapshot(
        userId: uid,
        chats: chats,
        drafts: drafts,
        userProfiles: users,
        unreadCounts: unread,
        onlineStatus: online,
      );
    }
    return snapshot;
  }

  /// Get cached chats
  Future<List<app_chat.Chat>> getCachedChats({String? userId}) async {
    try {
      final String? uid = userId ?? _currentUserId;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? chatsJsonString =
          await _readScopedOrLegacy(prefs, _chatsKey, uid);

      if (chatsJsonString == null) {
        return <app_chat.Chat>[];
      }

      final List<dynamic> chatsJson = jsonDecode(chatsJsonString) as List<dynamic>;
      return chatsJson
          .map(
            (dynamic json) => app_chat.Chat(
              id: json['id'] as String?,
              participants: List<String>.from(json['participants'] as List),
              lastMessage: json['lastMessage'] as String?,
              lastTimestamp: DateTime.parse(json['lastTimestamp'] as String),
              chatType: json['chatType'] as String?,
            ),
          )
          .toList();
    } catch (e) {
      LoggingService.instance.error('Error getting cached chats: $e');
      return <app_chat.Chat>[];
    }
  }

  /// Get cached drafts
  Future<List<SharedDraft>> getCachedDrafts({String? userId}) async {
    try {
      final String? uid = userId ?? _currentUserId;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? draftsJsonString =
          await _readScopedOrLegacy(prefs, _draftsKey, uid);

      if (draftsJsonString == null) {
        return <SharedDraft>[];
      }

      final List<dynamic> draftsJson =
          jsonDecode(draftsJsonString) as List<dynamic>;
      return draftsJson
          .map(
            (dynamic json) => SharedDraft(
              id: (json['id'] as String?) ?? '',
              draftId: (json['draftId'] as String?) ?? '',
              senderId: (json['senderId'] as String?) ?? '',
              receiverId: (json['receiverId'] as String?) ?? '',
              senderName: (json['senderName'] as String?) ?? '',
              senderAvatar: (json['senderAvatar'] as String?) ?? '',
              draftTitle: (json['draftTitle'] as String?) ?? '',
              draftThumbnailUrl: (json['draftThumbnailUrl'] as String?) ?? '',
              draftDuration: (json['draftDuration'] as num?)?.toInt() ?? 0,
              message: json['message'] as String?,
              status: SharedDraftStatus.values.firstWhere(
                (SharedDraftStatus e) => e.name == json['status'],
                orElse: () => SharedDraftStatus.pending,
              ),
              sharedAt: DateTime.parse(json['sharedAt'] as String),
              viewedAt: json['viewedAt'] != null
                  ? DateTime.parse(json['viewedAt'] as String)
                  : null,
            ),
          )
          .toList();
    } catch (e) {
      LoggingService.instance.error('Error getting cached drafts: $e');
      return <SharedDraft>[];
    }
  }

  /// Get cached user profiles
  Future<Map<String, app_user.User>> getCachedUserProfiles({
    String? userId,
  }) async {
    try {
      final String? uid = userId ?? _currentUserId;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? usersJsonString =
          await _readScopedOrLegacy(prefs, _usersKey, uid);

      if (usersJsonString == null) {
        return <String, app_user.User>{};
      }

      final Map<String, dynamic> usersJson =
          jsonDecode(usersJsonString) as Map<String, dynamic>;
      return usersJson.map(
        (String profileUserId, dynamic userData) => MapEntry(
          profileUserId,
          app_user.User(
            id: userData['id'] as String,
            displayName: userData['displayName'] as String,
            username: userData['username'] as String,
            bio: userData['bio'] as String?,
            avatarURL: resolveAvatarUrl(
              Map<String, dynamic>.from(userData as Map),
            ),
            onlineStatus: userData['onlineStatus'] as String? ?? 'offline',
            hashtags: List<String>.from(
              (userData['hashtags'] as List?) ?? <dynamic>[],
            ),
            aiSelf: userData['aiSelf'] as String? ?? '',
            postCount: (userData['postCount'] as num?)?.toInt() ?? 0,
            followerCount: UserCountFields.readFollowersCount(
              Map<String, dynamic>.from(userData),
            ),
            followingCount: UserCountFields.readFollowingCount(
              Map<String, dynamic>.from(userData),
            ),
          ),
        ),
      );
    } catch (e) {
      LoggingService.instance.error('Error getting cached user profiles: $e');
      return <String, app_user.User>{};
    }
  }

  /// Get cached unread counts
  Future<Map<String, int>> getCachedUnreadCounts({String? userId}) async {
    try {
      final String? uid = userId ?? _currentUserId;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? unreadCountsJsonString =
          await _readScopedOrLegacy(prefs, _unreadCountsKey, uid);

      if (unreadCountsJsonString == null) {
        return <String, int>{};
      }

      final Map<String, dynamic> unreadCountsJson =
          jsonDecode(unreadCountsJsonString) as Map<String, dynamic>;
      return unreadCountsJson.map(
        (String key, dynamic value) => MapEntry(key, (value as num).toInt()),
      );
    } catch (e) {
      LoggingService.instance.error('Error getting cached unread counts: $e');
      return <String, int>{};
    }
  }

  /// Get cached online status
  Future<Map<String, bool>> getCachedOnlineStatus({String? userId}) async {
    try {
      final String? uid = userId ?? _currentUserId;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? onlineStatusJsonString =
          await _readScopedOrLegacy(prefs, _onlineStatusKey, uid);

      if (onlineStatusJsonString == null) {
        return <String, bool>{};
      }

      final Map<String, dynamic> onlineStatusJson =
          jsonDecode(onlineStatusJsonString) as Map<String, dynamic>;
      return onlineStatusJson.map(
        (String key, dynamic value) => MapEntry(key, value as bool),
      );
    } catch (e) {
      LoggingService.instance.error('Error getting cached online status: $e');
      return <String, bool>{};
    }
  }

  /// Check if data is stale (older than 1 hour) — advisory only.
  Future<bool> isDataStale({String? userId}) async {
    try {
      final String? uid = userId ?? _currentUserId;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? lastSyncString =
          await _readScopedOrLegacy(prefs, _lastSyncKey, uid);

      if (lastSyncString == null) {
        return true;
      }

      final DateTime lastSync = DateTime.parse(lastSyncString);
      return DateTime.now().difference(lastSync).inHours >= 1;
    } catch (e) {
      LoggingService.instance.error('Error checking data staleness: $e');
      return true;
    }
  }

  /// Clear all cached data
  Future<void> clearCache({String? userId}) async {
    try {
      final String? uid = userId ?? _currentUserId;
      if (_memoryUserId == uid) {
        _memorySnapshot = null;
        _memoryUserId = null;
      }
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_scopedKey(_chatsKey, uid));
      await prefs.remove(_scopedKey(_draftsKey, uid));
      await prefs.remove(_scopedKey(_usersKey, uid));
      await prefs.remove(_scopedKey(_unreadCountsKey, uid));
      await prefs.remove(_scopedKey(_onlineStatusKey, uid));
      await prefs.remove(_scopedKey(_lastSyncKey, uid));
      // Legacy unscoped keys
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
