import 'mission_category.dart';
import 'mission_period.dart';

/// Config-only definition. Server assigns instances + progress + rewards.
class MissionTemplate {
  final String templateId;
  final MissionPeriod period;
  final MissionCategory category;
  final String title;
  final String description;
  final int target;
  final int rewardXp;
  final List<String> progressEventKeys;
  final int priority;

  const MissionTemplate({
    required this.templateId,
    required this.period,
    required this.category,
    required this.title,
    required this.description,
    required this.target,
    required this.rewardXp,
    required this.progressEventKeys,
    this.priority = 0,
  });
}
