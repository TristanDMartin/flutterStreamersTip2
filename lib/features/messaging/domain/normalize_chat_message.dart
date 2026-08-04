import 'package:cloud_firestore/cloud_firestore.dart';

import 'messaging_ids.dart';
import 'messaging_message.dart';

/// Normalize legacy + canonical Firestore message docs into one domain model.
MessagingMessage normalizeChatMessage({
  required String docId,
  required String chatId,
  required Map<String, dynamic> raw,
  MessagingSendStatus status = MessagingSendStatus.sent,
  bool isOptimistic = false,
}) {
  final String senderId = _firstNonEmpty(<Object?>[
    raw['senderId'],
    raw['from'],
  ]);
  final String type = _firstNonEmpty(<Object?>[
        raw['type'],
        raw['messageType'],
      ]).isEmpty
      ? 'text'
      : _firstNonEmpty(<Object?>[raw['type'], raw['messageType']]);
  final String clientId = _firstNonEmpty(<Object?>[
    raw['clientId'],
    docId,
  ]);
  final bool isUnsent = raw['isUnsent'] == true ||
      raw['deletedForEveryone'] == true ||
      raw['deleted'] == true;
  final String text = isUnsent
      ? ''
      : (raw['text'] as String?)?.trim() ??
          (raw['previewText'] as String?)?.trim() ??
          '';
  final DateTime createdAt = _readDate(raw['createdAt']) ??
      _readDate(raw['timestamp']) ??
      DateTime.now();
  final DateTime? serverCreatedAt = _readDate(raw['serverCreatedAt']) ??
      _readDate(raw['timestamp']);
  final int schemaVersion = raw['schemaVersion'] is int
      ? raw['schemaVersion'] as int
      : MessagingIds.schemaVersion;

  return MessagingMessage(
    id: docId,
    chatId: chatId,
    senderId: senderId,
    type: type,
    text: text,
    clientId: clientId,
    createdAt: createdAt,
    serverCreatedAt: serverCreatedAt,
    status: status,
    isUnsent: isUnsent,
    unsentAt: _readDate(raw['unsentAt']) ?? _readDate(raw['deletedAt']),
    unsentBy: (raw['unsentBy'] as String?) ?? (raw['deletedBy'] as String?),
    gifUrl: raw['gifUrl'] as String?,
    isOptimistic: isOptimistic,
    schemaVersion: schemaVersion,
  );
}

/// Stable sort: serverCreatedAt → createdAt → clientId.
int compareMessagingMessages(MessagingMessage a, MessagingMessage b) {
  final DateTime aTime = a.serverCreatedAt ?? a.createdAt;
  final DateTime bTime = b.serverCreatedAt ?? b.createdAt;
  final int byTime = aTime.compareTo(bTime);
  if (byTime != 0) {
    return byTime;
  }
  return a.clientId.compareTo(b.clientId);
}

/// Merge server snapshot with optimistic locals (match on clientId).
List<MessagingMessage> reconcileMessagingMessages({
  required List<MessagingMessage> serverMessages,
  required List<MessagingMessage> optimisticMessages,
}) {
  final Map<String, MessagingMessage> byClientId = <String, MessagingMessage>{};
  for (final MessagingMessage message in serverMessages) {
    byClientId[message.clientId] = message;
  }
  for (final MessagingMessage optimistic in optimisticMessages) {
    if (!byClientId.containsKey(optimistic.clientId)) {
      byClientId[optimistic.clientId] = optimistic;
    } else if (optimistic.status == MessagingSendStatus.failed) {
      byClientId[optimistic.clientId] = byClientId[optimistic.clientId]!
          .copyWith(status: MessagingSendStatus.failed);
    }
  }
  final List<MessagingMessage> merged = byClientId.values.toList()
    ..sort(compareMessagingMessages);
  return merged;
}

DateTime? _readDate(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return null;
}

String _firstNonEmpty(List<Object?> values) {
  for (final Object? value in values) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return '';
}
