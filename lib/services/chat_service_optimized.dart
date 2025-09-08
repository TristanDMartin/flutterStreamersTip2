import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/chat.dart' as app_chat;
import '../models/message.dart' as app_message;

class ChatServiceOptimized {
  static final ChatServiceOptimized _instance = ChatServiceOptimized._internal();
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
      print('Error getting messages: $e');
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

      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  /// Send a GIF message
  Future<bool> sendGifMessage(String chatId, String gifUrl) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final messageData = {
        'senderId': currentUser.uid,
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

      return true;
    } catch (e) {
      print('Error sending GIF message: $e');
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
      print('Error marking messages as read: $e');
      return false;
    }
  }

  /// Get user info
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting user info: $e');
      return null;
    }
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
      return messages.reversed.toList(); // Return in chronological order
    });
  }

  /// Listen to user status
  Stream<Map<String, dynamic>?> listenToUserStatus(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return snapshot.data();
      }
      return null;
    });
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
      print('Error deleting message: $e');
      return false;
    }
  }

  /// Update message
  Future<bool> updateMessage(String chatId, String messageId, String newText) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'text': newText});
      return true;
    } catch (e) {
      print('Error updating message: $e');
      return false;
    }
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
      print('Error getting unread count: $e');
      return 0;
    }
  }

  /// Map Firestore document to Message model
  app_message.Message _mapMessage(String id, Map<String, dynamic> data) {
    return app_message.Message(
      id: id,
      chatId: '', // Will be set by the calling context
      text: data['text'] ?? '',
      from: data['senderId'] ?? '',
      to: '', // Will be set by the calling context
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      gifUrl: data['gifUrl'],
      messageType: data['type'] ?? 'text',
    );
  }

  /// Clear cache
  void clearCache() {
    _chatCache.clear();
    _messagesCache.clear();
  }
}
