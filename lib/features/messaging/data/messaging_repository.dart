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
    final String canonicalId =
        MessagingIds.directChatId(currentUserId, otherUserId);
    final List<String> participants =
        MessagingIds.sortedParticipantIds(currentUserId, otherUserId);
    final DocumentReference<Map<String, dynamic>> canonicalRef =
        _firestore.collection(MessagingIds.chatsCollection).doc(canonicalId);

    // Prefer an existing live direct chat (legacy auto-ID or canonical).
    // Do not hide legacy history behind an empty dm_* document.
    final String? existingId = await _findExistingDirectChatId(
      currentUserId: currentUserId,
      otherUserId: otherUserId,
      preferredCanonicalId: canonicalId,
    );
    if (existingId != null && existingId.isNotEmpty) {
      if (existingId != canonicalId) {
        unawaited(_writeAliasOnly(
          legacyChatId: existingId,
          canonicalChatId: canonicalId,
        ));
      }
      return existingId;
    }

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> existing =
          await transaction.get(canonicalRef);
      if (existing.exists) {
        return;
      }
      transaction.set(canonicalRef, <String, dynamic>{
        'participants': participants,
        'participantIds': participants,
        'directPairKey': canonicalId,
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

    return canonicalId;
  }

  Future<String?> _findExistingDirectChatId({
    required String currentUserId,
    required String otherUserId,
    required String preferredCanonicalId,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection(MessagingIds.chatsCollection)
        .where('participants', arrayContains: currentUserId)
        .get();
    QueryDocumentSnapshot<Map<String, dynamic>>? bestDoc;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final List<dynamic> participants =
          data['participants'] as List<dynamic>? ?? <dynamic>[];
      if (participants.length != 2 || !participants.contains(otherUserId)) {
        continue;
      }
      if (bestDoc == null) {
        bestDoc = doc;
        continue;
      }
      final Map<String, dynamic> bestData = bestDoc.data();
      final String bestMessage = (bestData['lastMessage'] as String?) ?? '';
      final String candidateMessage = (data['lastMessage'] as String?) ?? '';
      final DateTime? bestTs = _readTimestamp(bestData['lastTimestamp']);
      final DateTime? candidateTs = _readTimestamp(data['lastTimestamp']);
      // Prefer threads with history, then newer activity, then canonical id.
      if (candidateMessage.isNotEmpty && bestMessage.isEmpty) {
        bestDoc = doc;
      } else if (candidateMessage.isEmpty && bestMessage.isNotEmpty) {
        continue;
      } else if (candidateTs != null &&
          (bestTs == null || candidateTs.isAfter(bestTs))) {
        bestDoc = doc;
      } else if (doc.id == preferredCanonicalId &&
          bestDoc.id != preferredCanonicalId &&
          candidateMessage.isNotEmpty == bestMessage.isNotEmpty) {
        bestDoc = doc;
      }
    }
    if (bestDoc == null) {
      return null;
    }
    if (bestDoc.data()['supersededBy'] != null) {
      unawaited(_clearSupersededBy(bestDoc.id));
    }
    return bestDoc.id;
  }

  Future<void> _clearSupersededBy(String chatId) async {
    try {
      await _firestore
          .collection(MessagingIds.chatsCollection)
          .doc(chatId)
          .update(<String, dynamic>{
        'supersededBy': FieldValue.delete(),
      });
    } catch (_) {
      // Best-effort recovery for Phase 1 supersede mistakes.
    }
  }

  /// Deep-link compatibility only — does not hide the legacy inbox row.
  Future<void> _writeAliasOnly({
    required String legacyChatId,
    required String canonicalChatId,
  }) async {
    if (legacyChatId.isEmpty ||
        canonicalChatId.isEmpty ||
        legacyChatId == canonicalChatId) {
      return;
    }
    try {
      await _firestore
          .collection(MessagingIds.chatAliasCollection)
          .doc(legacyChatId)
          .set(
        <String, dynamic>{
          'canonicalChatId': canonicalChatId,
          'migratedAt': FieldValue.serverTimestamp(),
          'reason': 'duplicate_direct_chat',
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Alias write is best-effort.
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
        // Re-show conversation if this user soft-hid it from Inbox.
        'deletedFor': FieldValue.arrayRemove(<String>[senderId]),
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
      final List<Map<String, dynamic>> chats = snapshot.docs
          .map(
        (QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          final Map<String, dynamic> data =
              Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          data['unreadCount'] = unreadCountForUser(data, userId);
          return data;
        },
      )
          .where((Map<String, dynamic> chat) {
        if (chat['supersededBy'] != null) {
          return false;
        }
        final Object? deletedRaw = chat['deletedFor'];
        if (deletedRaw is List &&
            deletedRaw.map((Object? e) => e.toString()).contains(userId)) {
          return false;
        }
        return true;
      }).toList();
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
    // Optimistic preview repair — CF onMessageUpdate is canonical.
    unawaited(_rebuildChatPreviewAfterUnsend(
      chatId: chatId,
      unsentMessageId: messageId,
    ));
  }

  Future<void> _rebuildChatPreviewAfterUnsend({
    required String chatId,
    required String unsentMessageId,
  }) async {
    try {
      final DocumentReference<Map<String, dynamic>> chatRef = _firestore
          .collection(MessagingIds.chatsCollection)
          .doc(chatId);
      final DocumentSnapshot<Map<String, dynamic>> chatSnap =
          await chatRef.get();
      if (!chatSnap.exists) {
        return;
      }
      final Map<String, dynamic> chatData =
          chatSnap.data() ?? <String, dynamic>{};
      final String lastMessageId =
          (chatData['lastMessageId'] as String?) ?? '';
      if (lastMessageId.isNotEmpty && lastMessageId != unsentMessageId) {
        return;
      }
      final QuerySnapshot<Map<String, dynamic>> messagesSnap = await chatRef
          .collection(MessagingIds.messagesCollection)
          .orderBy('timestamp', descending: true)
          .limit(40)
          .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in messagesSnap.docs) {
        final Map<String, dynamic> data = doc.data();
        if (data['isUnsent'] == true ||
            data['deleted'] == true ||
            data['deletedForEveryone'] == true) {
          continue;
        }
        final String text =
            (data['text'] as String?)?.trim() ?? '';
        final String preview = text.isNotEmpty
            ? text
            : (data['gifUrl'] != null
                ? 'Sent a GIF'
                : ((data['type'] == 'video_share' ||
                        data['messageType'] == 'video_share')
                    ? 'Shared a video'
                    : 'Message'));
        final String senderId = (data['senderId'] as String?) ??
            (data['from'] as String?) ??
            '';
        await chatRef.update(<String, dynamic>{
          'lastMessage': preview,
          'lastMessageId': doc.id,
          'lastMessageSenderId': senderId,
          'lastMessageType':
              (data['type'] as String?) ??
                  (data['messageType'] as String?) ??
                  'text',
          'lastTimestamp':
              data['timestamp'] ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }
      await chatRef.update(<String, dynamic>{
        'lastMessage': '',
        'lastMessageId': '',
        'lastMessageSenderId': '',
        'lastMessageType': 'text',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // CF onMessageUpdate repairs if this fails.
    }
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
