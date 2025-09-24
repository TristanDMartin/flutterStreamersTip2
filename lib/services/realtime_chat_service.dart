import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';
import '../services/logging_service.dart';

class RealtimeChatService {
  static final RealtimeChatService _instance = RealtimeChatService._internal();
  factory RealtimeChatService() => _instance;
  RealtimeChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final Map<String, StreamSubscription> _activeSubscriptions = {};
  final Map<String, StreamController<List<ChatMessage>>> _messageControllers = {};

  /// Create a new chat room
  Future<ChatRoom?> createChatRoom({
    required List<String> participantIds,
    String? roomName,
    String? roomType,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        LoggingService.instance.error('User not authenticated', tag: 'RealtimeChatService');
        return null;
      }

      // Ensure current user is in participants
      if (!participantIds.contains(currentUser.uid)) {
        participantIds.add(currentUser.uid);
      }

      // Create room document
      final roomData = {
        'participants': participantIds,
        'roomName': roomName ?? 'Chat Room',
        'roomType': roomType ?? 'direct',
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'lastMessageAt': null,
        'isActive': true,
      };

      final roomRef = await _firestore.collection('chat_rooms').add(roomData);
      
      // Create initial system message
      await _sendSystemMessage(
        roomId: roomRef.id,
        message: 'Chat room created',
      );

      LoggingService.instance.debug('✅ Chat room created: ${roomRef.id}', tag: 'RealtimeChatService');
      
      return ChatRoom(
        id: roomRef.id,
        participants: participantIds,
        roomName: roomName ?? 'Chat Room',
        roomType: roomType ?? 'direct',
        createdAt: DateTime.now(),
        lastMessage: null,
        lastMessageAt: null,
        isActive: true,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error creating chat room', tag: 'RealtimeChatService', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Send a message to a chat room
  Future<bool> sendMessage({
    required String roomId,
    required String content,
    String? messageType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        LoggingService.instance.error('User not authenticated', tag: 'RealtimeChatService');
        return false;
      }

      final messageData = {
        'roomId': roomId,
        'senderId': currentUser.uid,
        'content': content,
        'messageType': messageType ?? 'text',
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'isEdited': false,
        'isDeleted': false,
      };

      // Add message to messages subcollection
      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .add(messageData);

      // Update room's last message
      await _firestore.collection('chat_rooms').doc(roomId).update({
        'lastMessage': content,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      LoggingService.instance.debug('✅ Message sent to room: $roomId', tag: 'RealtimeChatService');
      return true;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error sending message', tag: 'RealtimeChatService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Send a system message (for room events)
  Future<bool> _sendSystemMessage({
    required String roomId,
    required String message,
  }) async {
    try {
      final messageData = {
        'roomId': roomId,
        'senderId': 'system',
        'content': message,
        'messageType': 'system',
        'metadata': {},
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': true,
        'isEdited': false,
        'isDeleted': false,
      };

      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .add(messageData);

      return true;
    } catch (e) {
      LoggingService.instance.error('Error sending system message', tag: 'RealtimeChatService', error: e);
      return false;
    }
  }

  /// Listen to messages in a chat room
  Stream<List<ChatMessage>> listenToMessages(String roomId) {
    if (_messageControllers.containsKey(roomId)) {
      return _messageControllers[roomId]!.stream;
    }

    final controller = StreamController<List<ChatMessage>>.broadcast();
    _messageControllers[roomId] = controller;

    final subscription = _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen(
      (snapshot) {
      final messages = snapshot.docs.map((doc) {
        final data = doc.data();
        return ChatMessage.fromMap({
          'id': doc.id,
          'roomId': data['roomId'] ?? '',
          'senderId': data['senderId'] ?? '',
          'content': data['content'] ?? '',
          'messageType': data['messageType'] ?? 'text',
          'metadata': data['metadata'] ?? {},
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'isRead': data['isRead'] ?? false,
          'isEdited': data['isEdited'] ?? false,
          'isDeleted': data['isDeleted'] ?? false,
        });
      }).toList();

        controller.add(messages);
      },
      onError: (error) {
        LoggingService.instance.error('Error listening to messages', tag: 'RealtimeChatService', error: error);
        controller.addError(error);
      },
    );

    _activeSubscriptions[roomId] = subscription;
    return controller.stream;
  }

  /// Get user's chat rooms
  Future<List<ChatRoom>> getUserChatRooms() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        LoggingService.instance.error('User not authenticated', tag: 'RealtimeChatService');
        return [];
      }

      final snapshot = await _firestore
          .collection('chat_rooms')
          .where('participants', arrayContains: currentUser.uid)
          .where('isActive', isEqualTo: true)
          .orderBy('lastMessageAt', descending: true)
          .get();

      final rooms = snapshot.docs.map((doc) {
        final data = doc.data();
        return ChatRoom.fromMap({
          'id': doc.id,
          'participants': data['participants'] ?? [],
          'roomName': data['roomName'] ?? 'Chat Room',
          'roomType': data['roomType'] ?? 'direct',
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'lastMessage': data['lastMessage'],
          'lastMessageAt': (data['lastMessageAt'] as Timestamp?)?.toDate(),
          'isActive': data['isActive'] ?? true,
        });
      }).toList();

      LoggingService.instance.debug('✅ Retrieved ${rooms.length} chat rooms', tag: 'RealtimeChatService');
      return rooms;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting user chat rooms', tag: 'RealtimeChatService', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Mark messages as read
  Future<bool> markMessagesAsRead(String roomId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Update all unread messages in the room
      final batch = _firestore.batch();
      
      final unreadMessages = await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUser.uid)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      
      LoggingService.instance.debug('✅ Marked messages as read in room: $roomId', tag: 'RealtimeChatService');
      return true;
    } catch (e) {
      LoggingService.instance.error('Error marking messages as read', tag: 'RealtimeChatService', error: e);
      return false;
    }
  }

  /// Edit a message
  Future<bool> editMessage({
    required String roomId,
    required String messageId,
    required String newContent,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .doc(messageId)
          .update({
        'content': newContent,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });

      LoggingService.instance.debug('✅ Message edited: $messageId', tag: 'RealtimeChatService');
      return true;
    } catch (e) {
      LoggingService.instance.error('Error editing message', tag: 'RealtimeChatService', error: e);
      return false;
    }
  }

  /// Delete a message
  Future<bool> deleteMessage({
    required String roomId,
    required String messageId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .doc(messageId)
          .update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });

      LoggingService.instance.debug('✅ Message deleted: $messageId', tag: 'RealtimeChatService');
      return true;
    } catch (e) {
      LoggingService.instance.error('Error deleting message', tag: 'RealtimeChatService', error: e);
      return false;
    }
  }

  /// Get or create direct message room with another user
  Future<ChatRoom?> getOrCreateDirectMessageRoom(String otherUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      // Check if direct message room already exists
      final existingRooms = await _firestore
          .collection('chat_rooms')
          .where('participants', arrayContains: currentUser.uid)
          .where('roomType', isEqualTo: 'direct')
          .get();

      for (final doc in existingRooms.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        if (participants.contains(otherUserId) && participants.length == 2) {
        return ChatRoom.fromMap({
          'id': doc.id,
          'participants': participants,
          'roomName': data['roomName'] ?? 'Direct Message',
          'roomType': 'direct',
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'lastMessage': data['lastMessage'],
          'lastMessageAt': (data['lastMessageAt'] as Timestamp?)?.toDate(),
          'isActive': data['isActive'] ?? true,
        });
        }
      }

      // Create new direct message room
      return await createChatRoom(
        participantIds: [currentUser.uid, otherUserId],
        roomName: 'Direct Message',
        roomType: 'direct',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting/creating direct message room', tag: 'RealtimeChatService', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Clean up resources
  void dispose() {
    for (final subscription in _activeSubscriptions.values) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();
    
    for (final controller in _messageControllers.values) {
      controller.close();
    }
    _messageControllers.clear();
  }

  /// Stop listening to a specific room
  void stopListeningToRoom(String roomId) {
    _activeSubscriptions[roomId]?.cancel();
    _activeSubscriptions.remove(roomId);
    
    _messageControllers[roomId]?.close();
    _messageControllers.remove(roomId);
  }
}
