import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Provider that tracks unread message count for the current user
/// Uses chat-level unreadCount field managed by Cloud Functions
final unreadMessagesProvider = StreamProvider<int>((ref) {
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    return Stream.value(0);
  }

  return FirebaseFirestore.instance
      .collection('chats')
      .where('participants', arrayContains: currentUser.uid)
      .snapshots()
      .map((chatsSnapshot) {
    int totalUnread = 0;

    for (final chatDoc in chatsSnapshot.docs) {
      final chatData = chatDoc.data();
      // Get unread count for this user from chat document
      final unreadField = 'unreadCount_${currentUser.uid}';
      final dynamic unreadCount = chatData[unreadField] ?? 0;
      totalUnread +=
          (unreadCount is int ? unreadCount : (unreadCount as num).toInt());
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

    // Get unread count for current user from chat document
    final unreadField = 'unreadCount_${currentUser.uid}';
    final dynamic unreadCount = chatData[unreadField] ?? 0;
    return unreadCount is int ? unreadCount : (unreadCount as num).toInt();
  });
});

/// Service to mark messages as read
class UnreadMessagesService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Mark all messages in a chat as read for the current user
  /// Simply resets the unread count to 0 on the chat document
  static Future<void> markChatAsRead(String chatId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('recipients', arrayContains: currentUser.uid)
          .get();

      final batch = _firestore.batch();
      var hasUpdates = false;

      for (final messageDoc in messagesSnapshot.docs) {
        final readBy = List<String>.from(messageDoc.data()['readBy'] ?? const []);
        if (readBy.contains(currentUser.uid)) continue;

        batch.update(messageDoc.reference, {
          'readBy': FieldValue.arrayUnion([currentUser.uid]),
          'isRead': true,
        });
        hasUpdates = true;
      }

      batch.set(
        _firestore.collection('chats').doc(chatId),
        {
          'unreadCount_${currentUser.uid}': 0,
          'lastReadTimestamp': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (hasUpdates || messagesSnapshot.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      // print('❌ Error marking chat as read: $e');
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
      // print('❌ Error marking message as read: $e');
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

      // print('✅ Marked all visible messages as read');
    } catch (e) {
      // print('❌ Error marking all messages as read: $e');
    }
  }
}
