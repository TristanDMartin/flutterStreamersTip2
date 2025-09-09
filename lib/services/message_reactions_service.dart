import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'logging_service.dart';

class MessageReactionsService {
  static final MessageReactionsService _instance = MessageReactionsService._internal();
  factory MessageReactionsService() => _instance;
  MessageReactionsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  // Available reaction types
  static const List<String> availableReactions = [
    '👍', '👎', '❤️', '😂', '😮', '😢', '😡', '🎉', '🔥', '💯'
  ];

  /// Add reaction to message
  Future<bool> addReaction(String chatId, String messageId, String reaction) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final reactionData = {
        'userId': currentUser.uid,
        'reaction': reaction,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .collection('reactions')
          .doc(currentUser.uid)
          .set(reactionData);

      LoggingService.instance.info('Reaction added: $reaction to message $messageId');
      return true;
    } catch (e) {
      LoggingService.instance.error('Error adding reaction: $e');
      return false;
    }
  }

  /// Remove reaction from message
  Future<bool> removeReaction(String chatId, String messageId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .collection('reactions')
          .doc(currentUser.uid)
          .delete();

      LoggingService.instance.info('Reaction removed from message $messageId');
      return true;
    } catch (e) {
      LoggingService.instance.error('Error removing reaction: $e');
      return false;
    }
  }

  /// Get reactions for a message
  Future<Map<String, int>> getMessageReactions(String chatId, String messageId) async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .collection('reactions')
          .get();

      final reactions = <String, int>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final reaction = data['reaction'] as String;
        reactions[reaction] = (reactions[reaction] ?? 0) + 1;
      }

      return reactions;
    } catch (e) {
      LoggingService.instance.error('Error getting message reactions: $e');
      return {};
    }
  }

  /// Stream reactions for a message
  Stream<Map<String, int>> streamMessageReactions(String chatId, String messageId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .collection('reactions')
        .snapshots()
        .map((snapshot) {
      final reactions = <String, int>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final reaction = data['reaction'] as String;
        reactions[reaction] = (reactions[reaction] ?? 0) + 1;
      }
      return reactions;
    });
  }

  /// Get user's reaction to a message
  Future<String?> getUserReaction(String chatId, String messageId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    try {
      final doc = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .collection('reactions')
          .doc(currentUser.uid)
          .get();

      if (doc.exists) {
        return doc.data()?['reaction'] as String?;
      }
      return null;
    } catch (e) {
      LoggingService.instance.error('Error getting user reaction: $e');
      return null;
    }
  }

  /// Stream user's reaction to a message
  Stream<String?> streamUserReaction(String chatId, String messageId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value(null);

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .collection('reactions')
        .doc(currentUser.uid)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return doc.data()?['reaction'] as String?;
      }
      return null;
    });
  }

  /// Get most popular reactions for a chat
  Future<Map<String, int>> getChatPopularReactions(String chatId, {int limit = 5}) async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      final allReactions = <String, int>{};
      
      for (final messageDoc in snapshot.docs) {
        final reactionsSnapshot = await messageDoc.reference
            .collection('reactions')
            .get();
            
        for (final reactionDoc in reactionsSnapshot.docs) {
          final data = reactionDoc.data();
          final reaction = data['reaction'] as String;
          allReactions[reaction] = (allReactions[reaction] ?? 0) + 1;
        }
      }

      // Sort by count and return top reactions
      final sortedReactions = Map.fromEntries(
        allReactions.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value))
      );

      return Map.fromEntries(
        sortedReactions.entries.take(limit)
      );
    } catch (e) {
      LoggingService.instance.error('Error getting chat popular reactions: $e');
      return {};
    }
  }

  /// Get reaction statistics for a user
  Future<Map<String, int>> getUserReactionStats(String userId) async {
    try {
      final snapshot = await _firestore
          .collectionGroup('reactions')
          .where('userId', isEqualTo: userId)
          .get();

      final stats = <String, int>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final reaction = data['reaction'] as String;
        stats[reaction] = (stats[reaction] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      LoggingService.instance.error('Error getting user reaction stats: $e');
      return {};
    }
  }

  /// Clear all reactions from a message
  Future<bool> clearMessageReactions(String chatId, String messageId) async {
    try {
      final batch = _firestore.batch();
      final reactionsSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .collection('reactions')
          .get();

      for (final doc in reactionsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      LoggingService.instance.info('All reactions cleared from message $messageId');
      return true;
    } catch (e) {
      LoggingService.instance.error('Error clearing message reactions: $e');
      return false;
    }
  }

  /// Get reaction emoji by name
  static String getReactionEmoji(String reactionName) {
    switch (reactionName.toLowerCase()) {
      case 'like':
      case 'thumbs_up':
        return '👍';
      case 'dislike':
      case 'thumbs_down':
        return '👎';
      case 'love':
      case 'heart':
        return '❤️';
      case 'laugh':
      case 'lol':
        return '😂';
      case 'wow':
      case 'surprised':
        return '😮';
      case 'sad':
      case 'cry':
        return '😢';
      case 'angry':
      case 'mad':
        return '😡';
      case 'celebration':
      case 'party':
        return '🎉';
      case 'fire':
      case 'hot':
        return '🔥';
      case 'hundred':
      case 'perfect':
        return '💯';
      default:
        return reactionName; // Return as-is if not recognized
    }
  }

  /// Get reaction name by emoji
  static String getReactionName(String emoji) {
    switch (emoji) {
      case '👍':
        return 'like';
      case '👎':
        return 'dislike';
      case '❤️':
        return 'love';
      case '😂':
        return 'laugh';
      case '😮':
        return 'wow';
      case '😢':
        return 'sad';
      case '😡':
        return 'angry';
      case '🎉':
        return 'celebration';
      case '🔥':
        return 'fire';
      case '💯':
        return 'hundred';
      default:
        return emoji;
    }
  }
}
