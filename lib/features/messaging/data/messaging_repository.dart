import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:uuid/uuid.dart';

import '../domain/messaging_ids.dart';
import '../domain/messaging_message.dart';
import '../domain/normalize_chat_message.dart';

/// Canonical messaging repository. UI should call this instead of Firestore.
///
/// Temporary shared backend dependency: Flutter Cloud Function
/// `onMessageCreate` owns unread increments, chat summary updates, and push.
class MessagingRepository {
  MessagingRepository({
    FirebaseFirestore? firestore,
    firebase_auth.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? firebase_auth.FirebaseAuth.instance;

  static final MessagingRepository instance = MessagingRepository();

  final FirebaseFirestore _firestore;
  final firebase_auth.FirebaseAuth _auth;
  static const Uuid _uuid = Uuid();
  static const int _messagePageSize = 50;
  static const Duration _typingStale = Duration(seconds: 8);

  String createClientId() => _uuid.v4();

  String? get currentUserId => _auth.currentUser?.uid;

  /// Resolve legacy notification/deep-link IDs via chatAliases.
  Future<String> resolveCanonicalChatId(String chatId) async {
    final String trimmed = chatId.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    final DocumentSnapshot<Map<String, dynamic>> chatSnap =
        await _firestore
            .collection(MessagingIds.chatsCollection)
            .doc(trimmed)
            .get();
    if (chatSnap.exists) {
      return trimmed;
    }
    final DocumentSnapshot<Map<String, dynamic>> aliasSnap =
        await _firestore
            .collection(MessagingIds.chatAliasCollection)
            .doc(trimmed)
            .get();
    final Object? canonical = aliasSnap.data()?['canonicalChatId'];
    if (canonical is String && canonical.trim().isNotEmpty) {
      return canonical.trim();
    }
    return trimmed;
  }

  Future<String> getOrCreateDirectChat({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final String chatId =
        MessagingIds.directChatId(currentUserId, otherUserId);
    final List<String> participants =
        MessagingIds.sortedParticipantIds(currentUserId, otherUserId);
    final DocumentReference<Map<String, dynamic>> chatRef =
        _firestore.collection(MessagingIds.chatsCollection).doc(chatId);

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> existing =
          await transaction.get(chatRef);
      if (existing.exists) {
        return;
      }
      transaction.set(chatRef, <String, dynamic>{
        'participants': participants,
        'participantIds': participants,
        'directPairKey': chatId,
        'lastMessage': '',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'chatType': 'direct',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUserId,
        'schemaVersion': MessagingIds.schemaVersion,
        'unreadCount_$currentUserId': 0,
        'unreadCount_$otherUserId': 0,
        'unreadCountByUser': <String, dynamic>{
          currentUserId: 0,
          otherUserId: 0,
        },
        'typing': <String, dynamic>{},
      });
    });

    unawaited(_aliasLegacyDuplicates(
      currentUserId: currentUserId,
      otherUserId: otherUserId,
      canonicalChatId: chatId,
    ));

    return chatId;
  }

  Future<void> _aliasLegacyDuplicates({
    required String currentUserId,
    required String otherUserId,
    required String canonicalChatId,
  }) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(MessagingIds.chatsCollection)
          .where('participants', arrayContains: currentUserId)
          .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        if (doc.id == canonicalChatId) {
          continue;
        }
        final List<dynamic> participants =
            doc.data()['participants'] as List<dynamic>? ?? <dynamic>[];
        if (participants.length == 2 &&
            participants.contains(otherUserId)) {
          await _firestore
              .collection(MessagingIds.chatAliasCollection)
              .doc(doc.id)
              .set(
            <String, dynamic>{
              'canonicalChatId': canonicalChatId,
              'migratedAt': FieldValue.serverTimestamp(),
              'reason': 'duplicate_direct_chat',
            },
            SetOptions(merge: true),
          );
          await _firestore
              .collection(MessagingIds.chatsCollection)
              .doc(doc.id)
              .set(
            <String, dynamic>{
              'supersededBy': canonicalChatId,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }
    } catch (_) {
      // Alias write is best-effort and must not block chat open.
    }
  }

  /// Send text using clientId as the message document ID (idempotent).
  Future<MessagingMessage> sendTextMessage({
    required String chatId,
    required String text,
    String? clientId,
  }) async {
    final String? senderId = currentUserId;
    if (senderId == null) {
      throw StateError('Not signed in');
    }
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Message text is empty');
    }
    final String resolvedClientId = clientId ?? createClientId();
    final DocumentReference<Map<String, dynamic>> messageRef = _firestore
        .collection(MessagingIds.chatsCollection)
        .doc(chatId)
        .collection(MessagingIds.messagesCollection)
        .doc(resolvedClientId);

    final DocumentSnapshot<Map<String, dynamic>> existing =
        await messageRef.get();
    if (existing.exists) {
      return normalizeChatMessage(
        docId: existing.id,
        chatId: chatId,
        raw: existing.data() ?? <String, dynamic>{},
      );
    }

    final Map<String, dynamic> messageData = <String, dynamic>{
      'id': resolvedClientId,
      'chatId': chatId,
      'from': senderId,
      'senderId': senderId,
      'text': trimmed,
      'type': 'text',
      'clientId': resolvedClientId,
      'createdAt': FieldValue.serverTimestamp(),
      'serverCreatedAt': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sent',
      'isUnsent': false,
      'isRead': false,
      'schemaVersion': MessagingIds.schemaVersion,
    };

    await messageRef.set(messageData);

    // Optimistic preview only — CF owns unread + push.
    unawaited(_updateChatPreview(
      chatId: chatId,
      lastMessage: trimmed,
      messageId: resolvedClientId,
      senderId: senderId,
    ));

    return MessagingMessage(
      id: resolvedClientId,
      chatId: chatId,
      senderId: senderId,
      type: 'text',
      text: trimmed,
      clientId: resolvedClientId,
      createdAt: DateTime.now(),
      status: MessagingSendStatus.sent,
      schemaVersion: MessagingIds.schemaVersion,
    );
  }

  Future<void> _updateChatPreview({
    required String chatId,
    required String lastMessage,
    required String messageId,
    required String senderId,
  }) async {
    try {
      await _firestore
          .collection(MessagingIds.chatsCollection)
          .doc(chatId)
          .update(<String, dynamic>{
        'lastMessage': lastMessage,
        'lastTimestamp': FieldValue.serverTimestamp(),
        'lastMessageId': messageId,
        'lastMessageSenderId': senderId,
        'lastMessageType': 'text',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Preview update is best-effort; CF also refreshes summary.
    }
  }

  Stream<List<MessagingMessage>> listenToMessages(String chatId) {
    return _firestore
        .collection(MessagingIds.chatsCollection)
        .doc(chatId)
        .collection(MessagingIds.messagesCollection)
        .orderBy('timestamp', descending: true)
        .limit(_messagePageSize)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
      final List<MessagingMessage> messages = snapshot.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                normalizeChatMessage(
              docId: doc.id,
              chatId: chatId,
              raw: doc.data(),
            ),
          )
          .toList()
        ..sort(compareMessagingMessages);
      return messages;
    });
  }

  Stream<List<Map<String, dynamic>>> listenToInbox(String userId) {
    return _firestore
        .collection(MessagingIds.chatsCollection)
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
      final List<Map<String, dynamic>> chats = snapshot.docs.map(
        (QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          final Map<String, dynamic> data =
              Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          data['unreadCount'] = unreadCountForUser(data, userId);
          return data;
        },
      ).toList();
      chats.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        final DateTime aTime = _readTimestamp(a['lastTimestamp']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime bTime = _readTimestamp(b['lastTimestamp']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return chats;
    });
  }

  int unreadCountForUser(Map<String, dynamic> chat, String userId) {
    final Object? nested = (chat['unreadCountByUser'] is Map)
        ? (chat['unreadCountByUser'] as Map)[userId]
        : null;
    if (nested is int) {
      return nested < 0 ? 0 : nested;
    }
    if (nested is num) {
      return nested.toInt().clamp(0, 1 << 30);
    }
    final Object? legacy = chat['unreadCount_$userId'];
    if (legacy is int) {
      return legacy < 0 ? 0 : legacy;
    }
    if (legacy is num) {
      return legacy.toInt().clamp(0, 1 << 30);
    }
    return 0;
  }

  Future<void> markChatRead({
    required String chatId,
    required String userId,
    String? lastReadMessageId,
  }) async {
    final Map<String, dynamic> update = <String, dynamic>{
      'unreadCount_$userId': 0,
      'unreadCountByUser.$userId': 0,
      'lastReadAtByUser.$userId': FieldValue.serverTimestamp(),
      'lastReadTimestamp': FieldValue.serverTimestamp(),
    };
    if (lastReadMessageId != null && lastReadMessageId.isNotEmpty) {
      update['lastReadMessageIdByUser.$userId'] = lastReadMessageId;
    }
    await _firestore
        .collection(MessagingIds.chatsCollection)
        .doc(chatId)
        .set(update, SetOptions(merge: true));
  }

  Future<void> markChatUnread({
    required String chatId,
    required String userId,
  }) async {
    await _firestore
        .collection(MessagingIds.chatsCollection)
        .doc(chatId)
        .set(
      <String, dynamic>{
        'unreadCount_$userId': 1,
        'unreadCountByUser.$userId': 1,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> unsendMessage({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    final DocumentReference<Map<String, dynamic>> messageRef = _firestore
        .collection(MessagingIds.chatsCollection)
        .doc(chatId)
        .collection(MessagingIds.messagesCollection)
        .doc(messageId);
    final DocumentSnapshot<Map<String, dynamic>> snap = await messageRef.get();
    if (!snap.exists) {
      throw StateError('Message not found');
    }
    final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
    final String senderId = (data['senderId'] as String?) ??
        (data['from'] as String?) ??
        '';
    if (senderId != userId) {
      throw StateError('You can only unsend your own messages');
    }
    // Flutter rules allow participant updates; write canonical + legacy.
    await messageRef.update(<String, dynamic>{
      'isUnsent': true,
      'text': null,
      'unsentAt': FieldValue.serverTimestamp(),
      'unsentBy': userId,
      'deleted': true,
      'deletedForEveryone': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': userId,
    });
  }

  Future<void> setTypingStatus({
    required String chatId,
    required bool isTyping,
  }) async {
    final String? userId = currentUserId;
    if (userId == null || chatId.isEmpty) {
      return;
    }
    await _firestore.collection(MessagingIds.chatsCollection).doc(chatId).set(
      <String, dynamic>{
        'typing.$userId': <String, dynamic>{
          'isTyping': isTyping,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      },
      SetOptions(merge: true),
    );
  }

  Stream<bool> listenToTypingStatus({
    required String chatId,
    required String userId,
  }) {
    return _firestore
        .collection(MessagingIds.chatsCollection)
        .doc(chatId)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> doc) {
      if (!doc.exists) {
        return false;
      }
      final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
      final Object? typingRaw = data['typing'];
      if (typingRaw is Map) {
        final Object? entry = typingRaw[userId];
        if (entry == true) {
          return true;
        }
        if (entry is Map) {
          final bool active = entry['isTyping'] == true;
          if (!active) {
            return false;
          }
          final DateTime? updatedAt = _readTimestamp(entry['updatedAt']);
          if (updatedAt == null) {
            return true;
          }
          return DateTime.now().difference(updatedAt) < _typingStale;
        }
      }
      // Legacy flat fields during migration.
      if (data['typing_$userId'] == true) {
        final DateTime? updatedAt =
            _readTimestamp(data['typingTimestamp_$userId']);
        if (updatedAt == null) {
          return true;
        }
        return DateTime.now().difference(updatedAt) < _typingStale;
      }
      return false;
    });
  }

  DateTime? _readTimestamp(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
