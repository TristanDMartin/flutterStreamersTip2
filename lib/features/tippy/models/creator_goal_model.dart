import 'package:cloud_firestore/cloud_firestore.dart';

class CreatorGoalModel {
  const CreatorGoalModel({
    required this.id,
    required this.uid,
    required this.type,
    required this.title,
    this.platform,
    this.targetValue,
    this.currentValue = 0,
    this.unit,
    this.deadlineAt,
    this.status = 'active',
    this.priority = 1,
  });

  final String id;
  final String uid;
  final String type;
  final String title;
  final String? platform;
  final int? targetValue;
  final int currentValue;
  final String? unit;
  final DateTime? deadlineAt;
  final String status;
  final int priority;

  int? get progressPercent {
    final int? target = targetValue;
    if (target == null || target <= 0) {
      return null;
    }
    return ((currentValue / target) * 100).clamp(0, 100).round();
  }

  factory CreatorGoalModel.fromFirestore(String id, Map<String, dynamic> raw) {
    return CreatorGoalModel(
      id: id,
      uid: (raw['uid'] as String?) ?? '',
      type: (raw['type'] as String?) ?? 'custom',
      title: (raw['title'] as String?) ?? 'Goal',
      platform: raw['platform'] as String?,
      targetValue: _readInt(raw['targetValue']),
      currentValue: _readInt(raw['currentValue']) ?? 0,
      unit: raw['unit'] as String?,
      deadlineAt: _readDate(raw['deadlineAt']),
      status: (raw['status'] as String?) ?? 'active',
      priority: _readInt(raw['priority']) ?? 1,
    );
  }

  Map<String, dynamic> toWritePayload() {
    return <String, dynamic>{
      'uid': uid,
      'type': type,
      'title': title,
      if (platform != null && platform!.isNotEmpty) 'platform': platform,
      if (targetValue != null) 'targetValue': targetValue,
      'currentValue': currentValue,
      if (unit != null) 'unit': unit,
      if (deadlineAt != null) 'deadlineAt': Timestamp.fromDate(deadlineAt!),
      'status': status,
      'priority': priority,
      'source': 'user',
      'tippyAnchored': true,
    };
  }

  static int? _readInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw);
    }
    return null;
  }

  static DateTime? _readDate(Object? raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    return null;
  }
}
