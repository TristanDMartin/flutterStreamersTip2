import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/chat.dart' as app_chat;
import '../models/shared_draft.dart';
import '../models/user.dart' as app_user;
import '../models/user_count_fields.dart';
import '../utils/avatar_url_resolver.dart';
import 'logging_service.dart';
import 'public_profile_firestore.dart';

class InboxServiceOptimized {
  static final InboxServiceOptimized _instance =
      InboxServiceOptimized._internal();
  factory InboxServiceOptimized() => _instance;
  InboxServiceOptimized._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  // Expose auth for external access
  firebase_auth.FirebaseAuth get auth => _auth;

  // Cache for better performance
  final Map<String, app_chat.Chat> _chatCache = {};
  final Map<String, SharedDraft> _draftCache = {};
  final Map<String, app_user.User> _userCache = {};
  final Map<String, int> _unreadCounts = {};

  // Real-time listeners
  StreamSubscription<List<app_chat.Chat>>? _chatsSubscription;
  StreamSubscription<List<SharedDraft>>? _draftsSubscription;

  /// Get user's chats
  Future<List<app_chat.Chat>> getChats() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    try {
      final query = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .orderBy('lastTimestamp', descending: true)
          .get();

      final chats = <app_chat.Chat>[];
      for (final doc in query.docs) {
        final chat = _mapChat(doc.id, doc.data());
        _chatCache[doc.id] = chat;
        chats.add(chat);
      }

      return chats;
    } catch (e) {
      LoggingService.instance.error('Error getting chats: $e');
      return [];
    }
  }

  /// Get user's shared drafts
  Future<List<SharedDraft>> getSharedDrafts() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    try {
      // Get drafts shared with me (I'm in recipients array)
      final receivedQuery = await _firestore
          .collection('shared_drafts')
          .where('recipients', arrayContains: currentUser.uid)
          .where('status', isEqualTo: 'shared')
          .orderBy('createdAt', descending: true)
          .get();

      // Get drafts shared by me (I'm the sharer)
      final sentQuery = await _firestore
          .collection('shared_drafts')
          .where('sharerId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'shared')
          .orderBy('createdAt', descending: true)
          .get();

      final drafts = <SharedDraft>[];

      // Process received drafts
      for (final doc in receivedQuery.docs) {
        final data = doc.data();
        // Convert to SharedDraft format (using first recipient as receiverId for compatibility)
        final recipients = List<String>.from(data['recipients'] ?? []);
        if (recipients.isNotEmpty) {
          final draftData = {
            ...data,
            'receiverId': currentUser.uid,
            'senderId': data['sharerId'],
            'draftId': data['originalDraftId'] ?? doc.id,
          };
          final draft = _mapSharedDraft(doc.id, draftData);
          _draftCache[doc.id] = draft;
          drafts.add(draft);
        }
      }

      // Process sent drafts
      for (final doc in sentQuery.docs) {
        final data = doc.data();
        final recipients = List<String>.from(data['recipients'] ?? []);
        // Create a SharedDraft for each recipient
        for (final recipientId in recipients) {
          final draftData = {
            ...data,
            'receiverId': recipientId,
            'senderId': currentUser.uid,
            'draftId': data['originalDraftId'] ?? doc.id,
          };
          final draftId = '${doc.id}_$recipientId';
          if (!_draftCache.containsKey(draftId)) {
            final draft = _mapSharedDraft(draftId, draftData);
            _draftCache[draftId] = draft;
            drafts.add(draft);
          }
        }
      }

      // Sort by creation time
      drafts.sort((a, b) => b.sharedAt.compareTo(a.sharedAt));

      return drafts;
    } catch (e) {
      LoggingService.instance.error('Error getting shared drafts: $e');
      return [];
    }
  }

  /// Search chats
  Future<List<app_chat.Chat>> searchChats(String query) async {
    if (query.isEmpty) return getChats();

    try {
      final chats = await getChats();
      return chats.where((chat) {
        final lastMessage = chat.lastMessage?.toLowerCase() ?? '';
        final participants = chat.participants.join(' ').toLowerCase();
        final searchQuery = query.toLowerCase();

        return lastMessage.contains(searchQuery) ||
            participants.contains(searchQuery);
      }).toList();
    } catch (e) {
      LoggingService.instance.error('Error searching chats: $e');
      return [];
    }
  }

  /// Search shared drafts
  Future<List<SharedDraft>> searchSharedDrafts(String query) async {
    if (query.isEmpty) return getSharedDrafts();

    try {
      final drafts = await getSharedDrafts();
      return drafts.where((draft) {
        final title = draft.draftTitle.toLowerCase();
        final message = draft.message?.toLowerCase() ?? '';
        final searchQuery = query.toLowerCase();

        return title.contains(searchQuery) || message.contains(searchQuery);
      }).toList();
    } catch (e) {
      LoggingService.instance.error('Error searching shared drafts: $e');
      return [];
    }
  }

  /// Get user profile by ID (publicUsers; own private doc only for self)
  Future<app_user.User?> getUserProfile(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    try {
      final Map<String, dynamic>? data =
          await PublicProfileFirestore.instance.getProfileMap(userId);
      if (data == null) {
        return null;
      }
      final user = _mapUser(userId, data);
      _userCache[userId] = user;
      return user;
    } catch (e) {
      LoggingService.instance.error('Error getting user profile: $e');
      return null;
    }
  }

  /// Cached unread count populated when chat docs are mapped from streams.
  int cachedUnreadCount(String chatId) => _unreadCounts[chatId] ?? 0;

  /// Snapshot of all cached unread counts (for inbox list sync).
  Map<String, int> snapshotUnreadCounts() =>
      Map<String, int>.from(_unreadCounts);

  /// Get unread message count for a chat
  Future<int> getUnreadCount(String chatId) async {
    if (_unreadCounts.containsKey(chatId)) {
      return _unreadCounts[chatId]!;
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) return 0;

    try {
      final query = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUser.uid)
          .get();

      final unreadCount = query.docs.where((doc) {
        final readBy = List<String>.from(doc.data()['readBy'] ?? const []);
        return !readBy.contains(currentUser.uid);
      }).length;
      _unreadCounts[chatId] = unreadCount;
      return unreadCount;
    } catch (e) {
      LoggingService.instance.error('Error getting unread count: $e');
      return 0;
    }
  }

  /// Mark messages as read
  Future<void> markAsRead(String chatId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Get all messages in this chat where current user is recipient but not in readBy
      final query = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('recipients', arrayContains: currentUser.uid)
          .get();

      final batch = _firestore.batch();
      var hasUpdates = false;
      for (final doc in query.docs) {
        final messageData = doc.data();
        final readBy = List<String>.from(messageData['readBy'] ?? []);

        // Only update if user is not already in readBy
        if (!readBy.contains(currentUser.uid)) {
          batch.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([currentUser.uid]),
            'isRead': true,
          });
          hasUpdates = true;
        }
      }

      batch.set(
        _firestore.collection('chats').doc(chatId),
        {
          'unreadCount_${currentUser.uid}': 0,
          'lastReadTimestamp': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (hasUpdates || _chatCache.containsKey(chatId)) {
        await batch.commit();
      }
      _unreadCounts[chatId] = 0;
    } catch (e) {
      LoggingService.instance.error('Error marking as read: $e');
    }
  }

  Future<void> markSharedDraftViewed(String sharedDraftId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore.collection('shared_drafts').doc(sharedDraftId).update({
        'viewedBy': FieldValue.arrayUnion([currentUser.uid]),
        'viewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      LoggingService.instance.error('Error marking shared draft viewed: $e');
    }
  }

  /// Get online status for a user (public profile fields when available)
  Future<bool> isUserOnline(String userId) async {
    try {
      final Map<String, dynamic>? data =
          await PublicProfileFirestore.instance.getProfileMap(userId);
      if (data == null) {
        return false;
      }
      final lastSeen = data['lastSeen'];
      if (lastSeen is Timestamp) {
        final now = Timestamp.now();
        final difference = now.seconds - lastSeen.seconds;
        return difference < 300;
      }
      return (data['onlineStatus'] ?? 'offline') == 'online';
    } catch (e) {
      LoggingService.instance.error('Error checking online status: $e');
      return false;
    }
  }

  /// Delete a chat
  Future<bool> deleteChat(String chatId) async {
    try {
      await _firestore.collection('chats').doc(chatId).delete();
      _chatCache.remove(chatId);
      return true;
    } catch (e) {
      LoggingService.instance.error('Error deleting chat: $e');
      return false;
    }
  }

  /// Delete multiple chats
  Future<bool> deleteMultipleChats(List<String> chatIds) async {
    try {
      final batch = _firestore.batch();

      for (final chatId in chatIds) {
        batch.delete(_firestore.collection('chats').doc(chatId));
        _chatCache.remove(chatId);
      }

      await batch.commit();
      return true;
    } catch (e) {
      LoggingService.instance.error('Error deleting multiple chats: $e');
      return false;
    }
  }

  /// Delete a shared draft
  Future<bool> deleteSharedDraft(String draftId) async {
    try {
      await _firestore.collection('shared_drafts').doc(draftId).delete();
      _draftCache.remove(draftId);
      return true;
    } catch (e) {
      LoggingService.instance.error('Error deleting shared draft: $e');
      return false;
    }
  }

  /// Mark chat as read
  Future<bool> markChatAsRead(String chatId) async {
    try {
      await markAsRead(chatId);

      // Update cache
      if (_chatCache.containsKey(chatId)) {
        final chat = _chatCache[chatId]!;
        _chatCache[chatId] = chat;
      }

      return true;
    } catch (e) {
      LoggingService.instance.error('Error marking chat as read: $e');
      return false;
    }
  }

  /// Mark all chats as read
  Future<bool> markAllChatsAsRead() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final query = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {
          'unreadCount': 0,
          'lastReadTimestamp': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Update cache
      for (final chatId in _chatCache.keys) {
        final chat = _chatCache[chatId]!;
        _chatCache[chatId] = chat;
      }

      return true;
    } catch (e) {
      LoggingService.instance.error('Error marking all chats as read: $e');
      return false;
    }
  }

  /// Create a new chat
  Future<app_chat.Chat?> createChat(String otherUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    try {
      // Check if chat already exists
      final existingQuery = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      for (final doc in existingQuery.docs) {
        final participants =
            List<String>.from(doc.data()['participants'] ?? []);
        if (participants.contains(otherUserId)) {
          return _mapChat(doc.id, doc.data());
        }
      }

      // Create new chat
      final data = {
        'participants': [currentUser.uid, otherUserId],
        'lastMessage': '',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'chatType': 'direct',
        'unreadCount': 0,
      };

      final docRef = await _firestore.collection('chats').add(data);
      final snapshot = await docRef.get();

      if (snapshot.exists) {
        final chat = _mapChat(docRef.id, snapshot.data()!);
        _chatCache[docRef.id] = chat;
        return chat;
      }

      return null;
    } catch (e) {
      LoggingService.instance.error('Error creating chat: $e');
      return null;
    }
  }

  /// Map Firestore document to Chat model
  app_chat.Chat _mapChat(String id, Map<String, dynamic> data) {
    final currentUser = _auth.currentUser;
    // Extract unread count for current user from chat document
    // Cloud Functions stores it as unreadCount_{userId}
    int unreadCount = 0;
    if (currentUser != null) {
      final unreadField = 'unreadCount_${currentUser.uid}';
      final dynamic unreadValue = data[unreadField];
      if (unreadValue != null) {
        unreadCount =
            unreadValue is int ? unreadValue : (unreadValue as num).toInt();
      }
      // Cache the unread count
      _unreadCounts[id] = unreadCount;
    }

    return app_chat.Chat(
      id: id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastTimestamp:
          (data['lastTimestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      chatType: data['chatType'] ?? 'direct',
    );
  }

  /// Map Firestore document to SharedDraft model
  SharedDraft _mapSharedDraft(String id, Map<String, dynamic> data) {
    final currentUser = _auth.currentUser;
    final currentUserId = currentUser?.uid ?? '';
    // Handle both old format (receiverId) and new format (sharerId/recipients)
    final senderId = data['senderId'] ?? data['sharerId'] ?? '';
    final senderName = data['senderName'] ?? data['sharerUsername'] ?? '';
    final senderAvatar = data['senderAvatar'] ?? data['sharerAvatarUrl'] ?? '';
    final receiverId = data['receiverId'] ?? '';
    final draftId = data['draftId'] ?? data['originalDraftId'] ?? '';
    final caption = data['caption'] ?? '';
    final draftTitle =
        ((data['draftTitle'] as String?)?.trim().isNotEmpty == true)
            ? data['draftTitle'] as String
            : (caption.isNotEmpty ? caption : 'Draft');
    final draftThumbnailUrl = data['draftThumbnailUrl'] ??
        data['thumbnailUrl'] ??
        data['thumbnailPath'] ??
        '';
    final draftDuration =
        data['draftDuration'] ?? (data['metadata']?['duration'] ?? 0);
    final sharedAt = (data['sharedAt'] as Timestamp?)?.toDate() ??
        (data['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.now();
    final status = _deriveSharedDraftStatus(
      data: data,
      currentUserId: currentUserId,
      receiverId: receiverId,
    );

    return SharedDraft(
      id: id,
      draftId: draftId,
      senderId: senderId,
      receiverId: receiverId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      draftTitle: draftTitle,
      draftThumbnailUrl: draftThumbnailUrl,
      draftDuration:
          draftDuration is int ? draftDuration : (draftDuration as num).toInt(),
      sharedAt: sharedAt,
      status: status,
      message: data['message'],
      viewedAt: (data['viewedAt'] as Timestamp?)?.toDate(),
    );
  }

  SharedDraftStatus _deriveSharedDraftStatus({
    required Map<String, dynamic> data,
    required String currentUserId,
    required String receiverId,
  }) {
    final declinedBy =
        List<String>.from(data['declinedBy'] as List<dynamic>? ?? const []);
    final acceptedBy =
        List<String>.from(data['acceptedBy'] as List<dynamic>? ?? const []);
    final viewedBy =
        List<String>.from(data['viewedBy'] as List<dynamic>? ?? const []);
    final targetUserId =
        currentUserId == receiverId ? currentUserId : receiverId;

    if (declinedBy.contains(targetUserId)) {
      return SharedDraftStatus.declined;
    }
    if (viewedBy.contains(targetUserId) || data['viewedAt'] != null) {
      return SharedDraftStatus.viewed;
    }
    if (acceptedBy.contains(targetUserId)) {
      return SharedDraftStatus.delivered;
    }
    return SharedDraftStatus.pending;
  }

  /// Map Firestore document to User model
  app_user.User _mapUser(String id, Map<String, dynamic> data) {
    return app_user.User(
      id: id,
      displayName: data['displayName'] ?? 'User',
      username: data['username'] ?? 'user',
      bio: data['bio'],
      avatarURL: resolveAvatarUrl(data),
      onlineStatus: data['onlineStatus'] ?? 'offline',
      hashtags:
          data['hashtags'] is List ? List<String>.from(data['hashtags']) : [],
      aiSelf: data['aiSelf'] ?? '',
      postCount: data['postCount'] ?? 0,
      followerCount: UserCountFields.readFollowersCount(data),
      followingCount: UserCountFields.readFollowingCount(data),
      calendarEvents: [],
    );
  }

  /// Stream chats in real-time
  Stream<List<app_chat.Chat>> streamChats() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('lastTimestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      final chats = <app_chat.Chat>[];
      for (final doc in snapshot.docs) {
        final chat = _mapChat(doc.id, doc.data());
        _chatCache[doc.id] = chat;
        chats.add(chat);
      }
      return chats;
    });
  }

  /// Stream shared drafts in real-time
  Stream<List<SharedDraft>> streamSharedDrafts() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    late final StreamController<List<SharedDraft>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? receivedSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sentSub;

    Future<void> emitDrafts() async {
      try {
        if (controller.isClosed) return;
        controller.add(await getSharedDrafts());
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    controller = StreamController<List<SharedDraft>>.broadcast(
      onListen: () {
        emitDrafts();

        receivedSub = _firestore
            .collection('shared_drafts')
            .where('recipients', arrayContains: currentUser.uid)
            .where('status', isEqualTo: 'shared')
            .snapshots()
            .listen(
              (_) => emitDrafts(),
              onError: controller.addError,
            );

        sentSub = _firestore
            .collection('shared_drafts')
            .where('sharerId', isEqualTo: currentUser.uid)
            .where('status', isEqualTo: 'shared')
            .snapshots()
            .listen(
              (_) => emitDrafts(),
              onError: controller.addError,
            );
      },
      onCancel: () async {
        await receivedSub?.cancel();
        await sentSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Stream unread count for a specific chat
  Stream<int> streamUnreadCount(String chatId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value(0);

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .snapshots()
        .map((snapshot) {
      final count = snapshot.docs.where((doc) {
        final readBy = List<String>.from(doc.data()['readBy'] ?? const []);
        final from = doc.data()['from'] as String? ?? '';
        return from != currentUser.uid && !readBy.contains(currentUser.uid);
      }).length;
      _unreadCounts[chatId] = count;
      return count;
    });
  }

  /// Stream online status for a user
  Stream<bool> streamUserOnlineStatus(String userId) {
    return PublicProfileFirestore.instance.watchProfile(userId).map((doc) {
      if (doc.exists) {
        final data = doc.data()!;
        final lastSeen = data['lastSeen'];
        if (lastSeen is Timestamp) {
          final now = Timestamp.now();
          final difference = now.seconds - lastSeen.seconds;
          return difference < 300;
        }
        return (data['onlineStatus'] ?? 'offline') == 'online';
      }
      return false;
    });
  }

  /// Start real-time listeners
  void startRealTimeListeners({
    required Function(List<app_chat.Chat>) onChatsUpdate,
    required Function(List<SharedDraft>) onDraftsUpdate,
  }) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Listen to chats
    _chatsSubscription = streamChats().listen(
      onChatsUpdate,
      onError: (error) {
        LoggingService.instance.error('Error in chats stream: $error');
      },
    );

    // Listen to drafts
    _draftsSubscription = streamSharedDrafts().listen(
      onDraftsUpdate,
      onError: (error) {
        LoggingService.instance.error('Error in drafts stream: $error');
      },
    );
  }

  /// Stop real-time listeners
  void stopRealTimeListeners() {
    _chatsSubscription?.cancel();
    _draftsSubscription?.cancel();
    _chatsSubscription = null;
    _draftsSubscription = null;
  }

  /// Clear cache
  void clearCache() {
    _chatCache.clear();
    _draftCache.clear();
    _userCache.clear();
    _unreadCounts.clear();
  }

  /// Dispose resources
  void dispose() {
    stopRealTimeListeners();
    clearCache();
  }
}
