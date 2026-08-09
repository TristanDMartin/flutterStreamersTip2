import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/messaging/data/messaging_repository.dart';

/// Provider that tracks unread message count for the current user.
/// Uses chat-level unreadCount field managed by Cloud Functions.
/// Kept alive so the inbox badge updates on startup without opening Inbox.
final unreadMessagesProvider = StreamProvider<int>((ref) {
  ref.keepAlive();
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    return Stream.value(0);
  }

  final MessagingRepository messaging = MessagingRepository.instance;
  return FirebaseFirestore.instance
      .collection('chats')
      .where('participants', arrayContains: currentUser.uid)
      .snapshots()
      .map((chatsSnapshot) {
    int totalUnread = 0;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> chatDoc
        in chatsSnapshot.docs) {
      final Map<String, dynamic> chatData = chatDoc.data();
      if (chatData['supersededBy'] != null) {
        continue;
      }
      final List<dynamic> deletedRaw =
          (chatData['deletedFor'] as List<dynamic>?) ?? const <dynamic>[];
      if (deletedRaw
          .map((dynamic e) => e.toString())
          .contains(currentUser.uid)) {
        continue;
      }
      totalUnread += messaging.unreadCountForUser(chatData, currentUser.uid);
    }
    return totalUnread;
  });
});

/// Provider for unread messages in a specific chat
/// Uses chat-level unreadCount field managed by Cloud Functions
final chatUnreadMessagesProvider =
    StreamProvider.family<int, String>((ref, chatId) {
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    return Stream.value(0);
  }

  return FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .snapshots()
      .map((snapshot) {
    if (!snapshot.exists) return 0;

    final chatData = snapshot.data();
    if (chatData == null) return 0;

    return MessagingRepository.instance.unreadCountForUser(
      chatData,
      currentUser.uid,
    );
  });
});

/// Service to mark messages as read
class UnreadMessagesService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Mark all messages in a chat as read for the current user.
  /// Only zeros this chat's unread counter (never other chats).
  static Future<void> markChatAsRead(String chatId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await MessagingRepository.instance.markChatRead(
        chatId: chatId,
        userId: currentUser.uid,
      );
    } catch (e) {
      // Best-effort read marker.
    }
  }

  /// Mark a specific message as read
  static Future<void> markMessageAsRead(String chatId, String messageId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'readBy': FieldValue.arrayUnion([currentUser.uid]),
        'isRead': true,
      });
    } catch (e) {
      // appLog('❌ Error marking message as read: $e');
    }
  }

  /// Mark all visible messages in inbox as read
  static Future<void> markAllVisibleAsRead() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Get all chats for current user
      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      // Mark all messages in all chats as read
      for (final chatDoc in chatsSnapshot.docs) {
        await markChatAsRead(chatDoc.id);
      }

      // appLog('✅ Marked all visible messages as read');
    } catch (e) {
      // appLog('❌ Error marking all messages as read: $e');
    }
  }
}
