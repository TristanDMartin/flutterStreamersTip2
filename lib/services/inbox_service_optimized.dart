import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/chat.dart' as app_chat;
import '../models/shared_draft.dart';

class InboxServiceOptimized {
  static final InboxServiceOptimized _instance = InboxServiceOptimized._internal();
  factory InboxServiceOptimized() => _instance;
  InboxServiceOptimized._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  
  // Expose auth for external access
  firebase_auth.FirebaseAuth get auth => _auth;

  // Cache for better performance
  final Map<String, app_chat.Chat> _chatCache = {};
  final Map<String, SharedDraft> _draftCache = {};

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
      print('Error getting chats: $e');
      return [];
    }
  }

  /// Get user's shared drafts
  Future<List<SharedDraft>> getSharedDrafts() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    try {
      final query = await _firestore
          .collection('shared_drafts')
          .where('receiverId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .get();

      final drafts = <SharedDraft>[];
      for (final doc in query.docs) {
        final draft = _mapSharedDraft(doc.id, doc.data());
        _draftCache[doc.id] = draft;
        drafts.add(draft);
      }

      return drafts;
    } catch (e) {
      print('Error getting shared drafts: $e');
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
      print('Error searching chats: $e');
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
        
        return title.contains(searchQuery) || 
               message.contains(searchQuery);
      }).toList();
    } catch (e) {
      print('Error searching shared drafts: $e');
      return [];
    }
  }

  /// Delete a chat
  Future<bool> deleteChat(String chatId) async {
    try {
      await _firestore.collection('chats').doc(chatId).delete();
      _chatCache.remove(chatId);
      return true;
    } catch (e) {
      print('Error deleting chat: $e');
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
      print('Error deleting multiple chats: $e');
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
      print('Error deleting shared draft: $e');
      return false;
    }
  }

  /// Mark chat as read
  Future<bool> markChatAsRead(String chatId) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'unreadCount': 0,
        'lastReadTimestamp': FieldValue.serverTimestamp(),
      });
      
      // Update cache
      if (_chatCache.containsKey(chatId)) {
        final chat = _chatCache[chatId]!;
        _chatCache[chatId] = chat;
      }
      
      return true;
    } catch (e) {
      print('Error marking chat as read: $e');
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
      print('Error marking all chats as read: $e');
      return false;
    }
  }

  /// Get unread count
  Future<int> getUnreadCount() async {
    try {
      // For now, return 0 since Chat model doesn't have unreadCount
      // This would need to be implemented with a separate unread messages collection
      return 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
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
        final participants = List<String>.from(doc.data()['participants'] ?? []);
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
      print('Error creating chat: $e');
      return null;
    }
  }

  /// Map Firestore document to Chat model
  app_chat.Chat _mapChat(String id, Map<String, dynamic> data) {
    return app_chat.Chat(
      id: id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastTimestamp: (data['lastTimestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      chatType: data['chatType'] ?? 'direct',
    );
  }

  /// Map Firestore document to SharedDraft model
  SharedDraft _mapSharedDraft(String id, Map<String, dynamic> data) {
    return SharedDraft(
      id: id,
      draftId: data['draftId'] ?? '',
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderAvatar: data['senderAvatar'] ?? '',
      draftTitle: data['draftTitle'] ?? '',
      draftThumbnailUrl: data['draftThumbnailUrl'] ?? '',
      draftDuration: data['draftDuration'] ?? 0,
      sharedAt: (data['sharedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: SharedDraftStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => SharedDraftStatus.pending,
      ),
      message: data['message'],
      viewedAt: (data['viewedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Clear cache
  void clearCache() {
    _chatCache.clear();
    _draftCache.clear();
  }
}
