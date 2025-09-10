import 'package:cloud_firestore/cloud_firestore.dart';

class BookmarkEvent {
  final String eventId;
  final String creatorId;
  final String title;
  final DateTime startAt;
  final DateTime notifyAt;
  final bool notify;
  final DateTime createdAt;
  final String? scheduledTaskId;
  final String source;

  const BookmarkEvent({
    required this.eventId,
    required this.creatorId,
    required this.title,
    required this.startAt,
    required this.notifyAt,
    this.notify = true,
    required this.createdAt,
    this.scheduledTaskId,
    this.source = 'streamerCardBackView',
  });

  factory BookmarkEvent.fromMap(Map<String, dynamic> map) {
    return BookmarkEvent(
      eventId: map['eventId'] as String,
      creatorId: map['creatorId'] as String,
      title: map['title'] as String,
      startAt: (map['startAt'] as Timestamp).toDate(),
      notifyAt: (map['notifyAt'] as Timestamp).toDate(),
      notify: map['notify'] as bool? ?? true,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      scheduledTaskId: map['scheduledTaskId'] as String?,
      source: map['source'] as String? ?? 'streamerCardBackView',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'creatorId': creatorId,
      'title': title,
      'startAt': Timestamp.fromDate(startAt),
      'notifyAt': Timestamp.fromDate(notifyAt),
      'notify': notify,
      'createdAt': Timestamp.fromDate(createdAt),
      'scheduledTaskId': scheduledTaskId,
      'source': source,
    };
  }

  BookmarkEvent copyWith({
    String? eventId,
    String? creatorId,
    String? title,
    DateTime? startAt,
    DateTime? notifyAt,
    bool? notify,
    DateTime? createdAt,
    String? scheduledTaskId,
    String? source,
  }) {
    return BookmarkEvent(
      eventId: eventId ?? this.eventId,
      creatorId: creatorId ?? this.creatorId,
      title: title ?? this.title,
      startAt: startAt ?? this.startAt,
      notifyAt: notifyAt ?? this.notifyAt,
      notify: notify ?? this.notify,
      createdAt: createdAt ?? this.createdAt,
      scheduledTaskId: scheduledTaskId ?? this.scheduledTaskId,
      source: source ?? this.source,
    );
  }

  // Helper method to determine event status
  EventStatus get status {
    final now = DateTime.now();
    final timeDiff = startAt.difference(now);
    
    if (timeDiff.isNegative) {
      return EventStatus.past;
    } else if (timeDiff.inMinutes <= 30) {
      return EventStatus.live;
    } else {
      return EventStatus.upcoming;
    }
  }

  // Helper method to format time for display
  String get formattedStartTime {
    final now = DateTime.now();
    final timeDiff = startAt.difference(now);
    
    if (timeDiff.isNegative) {
      return 'Past';
    } else if (timeDiff.inDays > 0) {
      return '${timeDiff.inDays}d';
    } else if (timeDiff.inHours > 0) {
      return '${timeDiff.inHours}h';
    } else if (timeDiff.inMinutes > 0) {
      return '${timeDiff.inMinutes}m';
    } else {
      return 'Now';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookmarkEvent && other.eventId == eventId;
  }

  @override
  int get hashCode => eventId.hashCode;

  @override
  String toString() {
    return 'BookmarkEvent(eventId: $eventId, creatorId: $creatorId, title: $title, startAt: $startAt, notifyAt: $notifyAt, notify: $notify, createdAt: $createdAt, scheduledTaskId: $scheduledTaskId, source: $source)';
  }
}

enum EventStatus {
  upcoming,
  live,
  past,
}

extension EventStatusExtension on EventStatus {
  String get displayName {
    switch (this) {
      case EventStatus.upcoming:
        return 'Upcoming';
      case EventStatus.live:
        return 'Live';
      case EventStatus.past:
        return 'Past';
    }
  }

  String get chipColor {
    switch (this) {
      case EventStatus.upcoming:
        return 'blue';
      case EventStatus.live:
        return 'green';
      case EventStatus.past:
        return 'gray';
    }
  }
}
