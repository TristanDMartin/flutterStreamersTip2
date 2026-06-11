import 'package:cloud_firestore/cloud_firestore.dart';

enum UserStatus {
  online('online'),
  offline('offline'),
  away('away'),
  busy('busy'),
  streaming('streaming');

  const UserStatus(this.value);
  final String value;

  static const Set<String> validFirestoreValues = <String>{
    'online',
    'offline',
    'away',
    'busy',
    'streaming',
  };

  static bool isValidFirestoreValue(String value) {
    return validFirestoreValues.contains(value);
  }

  static UserStatus fromString(String value) {
    final String normalized = value == 'dnd' ? 'away' : value;
    return UserStatus.values.firstWhere(
      (UserStatus status) => status.value == normalized,
      orElse: () => UserStatus.offline,
    );
  }

  static UserStatus? tryParseFirestoreValue(String value) {
    final String normalized = value == 'dnd' ? 'away' : value;
    if (!isValidFirestoreValue(normalized)) {
      return null;
    }
    return fromString(normalized);
  }

  String get displayName {
    switch (this) {
      case UserStatus.online:
        return 'Online';
      case UserStatus.offline:
        return 'Offline';
      case UserStatus.busy:
        return 'Busy';
      case UserStatus.away:
        return 'Away';
      case UserStatus.streaming:
        return 'Streaming';
    }
  }

  String get icon {
    switch (this) {
      case UserStatus.online:
        return '🟢';
      case UserStatus.offline:
        return '⚫';
      case UserStatus.busy:
        return '🟡';
      case UserStatus.away:
        return '🟠';
      case UserStatus.streaming:
        return '📺';
    }
  }

  String get color {
    switch (this) {
      case UserStatus.online:
        return '#4CAF50'; // Green
      case UserStatus.offline:
        return '#9E9E9E'; // Grey
      case UserStatus.busy:
        return '#FF9800'; // Orange
      case UserStatus.away:
        return '#FF5722'; // Deep orange
      case UserStatus.streaming:
        return '#9C27B0'; // Purple
    }
  }
}

class UserPresence {
  final UserStatus status;
  final DateTime? lastSeen;
  final DateTime? lastActive;

  const UserPresence({
    required this.status,
    this.lastSeen,
    this.lastActive,
  });

  factory UserPresence.fromMap(Map<String, dynamic> data) {
    return UserPresence(
      status: UserStatus.fromString(data['status'] ?? 'offline'),
      lastSeen: data['lastSeen'] != null
          ? (data['lastSeen'] is Timestamp
              ? (data['lastSeen'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(data['lastSeen']))
          : null,
      lastActive: data['lastActive'] != null
          ? (data['lastActive'] is Timestamp
              ? (data['lastActive'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(data['lastActive']))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status.value,
      'lastSeen': lastSeen?.millisecondsSinceEpoch,
      'lastActive': lastActive?.millisecondsSinceEpoch,
    };
  }

  UserPresence copyWith({
    UserStatus? status,
    DateTime? lastSeen,
    DateTime? lastActive,
  }) {
    return UserPresence(
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      lastActive: lastActive ?? this.lastActive,
    );
  }
}

class StatusUpdateOutcome {
  const StatusUpdateOutcome({
    required this.success,
    this.userMessage,
    this.pendingRetry = false,
  });

  final bool success;
  final String? userMessage;
  final bool pendingRetry;

  static const StatusUpdateOutcome ok = StatusUpdateOutcome(success: true);

  static StatusUpdateOutcome failed({
    required String userMessage,
    bool pendingRetry = false,
  }) {
    return StatusUpdateOutcome(
      success: false,
      userMessage: userMessage,
      pendingRetry: pendingRetry,
    );
  }
}
