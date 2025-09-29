import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  static ChatService get shared => _instance;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  ChatService._internal();

  Future<Chat?> fetchOrCreateChat(String otherUID) async {
    final me = _auth.currentUser?.uid;
    if (me == null) {
      print("❌ ChatService: No current user signed in");
      return null;
    }

    print("💬 ChatService: fetchOrCreateChat called with otherUID: $otherUID, currentUser: $me");

    try {
      // Query for existing chats
      final querySnapshot = await _firestore
          .collection("chats")
          .where("participants", arrayContains: me)
          .get();

      print("💬 ChatService: Found ${querySnapshot.docs.length} existing chats");

      // Check if there's an existing chat with the other user
      for (final doc in querySnapshot.docs) {
        final participants = List<String>.from(doc.data()["participants"] ?? []);
        print("💬 ChatService: Checking chat ${doc.id} with participants: $participants");
        if (participants.contains(otherUID)) {
          print("💬 ChatService: Found existing chat with user $otherUID");
          final chat = Chat.fromJson(doc.data());
          return chat.copyWith(id: doc.id);
        }
      }

      print("💬 ChatService: No existing chat found, creating new chat");
      // No existing chat, create new
      final data = {
        "participants": [me, otherUID],
        "lastMessage": "",
        "lastTimestamp": FieldValue.serverTimestamp(),
        "chatType": "direct",
      };

      final docRef = await _firestore.collection("chats").add(data);
      print("💬 ChatService: Created new chat with ID: ${docRef.id}");
      
      // Fetch the created document
      final snapshot = await docRef.get();
      if (snapshot.exists) {
        print("💬 ChatService: Successfully fetched created chat document");
        final chat = Chat.fromJson(snapshot.data()!);
        return chat.copyWith(id: snapshot.id);
      }

      print("❌ ChatService: Created chat document doesn't exist");
      return null;
    } catch (e) {
      print("❌ ChatService: Error in fetchOrCreateChat: $e");
      return null;
    }
  }

  // New method: Create a placeholder chat immediately and then fetch/create the real one
  Future<void> createPlaceholderAndFetchChat({
    required String otherUID,
    required Function(Chat) onPlaceholderCreated,
    required Function(Chat) onRealChatFetched,
  }) async {
    final me = _auth.currentUser?.uid;
    if (me == null) {
    // print("No current user signed in");
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
        final participants = List<String>.from(doc.data()["participants"] ?? []);
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
    // print("Error in createPlaceholderAndFetchChat: $e");
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
    // print("Error updating last message: $e");
    }
  }

  Future<void> markChatAsRead(String chatId) async {
    try {
      await _firestore.collection("chats").doc(chatId).update({
        "lastReadTimestamp": FieldValue.serverTimestamp(),
      });
    } catch (e) {
    // print("Error marking chat as read: $e");
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
    // print("Error getting user chats: $e");
      return [];
    }
  }

  Future<void> deleteChat(String chatId) async {
    try {
      await _firestore.collection("chats").doc(chatId).delete();
    } catch (e) {
    // print("Error deleting chat: $e");
    }
  }

  // Bulk action methods
  Future<void> deleteMultipleChats(List<String> chatIds) async {
    try {
      final batch = _firestore.batch();
      for (final chatId in chatIds) {
        final chatRef = _firestore.collection("chats").doc(chatId);
        batch.delete(chatRef);
      }
      await batch.commit();
    // print("✅ Deleted ${chatIds.length} chats");
    } catch (e) {
    // print("Error deleting multiple chats: $e");
      rethrow;
    }
  }

  Future<void> muteChat(String chatId, String userId) async {
    try {
      await _firestore.collection("chats").doc(chatId).update({
        "mutedBy": FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
    // print("Error muting chat: $e");
      rethrow;
    }
  }

  Future<void> unmuteChat(String chatId, String userId) async {
    try {
      await _firestore.collection("chats").doc(chatId).update({
        "mutedBy": FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
    // print("Error unmuting chat: $e");
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
    // print("✅ Muted ${chatIds.length} chats");
    } catch (e) {
    // print("Error muting multiple chats: $e");
      rethrow;
    }
  }

  Future<void> archiveChat(String chatId, String userId) async {
    try {
      await _firestore.collection("chats").doc(chatId).update({
        "archivedBy": FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
    // print("Error archiving chat: $e");
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
    // print("✅ Archived ${chatIds.length} chats");
    } catch (e) {
    // print("Error archiving multiple chats: $e");
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
    // print("Error creating group chat: $e");
      return null;
    }
  }

  Future<void> addParticipantToGroup(String chatId, String participantId) async {
    try {
      await _firestore.collection("chats").doc(chatId).update({
        "participants": FieldValue.arrayUnion([participantId]),
      });
    } catch (e) {
    // print("Error adding participant to group: $e");
    }
  }

  Future<void> removeParticipantFromGroup(String chatId, String participantId) async {
    try {
      await _firestore.collection("chats").doc(chatId).update({
        "participants": FieldValue.arrayRemove([participantId]),
      });
    } catch (e) {
    // print("Error removing participant from group: $e");
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
    // print("Error updating group info: $e");
    }
  }

  /// Creates sample chats for testing purposes
  Future<void> createSampleChats() async {
    final me = _auth.currentUser?.uid;
    if (me == null) {
    // print("No current user signed in");
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
          final participants = List<String>.from(doc.data()['participants'] ?? []);
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
          await _addSampleMessages(chatRef.id, chatData['participants'] as List<String>);
        }
      }

    // print('✅ Created sample chats for testing');
    } catch (e) {
    // print('❌ Error creating sample chats: $e');
    }
  }

  /// Adds sample messages to a chat for testing
  Future<void> _addSampleMessages(String chatId, List<String> participants) async {
    try {
      final currentUser = _auth.currentUser?.uid;
      if (currentUser == null) return;
      
      final otherUserId = participants.firstWhere((id) => id != currentUser, orElse: () => '');
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
          'readBy': [messageData['from']], // Sender has "read" their own message
        });
      }
      
    // print('✅ Added sample messages to chat $chatId');
    } catch (e) {
    // print('❌ Error adding sample messages: $e');
    }
  }
}
