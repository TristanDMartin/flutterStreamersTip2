/// Phase 1 canonical message domain model (UI-agnostic).
class MessagingMessage {
  const MessagingMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    required this.text,
    required this.clientId,
    required this.createdAt,
    required this.schemaVersion,
    this.serverCreatedAt,
    this.status = MessagingSendStatus.sent,
    this.isUnsent = false,
    this.unsentAt,
    this.unsentBy,
    this.gifUrl,
    this.isOptimistic = false,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String type;
  final String text;
  final String clientId;
  final DateTime createdAt;
  final DateTime? serverCreatedAt;
  final MessagingSendStatus status;
  final bool isUnsent;
  final DateTime? unsentAt;
  final String? unsentBy;
  final String? gifUrl;
  final bool isOptimistic;
  final int schemaVersion;

  MessagingMessage copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? type,
    String? text,
    String? clientId,
    DateTime? createdAt,
    DateTime? serverCreatedAt,
    MessagingSendStatus? status,
    bool? isUnsent,
    DateTime? unsentAt,
    String? unsentBy,
    String? gifUrl,
    bool? isOptimistic,
    int? schemaVersion,
  }) {
    return MessagingMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      type: type ?? this.type,
      text: text ?? this.text,
      clientId: clientId ?? this.clientId,
      createdAt: createdAt ?? this.createdAt,
      serverCreatedAt: serverCreatedAt ?? this.serverCreatedAt,
      status: status ?? this.status,
      isUnsent: isUnsent ?? this.isUnsent,
      unsentAt: unsentAt ?? this.unsentAt,
      unsentBy: unsentBy ?? this.unsentBy,
      gifUrl: gifUrl ?? this.gifUrl,
      isOptimistic: isOptimistic ?? this.isOptimistic,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }
}

enum MessagingSendStatus {
  sending,
  sent,
  failed,
}
