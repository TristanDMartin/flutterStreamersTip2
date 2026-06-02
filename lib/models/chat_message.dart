class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final String messageType;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final bool isRead;
  final bool isEdited;
  final bool isDeleted;
  final DateTime? editedAt;
  final DateTime? deletedAt;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    this.messageType = 'text',
    this.metadata = const {},
    required this.timestamp,
    this.isRead = false,
    this.isEdited = false,
    this.isDeleted = false,
    this.editedAt,
    this.deletedAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      roomId: map['roomId'] ?? '',
      senderId: map['senderId'] ?? '',
      content: map['content'] ?? '',
      messageType: map['messageType'] ?? 'text',
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      timestamp: (map['timestamp'] as DateTime?) ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      isEdited: map['isEdited'] ?? false,
      isDeleted: map['isDeleted'] ?? false,
      editedAt: map['editedAt'] as DateTime?,
      deletedAt: map['deletedAt'] as DateTime?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'roomId': roomId,
      'senderId': senderId,
      'content': content,
      'messageType': messageType,
      'metadata': metadata,
      'timestamp': timestamp,
      'isRead': isRead,
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      'editedAt': editedAt,
      'deletedAt': deletedAt,
    };
  }
}

class ChatRoom {
  final String id;
  final List<String> participants;
  final String roomName;
  final String roomType;
  final DateTime createdAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final bool isActive;
  final String? createdBy;
  final DateTime? updatedAt;

  const ChatRoom({
    required this.id,
    required this.participants,
    required this.roomName,
    this.roomType = 'direct',
    required this.createdAt,
    this.lastMessage,
    this.lastMessageAt,
    this.isActive = true,
    this.createdBy,
    this.updatedAt,
  });

  factory ChatRoom.fromMap(Map<String, dynamic> map) {
    return ChatRoom(
      id: map['id'] ?? '',
      participants: List<String>.from(map['participants'] ?? []),
      roomName: map['roomName'] ?? 'Chat Room',
      roomType: map['roomType'] ?? 'direct',
      createdAt: (map['createdAt'] as DateTime?) ?? DateTime.now(),
      lastMessage: map['lastMessage'],
      lastMessageAt: map['lastMessageAt'] as DateTime?,
      isActive: map['isActive'] ?? true,
      createdBy: map['createdBy'],
      updatedAt: map['updatedAt'] as DateTime?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participants': participants,
      'roomName': roomName,
      'roomType': roomType,
      'createdAt': createdAt,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt,
      'isActive': isActive,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
    };
  }
}
