import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/chat.dart' as app_chat;
import '../models/message.dart' as app_message;
import '../features/gamification/emit_engagement_gamification.dart';
import '../features/gamification/gamification_event_types.dart';
import 'progression_service.dart';
import 'public_profile_firestore.dart';

class ChatServiceOptimized {
  static final ChatServiceOptimized _instance =
      ChatServiceOptimized._internal();
  factory ChatServiceOptimized() => _instance;
  ChatServiceOptimized._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  // Expose auth for external access
  firebase_auth.FirebaseAuth get auth => _auth;

  // Cache for better performance
  final Map<String, app_chat.Chat> _chatCache = {};
  final Map<String, List<app_message.Message>> _messagesCache = {};

  /// Get messages for a chat
  Future<List<app_message.Message>> getMessages(String chatId) async {
    try {
      final query = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      final messages = <app_message.Message>[];
      for (final doc in query.docs) {
        final message = _mapMessage(doc.id, doc.data());
        messages.add(message);
      }

      _messagesCache[chatId] = messages;
      return messages.reversed.toList(); // Return in chronological order
    } catch (e) {
      // appLog('Error getting messages: $e');
      return [];
    }
  }

  /// Send a message
  Future<bool> sendMessage(String chatId, String text) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final messageData = {
        'senderId': currentUser.uid,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
        'isRead': false,
      };

      // Add message to messages collection
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      // Update chat's last message
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': text,
        'lastTimestamp': FieldValue.serverTimestamp(),
      });
      scheduleEngagementGamificationEvent(
        type: GamificationEventTypes.communityMessageSent,
        entityType: 'chat',
        entityId: chatId,
        source: 'messages',
      );
      unawaited(ProgressionService.instance.markTaskCompleted(
        currentUser.uid,
        ProgressionTaskIds.firstMessageSent,
        source: 'messages',
      ));

      return true;
    } catch (e) {
      // appLog('Error sending message: $e');
      return false;
    }
  }

  /// Send a StreamersTip-native video preview card into an inbox chat.
  Future<bool> sendVideoShare({
    required String chatId,
    required String videoId,
    required String shareToken,
    required String previewText,
    String? thumbnailUrl,
    String? title,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final messageData = <String, dynamic>{
        'senderId': currentUser.uid,
        'from': currentUser.uid,
        'text': previewText,
        'previewText': previewText,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'video_share',
        'messageType': 'video_share',
        'isRead': false,
        'videoId': videoId,
        'shareToken': shareToken,
        if (thumbnailUrl != null && thumbnailUrl.trim().isNotEmpty)
          'thumbnailUrl': thumbnailUrl.trim(),
        if (thumbnailUrl != null && thumbnailUrl.trim().isNotEmpty)
          'videoThumbnailUrl': thumbnailUrl.trim(),
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        if (title != null && title.trim().isNotEmpty)
          'videoTitle': title.trim(),
      };

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': 'Shared a video',
        'lastTimestamp': FieldValue.serverTimestamp(),
      });
      unawaited(ProgressionService.instance.markTaskCompleted(
        currentUser.uid,
        ProgressionTaskIds.firstMessageSent,
        source: 'messages',
      ));

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Send a GIF message
  Future<bool> sendGifMessage(String chatId, String gifUrl) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final messageData = <String, dynamic>{
        'senderId': currentUser.uid,
        'text': '[GIF]',
        'gifUrl': gifUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'gif',
        'isRead': false,
      };

      // Add message to messages collection
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      // Update chat's last message
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': 'GIF',
        'lastTimestamp': FieldValue.serverTimestamp(),
      });
      unawaited(ProgressionService.instance.markTaskCompleted(
        currentUser.uid,
        ProgressionTaskIds.firstMessageSent,
        source: 'messages',
      ));

      return true;
    } catch (e) {
      // appLog('Error sending GIF message: $e');
      return false;
    }
  }

  /// Mark messages as read
  Future<bool> markMessagesAsRead(String chatId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Mark all unread messages as read
      final query = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .where('senderId', isNotEqualTo: currentUser.uid)
          .get();

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      return true;
    } catch (e) {
      // appLog('Error marking messages as read: $e');
      return false;
    }
  }

  /// Get user info (publicUsers first)
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      return await PublicProfileFirestore.instance.getProfileMap(userId);
    } catch (e) {
      return null;
    }
  }

  /// Listen to user status (public mirror for peers)
  Stream<Map<String, dynamic>?> listenToUserStatus(String userId) {
    return PublicProfileFirestore.instance.watchProfile(userId).map((snapshot) {
      if (snapshot.exists) {
        return snapshot.data();
      }
      return null;
    });
  }

  /// Listen to messages in real-time
  Stream<List<app_message.Message>> listenToMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      final messages = <app_message.Message>[];
      for (final doc in snapshot.docs) {
        final message = _mapMessage(doc.id, doc.data());
        messages.add(message);
      }
      return messages.reversed.toList();
    });
  }

  /// Listen to typing status for a specific user in a chat
  Stream<bool> listenToTypingStatus(String chatId, String userId) {
    return _firestore.collection('chats').doc(chatId).snapshots().map((doc) {
      if (!doc.exists) {
        return false;
      }
      final Map<String, dynamic>? data = doc.data();
      if (data == null) {
        return false;
      }
      final Object? typingRaw = data['typing'];
      if (typingRaw is! Map<String, dynamic>) {
        return false;
      }
      return typingRaw[userId] == true;
    });
  }

  /// Update current user's typing status in a chat
  Future<void> setTypingStatus(String chatId, bool isTyping) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || chatId.isEmpty) {
      return;
    }
    await _firestore.collection('chats').doc(chatId).set(
      <String, dynamic>{
        'typing.${currentUser.uid}': isTyping,
        'typingUpdatedAt.${currentUser.uid}': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Delete a message
  Future<bool> deleteMessage(String chatId, String messageId) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
      return true;
    } catch (e) {
      // appLog('Error deleting message: $e');
      return false;
    }
  }

  /// Update message
  Future<bool> updateMessage(
      String chatId, String messageId, String newText) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'text': newText});
      return true;
    } catch (e) {
      // appLog('Error updating message: $e');
      return false;
    }
  }

  /// Send a text reply with quoted-message metadata.
  Future<bool> sendReplyMessage(
    String chatId,
    String text,
    app_message.Message replyTo,
    String replySenderName,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;
    final String? replyToMessageId = replyTo.id;
    if (replyToMessageId == null || replyToMessageId.isEmpty) return false;

    try {
      final String previewText = _replyPreviewText(replyTo);
      final messageData = {
        'senderId': currentUser.uid,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'reply',
        'isRead': false,
        'replyTo': {
          'messageId': replyToMessageId,
          'senderId': replyTo.from,
          'senderName': replySenderName,
          'type': replyTo.messageType,
          'previewText': previewText,
          if ((replyTo.videoThumbnailUrl ?? '').isNotEmpty)
            'thumbnailUrl': replyTo.videoThumbnailUrl,
          if ((replyTo.videoId ?? '').isNotEmpty) 'videoId': replyTo.videoId,
        },
      };

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': text,
        'lastTimestamp': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  String _replyPreviewText(app_message.Message message) {
    if (message.deletedForEveryone) return 'Deleted message';
    if (message.text.trim().isNotEmpty) return message.text.trim();
    if ((message.videoTitle ?? '').trim().isNotEmpty) {
      return message.videoTitle!.trim();
    }
    if ((message.gifUrl ?? '').trim().isNotEmpty) return 'GIF';
    if (message.messageType == 'video_share' ||
        message.messageType == 'content_share') {
      return 'Shared video';
    }
    return 'Message';
  }

  /// Get unread count for a chat
  Future<int> getUnreadCount(String chatId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return 0;

      final query = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .where('senderId', isNotEqualTo: currentUser.uid)
          .get();

      return query.docs.length;
    } catch (e) {
      // appLog('Error getting unread count: $e');
      return 0;
    }
  }

  /// Map Firestore document to Message model
  app_message.Message _mapMessage(String id, Map<String, dynamic> data) {
    final currentUser = _auth.currentUser?.uid ?? '';
    final String senderId =
        (data['senderId'] as String?)?.trim().isNotEmpty == true
            ? data['senderId'] as String
            : (data['from'] as String? ?? '');

    return app_message.Message(
      id: id,
      chatId: '', // Will be set by the calling context
      text: data['text'] ?? (data['previewText'] ?? ''),
      from: senderId,
      to: senderId == currentUser
          ? 'other_user'
          : currentUser, // Simplified for now
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      gifUrl: data['gifUrl'],
      messageType: data['type'] ?? 'text',
      videoId: data['videoId'] as String?,
      videoThumbnailUrl: data['thumbnailUrl'] as String? ??
          data['videoThumbnailUrl'] as String?,
      videoTitle: data['title'] as String? ?? data['videoTitle'] as String?,
      deletedForEveryone: data['deletedForEveryone'] == true,
      replyToMessageId:
          (data['replyTo'] as Map<String, dynamic>?)?['messageId'] as String?,
      replyToSenderId:
          (data['replyTo'] as Map<String, dynamic>?)?['senderId'] as String?,
      replyToSenderName:
          (data['replyTo'] as Map<String, dynamic>?)?['senderName'] as String?,
      replyToType:
          (data['replyTo'] as Map<String, dynamic>?)?['type'] as String?,
      replyPreviewText:
          (data['replyTo'] as Map<String, dynamic>?)?['previewText'] as String?,
      replyThumbnailUrl: (data['replyTo']
          as Map<String, dynamic>?)?['thumbnailUrl'] as String?,
      replyVideoId:
          (data['replyTo'] as Map<String, dynamic>?)?['videoId'] as String?,
    );
  }

  /// Clear cache
  void clearCache() {
    _chatCache.clear();
    _messagesCache.clear();
  }
}
