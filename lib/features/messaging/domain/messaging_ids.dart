/// Deterministic direct-message chat IDs shared with the website.
class MessagingIds {
  MessagingIds._();

  static const int schemaVersion = 1;
  static const String chatAliasCollection = 'chatAliases';
  static const String chatsCollection = 'chats';
  static const String messagesCollection = 'messages';

  /// Canonical one-to-one chat document ID.
  /// Format: `dm_{lowerUid}_{higherUid}`
  static String directChatId(String userIdA, String userIdB) {
    final String a = userIdA.trim();
    final String b = userIdB.trim();
    if (a.isEmpty || b.isEmpty) {
      throw ArgumentError('Both user IDs are required for a direct chat.');
    }
    if (a == b) {
      throw ArgumentError('Cannot create a direct chat with the same user.');
    }
    final List<String> sorted = <String>[a, b]..sort();
    return 'dm_${sorted[0]}_${sorted[1]}';
  }

  static List<String> sortedParticipantIds(String userIdA, String userIdB) {
    final List<String> sorted = <String>[userIdA.trim(), userIdB.trim()]
      ..sort();
    return sorted;
  }

  /// Resolve a notification / deep-link chat key (chatId | roomId | conversationId).
  static String? resolveDeepLinkChatId(Map<String, dynamic> payload) {
    for (final String key in <String>[
      'chatId',
      'roomId',
      'conversationId',
    ]) {
      final Object? value = payload[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }
}
