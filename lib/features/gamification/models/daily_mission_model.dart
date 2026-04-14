import '../gamification_firestore_utils.dart';

/// Mission row — server-owned progress; optional [templateId] links to config.
class DailyMissionModel {
  final String missionId;
  final String? templateId;
  final String? missionCategoryKey;
  final String type;
  final String status;
  final String title;
  final String description;
  final String objectiveType;
  final int target;
  final int progress;
  final int rewardXp;
  final DateTime startsAt;
  final DateTime expiresAt;
  final DateTime? completedAt;
  final bool rewardClaimed;

  const DailyMissionModel({
    required this.missionId,
    this.templateId,
    this.missionCategoryKey,
    required this.type,
    required this.status,
    required this.title,
    required this.description,
    required this.objectiveType,
    required this.target,
    required this.progress,
    required this.rewardXp,
    required this.startsAt,
    required this.expiresAt,
    this.completedAt,
    this.rewardClaimed = false,
  });

  double get completionPercent =>
      target <= 0 ? 0 : (progress / target).clamp(0.0, 1.0);

  bool get isCompleted =>
      status == 'completed' ||
      status == 'claimed' ||
      (progress >= target && target > 0);

  bool get isClaimed =>
      rewardClaimed || status == 'claimed' || status == 'rewarded';

  factory DailyMissionModel.fromFirestoreMap(Map<String, dynamic> raw) {
    return DailyMissionModel(
      missionId: raw['missionId'] as String? ?? raw['id'] as String? ?? '',
      templateId: raw['templateId'] as String? ?? raw['template_id'] as String?,
      missionCategoryKey: raw['missionCategory'] as String? ??
          raw['mission_category'] as String?,
      type: raw['type'] as String? ?? 'daily',
      status: raw['status'] as String? ?? 'active',
      title: raw['title'] as String? ?? 'Mission',
      description: raw['description'] as String? ?? '',
      objectiveType: raw['objectiveType'] as String? ??
          raw['objective_type'] as String? ??
          'unknown',
      target: _readInt(raw['target']) ?? 1,
      progress: _readInt(raw['progress']) ?? 0,
      rewardXp: _readInt(raw['rewardXp']) ?? _readInt(raw['reward_xp']) ?? 0,
      startsAt: readFirestoreDate(raw['startsAt']) ?? DateTime.now(),
      expiresAt: readFirestoreDate(raw['expiresAt']) ??
          DateTime.now().add(const Duration(days: 1)),
      completedAt: readFirestoreDate(raw['completedAt']),
      rewardClaimed: raw['rewardClaimed'] as bool? ??
          raw['reward_claimed'] as bool? ??
          false,
    );
  }

  static int? _readInt(Object? v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.round();
    return null;
  }
}
