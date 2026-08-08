import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../features/messaging/data/messaging_repository.dart';
import '../models/chat.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  static ChatService get shared => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final MessagingRepository _messaging = MessagingRepository.instance;

  ChatService._internal();

  Future<Chat?> fetchOrCreateChat(String otherUID) async {
    final me = _auth.currentUser?.uid;
    if (me == null) {
      debugPrint("❌ ChatService: No current user signed in");
      return null;
    }

    if (otherUID.isEmpty) {
      debugPrint("❌ ChatService: otherUID is empty");
      return null;
    }

    debugPrint(
        "💬 ChatService: fetchOrCreateChat called with otherUID: $otherUID, currentUser: $me");

    try {
      final String chatId = await _messaging.getOrCreateDirectChat(
        currentUserId: me,
        otherUserId: otherUID,
      );
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _firestore.collection('chats').doc(chatId).get();
      if (!snapshot.exists) {
        debugPrint("❌ ChatService: Canonical chat missing after create");
        return null;
      }
      return _chatFromFirestore(chatId, snapshot.data()!);
    } catch (e, stackTrace) {
      debugPrint("❌ ChatService: Error in fetchOrCreateChat: $e");
      debugPrint("❌ ChatService: Stack trace: $stackTrace");
      if (e.toString().contains('permission-denied')) {
        debugPrint("❌ ChatService: Permission denied - check Firestore rules");
      } else if (e.toString().contains('network')) {
        debugPrint("❌ ChatService: Network error");
      } else if (e.toString().contains('invalid-argument')) {
        debugPrint(
            "❌ ChatService: Invalid argument - check otherUID: $otherUID");
      }
      return null;
    }
  }

  Chat _chatFromFirestore(String id, Map<String, dynamic> data) {
    final List<String> participants = (data['participants'] as List<dynamic>?)
            ?.map((dynamic e) => e.toString())
            .where((String id) => id.isNotEmpty)
            .toList() ??
        <String>[];
    final Object? timestampRaw = data['lastTimestamp'];
    final DateTime lastTimestamp = timestampRaw is Timestamp
        ? timestampRaw.toDate()
        : DateTime.now();
    return Chat(
      id: id,
      participants: participants,
      lastMessage: (data['lastMessage'] as String?) ?? '',
      lastTimestamp: lastTimestamp,
      chatType: (data['chatType'] as String?) ?? 'direct',
      mutedBy: (data['mutedBy'] as List<dynamic>?)
              ?.map((dynamic e) => e.toString())
              .toList() ??
          const <String>[],
      archivedBy: (data['archivedBy'] as List<dynamic>?)
              ?.map((dynamic e) => e.toString())
              .toList() ??
          const <String>[],
    );
  }

  // New method: Create a placeholder chat immediately and then fetch/create the real one
  Future<void> createPlaceholderAndFetchChat({
    required String otherUID,
    required Function(Chat) onPlaceholderCreated,
    required Function(Chat) onRealChatFetched,
  }) async {
    final me = _auth.currentUser?.uid;
    if (me == null) {
      // appLog("No current user signed in");
      return;
    }

    // Create placeholder chat immediately with a temporary unique ID
    final tempId = "temp_${DateTime.now().millisecondsSinceEpoch}";
    final placeholderChat = Chat(
      id: tempId,
      participants: [me, otherUID],
      lastMessage: "",
      lastTimestamp: DateTime.now(),
      chatType: "direct",
    );

    // Present the placeholder immediately
    onPlaceholderCreated(placeholderChat);

    // Then fetch/create the real chat in the background
    try {
      // Query for existing chats
      final querySnapshot = await _firestore
          .collection("chats")
          .where("participants", arrayContains: me)
          .get();

      // Check if there's an existing chat with the other user
      for (final doc in querySnapshot.docs) {
        final participants =
            List<String>.from(doc.data()["participants"] ?? []);
        if (participants.contains(otherUID)) {
          final chat = Chat.fromJson(doc.data());
          final realChat = chat.copyWith(id: doc.id);
          onRealChatFetched(realChat);
          return;
        }
      }

      // No existing chat, create new
      final data = {
        "participants": [me, otherUID],
        "lastMessage": "",
        "lastTimestamp": FieldValue.serverTimestamp(),
        "chatType": "direct",
      };

      final docRef = await _firestore.collection("chats").add(data);

      // Fetch the created document
      final snapshot = await docRef.get();
      if (snapshot.exists) {
        final chat = Chat.fromJson(snapshot.data()!);
        final realChat = chat.copyWith(id: snapshot.id);
        onRealChatFetched(realChat);
      }
    } catch (e) {
      // appLog("Error in createPlaceholderAndFetchChat: $e");
    }
  }

  // Method to update a placeholder chat with real data
  Chat updateChatWithRealData(Chat placeholderChat, Chat realChat) {
    return placeholderChat.copyWith(
      id: realChat.id,
      lastMessage: realChat.lastMessage,
      lastTimestamp: realChat.lastTimestamp,
      groupName: realChat.groupName,
      groupAvatarURL: realChat.groupAvatarURL,
    );
  }

  // Additional methods for chat management

  Future<void> updateLastMessage(String chatId, String message) async {
    try {
      await _firestore.collection("chats").doc(chatId).update({
        "lastMessage": message,
        "lastTimestamp": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // appLog("Error updating last message: $e");
    }
  }

  Future<void> markChatAsRead(String chatId) async {
    try {
      await _firestore.collection("chats").doc(chatId).update({
        "lastReadTimestamp": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // appLog("Error marking chat as read: $e");
    }
  }

  Future<List<Chat>> getUserChats() async {
    final me = _auth.currentUser?.uid;
    if (me == null) return [];

    try {
      final querySnapshot = await _firestore
          .collection("chats")
          .where("participants", arrayContains: me)
          .orderBy("lastTimestamp", descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final chat = Chat.fromJson(doc.data());
        return chat.copyWith(id: doc.id);
      }).toList();
    } catch (e) {
      // appLog("Error getting user chats: $e");
      return [];
    }
  }

  Future<void> deleteChat(String chatId) async {
    final String? me = _auth.currentUser?.uid;
    if (me == null || chatId.isEmpty) {
      return;
    }
    try {
      // Rules disallow hard delete; soft-hide for this user only.
      await _firestore.collection("chats").doc(chatId).update({
        "deletedFor": FieldValue.arrayUnion(<String>[me]),
      });
    } catch (e) {
      // appLog("Error deleting chat: $e");
    }
  }

  // Bulk action methods
  Future<void> deleteMultipleChats(List<String> chatIds) async {
    final String? me = _auth.currentUser?.uid;
    if (me == null || chatIds.isEmpty) {
      return;
    }
    try {
      final WriteBatch batch = _firestore.batch();
      for (final String chatId in chatIds) {
        batch.update(
          _firestore.collection("chats").doc(chatId),
          <String, dynamic>{
            "deletedFor": FieldValue.arrayUnion(<String>[me]),
          },
        );
      }
      await batch.commit();
    } catch (e) {
      // appLog("Error deleting multiple chats: $e");
      rethrow;
    }
  }

  Future<void> muteChat(String chatId, String userId) async {
    try {
      await _firestore.collection("chats").doc(chatId).update({
        "mutedBy": FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      // appLog("Error muting chat: $e");
      rethrow;
    }
  }

  Future<void> unmuteChat(String chatId, String userId) async {
    try {
      await _firestore.collection("chats").doc(chatId).update({
        "mutedBy": FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      // appLog("Error unmuting chat: $e");
      rethrow;
    }
  }

  Future<void> muteMultipleChats(List<String> chatIds, String userId) async {
    try {
      final batch = _firestore.batch();
      for (final chatId in chatIds) {
        final chatRef = _firestore.collection("chats").doc(chatId);
        batch.update(chatRef, {
          "mutedBy": FieldValue.arrayUnion([userId]),
        });
      }
      await batch.commit();
      // appLog("✅ Muted ${chatIds.length} chats");
    } catch (e) {
      // appLog("Error muting multiple chats: $e");
      rethrow;
    }
  }

  Future<void> archiveChat(String chatId, String userId) async {
    try {
      await _firestore.collection("chats").doc(chatId).update({
        "archivedBy": FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      // appLog("Error archiving chat: $e");
      rethrow;
    }
  }

  Future<void> archiveMultipleChats(List<String> chatIds, String userId) async {
    try {
      final batch = _firestore.batch();
      for (final chatId in chatIds) {
        final chatRef = _firestore.collection("chats").doc(chatId);
        batch.update(chatRef, {
          "archivedBy": FieldValue.arrayUnion([userId]),
        });
      }
      await batch.commit();
      // appLog("✅ Archived ${chatIds.length} chats");
    } catch (e) {
      // appLog("Error archiving multiple chats: $e");
      rethrow;
    }
  }

  // Group chat methods

  Future<Chat?> createGroupChat({
    required String groupName,
    required List<String> participantIds,
    String? groupAvatarURL,
  }) async {
    final me = _auth.currentUser?.uid;
    if (me == null) return null;

    try {
      final data = {
        "participants": participantIds,
        "groupName": groupName,
        "groupAvatarURL": groupAvatarURL,
        "lastMessage": "",
        "lastTimestamp": FieldValue.serverTimestamp(),
        "chatType": "group",
        "createdBy": me,
        "createdAt": FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection("chats").add(data);

      // Fetch the created document
      final snapshot = await docRef.get();
      if (snapshot.exists) {
        final chat = Chat.fromJson(snapshot.data()!);
        return chat.copyWith(id: snapshot.id);
      }

      return null;
    } catch (e) {
      // appLog("Error creating group chat: $e");
      return null;
    }
  }

  Future<void> addParticipantToGroup(
      String chatId, String participantId) async {
    try {
      await _firestore.collection("chats").doc(chatId).update({
        "participants": FieldValue.arrayUnion([participantId]),
      });
    } catch (e) {
      // appLog("Error adding participant to group: $e");
    }
  }

  Future<void> removeParticipantFromGroup(
      String chatId, String participantId) async {
    try {
      await _firestore.collection("chats").doc(chatId).update({
        "participants": FieldValue.arrayRemove([participantId]),
      });
    } catch (e) {
      // appLog("Error removing participant from group: $e");
    }
  }

  Future<void> updateGroupInfo({
    required String chatId,
    String? groupName,
    String? groupAvatarURL,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (groupName != null) updates["groupName"] = groupName;
      if (groupAvatarURL != null) updates["groupAvatarURL"] = groupAvatarURL;

      if (updates.isNotEmpty) {
        await _firestore.collection("chats").doc(chatId).update(updates);
      }
    } catch (e) {
      // appLog("Error updating group info: $e");
    }
  }

  /// Creates sample chats for testing purposes
  Future<void> createSampleChats() async {
    final me = _auth.currentUser?.uid;
    if (me == null) {
      // appLog("No current user signed in");
      return;
    }

    try {
      // Create sample users first if they don't exist
      final sampleUsers = [
        {
          'id': 'user1',
          'username': 'gamer_girl',
          'displayName': 'Gamer Girl',
          'bio': 'Professional gamer',
          'avatarURL': null,
          'onlineStatus': 'online',
        },
        {
          'id': 'user2',
          'username': 'art_streamer',
          'displayName': 'Art Streamer',
          'bio': 'Digital artist',
          'avatarURL': null,
          'onlineStatus': 'offline',
        },
        {
          'id': 'user3',
          'username': 'music_lover',
          'displayName': 'Music Lover',
          'bio': 'Music enthusiast',
          'avatarURL': null,
          'onlineStatus': 'busy',
        },
      ];

      for (final userData in sampleUsers) {
        final userId = userData['id']!;
        final userRef = _firestore.collection('users').doc(userId);

        await userRef.set({
          'id': userId,
          'username': userData['username']!,
          'displayName': userData['displayName']!,
          'bio': userData['bio']!,
          'avatarURL': userData['avatarURL'],
          'onlineStatus': userData['onlineStatus']!,
          'followerCount': 0,
          'followingCount': 0,
          'postCount': 0,
          'hashtags': [],
          'aiSelf': '',
          'calendarEvents': [],
        }, SetOptions(merge: true));
      }

      // Create sample chats
      final sampleChats = [
        {
          'participants': [me, 'user1'],
          'lastMessage': 'Hey! How\'s it going?',
          'lastTimestamp': DateTime.now().subtract(const Duration(minutes: 5)),
          'chatType': 'direct',
        },
        {
          'participants': [me, 'user2'],
          'lastMessage': 'Check out this amazing play!',
          'lastTimestamp': DateTime.now().subtract(const Duration(hours: 2)),
          'chatType': 'direct',
        },
        {
          'participants': [me, 'user3'],
          'lastMessage': 'Are you streaming tonight?',
          'lastTimestamp': DateTime.now().subtract(const Duration(days: 1)),
          'chatType': 'direct',
        },
      ];

      for (final chatData in sampleChats) {
        // Check if chat already exists
        final existingChats = await _firestore
            .collection('chats')
            .where('participants', arrayContains: me)
            .get();

        bool chatExists = false;
        for (final doc in existingChats.docs) {
          final participants =
              List<String>.from(doc.data()['participants'] ?? []);
          final chatParticipants = chatData['participants'] as List<String>;
          if (participants.contains(chatParticipants[1])) {
            chatExists = true;
            break;
          }
        }

        if (!chatExists) {
          final chatRef = await _firestore.collection('chats').add({
            'participants': chatData['participants'],
            'lastMessage': chatData['lastMessage'],
            'lastTimestamp': chatData['lastTimestamp'],
            'chatType': chatData['chatType'],
          });

          // Add some sample messages to the chat
          await _addSampleMessages(
              chatRef.id, chatData['participants'] as List<String>);
        }
      }

      // appLog('✅ Created sample chats for testing');
    } catch (e) {
      // appLog('❌ Error creating sample chats: $e');
    }
  }

  /// Adds sample messages to a chat for testing
  Future<void> _addSampleMessages(
      String chatId, List<String> participants) async {
    try {
      final currentUser = _auth.currentUser?.uid;
      if (currentUser == null) return;

      final otherUserId =
          participants.firstWhere((id) => id != currentUser, orElse: () => '');
      if (otherUserId.isEmpty) return;

      // Sample conversation
      final sampleMessages = [
        {
          'text': 'Hey! How\'s it going?',
          'from': otherUserId,
          'to': currentUser,
          'timestamp': DateTime.now().subtract(const Duration(minutes: 10)),
        },
        {
          'text': 'Hi! I\'m doing great, thanks for asking!',
          'from': currentUser,
          'to': otherUserId,
          'timestamp': DateTime.now().subtract(const Duration(minutes: 9)),
        },
        {
          'text': 'That\'s awesome! Are you streaming tonight?',
          'from': otherUserId,
          'to': currentUser,
          'timestamp': DateTime.now().subtract(const Duration(minutes: 8)),
        },
        {
          'text': 'Yes! I\'ll be live at 8 PM. You should join!',
          'from': currentUser,
          'to': otherUserId,
          'timestamp': DateTime.now().subtract(const Duration(minutes: 7)),
        },
        {
          'text': 'Definitely! I\'ll be there 🎮',
          'from': otherUserId,
          'to': currentUser,
          'timestamp': DateTime.now().subtract(const Duration(minutes: 6)),
        },
      ];

      for (final messageData in sampleMessages) {
        await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .add({
          'text': messageData['text'],
          'from': messageData['from'],
          'to': messageData['to'],
          'isRead': false,
          'timestamp': messageData['timestamp'],
          'chatId': chatId,
          'recipients': [messageData['to']], // Recipient needs to read this
          'readBy': [
            messageData['from']
          ], // Sender has "read" their own message
        });
      }

      // appLog('✅ Added sample messages to chat $chatId');
    } catch (e) {
      // appLog('❌ Error adding sample messages: $e');
    }
  }
}
