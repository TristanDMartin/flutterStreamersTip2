import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Provider that tracks unread message count for the current user
final unreadMessagesProvider = StreamProvider<int>((ref) {
  final currentUser = FirebaseAuth.instance.currentUser;
  
  if (currentUser == null) {
    return Stream.value(0);
  }
  
  return FirebaseFirestore.instance
      .collection('chats')
      .where('participants', arrayContains: currentUser.uid)
      .snapshots()
      .asyncMap((chatsSnapshot) async {
    int totalUnread = 0;
    
    for (final chatDoc in chatsSnapshot.docs) {
      final chatId = chatDoc.id;
      
      // Note: We'll count unread messages below by checking readBy field
      
      // Count messages where current user is recipient but not in readBy
      final allMessages = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('recipients', arrayContains: currentUser.uid)
          .get();
      
      for (final messageDoc in allMessages.docs) {
        final messageData = messageDoc.data();
        final recipients = List<String>.from(messageData['recipients'] ?? []);
        final readBy = List<String>.from(messageData['readBy'] ?? []);
        
        // Message is unread if user is recipient but not in readBy
        if (recipients.contains(currentUser.uid) && !readBy.contains(currentUser.uid)) {
          totalUnread++;
        }
      }
    }
    
    return totalUnread;
  });
});

/// Provider for unread messages in a specific chat
final chatUnreadMessagesProvider = StreamProvider.family<int, String>((ref, chatId) {
  final currentUser = FirebaseAuth.instance.currentUser;
  
  if (currentUser == null) {
    return Stream.value(0);
  }
  
  return FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .where('recipients', arrayContains: currentUser.uid)
      .snapshots()
      .map((snapshot) {
    int unreadCount = 0;
    
    for (final doc in snapshot.docs) {
      final messageData = doc.data();
      final recipients = List<String>.from(messageData['recipients'] ?? []);
      final readBy = List<String>.from(messageData['readBy'] ?? []);
      
      // Message is unread if user is recipient but not in readBy
      if (recipients.contains(currentUser.uid) && !readBy.contains(currentUser.uid)) {
        unreadCount++;
      }
    }
    
    return unreadCount;
  });
});

/// Service to mark messages as read
class UnreadMessagesService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Mark all messages in a chat as read for the current user
  static Future<void> markChatAsRead(String chatId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    
    try {
      // Get all unread messages in this chat
      final unreadMessages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('recipients', arrayContains: currentUser.uid)
          .get();
      
      // Mark each unread message as read
      final batch = _firestore.batch();
      
      for (final messageDoc in unreadMessages.docs) {
        final messageData = messageDoc.data();
        final readBy = List<String>.from(messageData['readBy'] ?? []);
        
        // Only update if user is not already in readBy
        if (!readBy.contains(currentUser.uid)) {
          batch.update(messageDoc.reference, {
            'readBy': FieldValue.arrayUnion([currentUser.uid])
          });
        }
      }
      
      await batch.commit();
    // print('✅ Marked chat $chatId as read for user ${currentUser.uid}');
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
        'readBy': FieldValue.arrayUnion([currentUser.uid])
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
