import '../models/daily_mission_model.dart';
import '../models/user_progress_bundle.dart';
import 'mission_period.dart';
import 'mission_template.dart';
import 'mission_templates_config.dart';

/// Template selection + UI placeholders. Server remains source of truth for
/// progress, XP grants, and duplicate reward prevention (`eventId`).
class MissionEngine {
  MissionEngine._();

  static const int defaultDailyPickCount = 3;
  static const int defaultWeeklyPickCount = 3;

  static MissionTemplate? templateById(String templateId) {
    for (final MissionTemplate t in MissionTemplatesConfig.all) {
      if (t.templateId == templateId) {
        return t;
      }
    }
    return null;
  }

  /// Deterministic daily picks (when Firestore has not materialized missions yet).
  static List<MissionTemplate> pickDailyTemplates(
    String userId,
    DateTime now, {
    int count = defaultDailyPickCount,
  }) {
    final List<MissionTemplate> pool =
        MissionTemplatesConfig.byPeriod(MissionPeriod.daily);
    return _pickRotated(pool, count, _seed(userId, _utcDayKey(now)));
  }

  /// Deterministic weekly picks.
  static List<MissionTemplate> pickWeeklyTemplates(
    String userId,
    DateTime now, {
    int count = defaultWeeklyPickCount,
  }) {
    final List<MissionTemplate> pool =
        MissionTemplatesConfig.byPeriod(MissionPeriod.weekly);
    return _pickRotated(pool, count, _seed(userId, _utcWeekKey(now)));
  }

  static List<MissionTemplate> onboardingTemplates() =>
      MissionTemplatesConfig.byPeriod(MissionPeriod.onboarding);

  /// Build UI sections: merge Firestore missions with template slots so completed
  /// / in-progress server rows show real [progress] and [status], and remaining
  /// slots show placeholders at 0%.
  static List<MissionSection> resolveSections(
    UserProgressBundle bundle,
    String userId,
    DateTime now,
  ) {
    if (bundle.missions.isEmpty) {
      return _placeholderOnlySections(userId, now);
    }
    return _sectionsMergedWithTemplates(bundle.missions, userId, now);
  }

  static List<MissionSection> _placeholderOnlySections(
    String userId,
    DateTime now,
  ) {
    final List<DailyMissionModel> daily = pickDailyTemplates(userId, now)
        .map((MissionTemplate t) => templateToPlaceholder(t, userId, now))
        .toList();
    final List<DailyMissionModel> weekly = pickWeeklyTemplates(userId, now)
        .map((MissionTemplate t) => templateToPlaceholder(t, userId, now))
        .toList();
    final List<DailyMissionModel> onboard = onboardingTemplates()
        .map((MissionTemplate t) => templateToPlaceholder(t, userId, now))
        .toList();
    return <MissionSection>[
      MissionSection(title: 'Today', missions: daily),
      MissionSection(title: 'This week', missions: weekly),
      if (onboard.isNotEmpty)
        MissionSection(title: 'Getting started', missions: onboard),
    ];
  }

  static List<MissionSection> _sectionsMergedWithTemplates(
    List<DailyMissionModel> server,
    String userId,
    DateTime now,
  ) {
    final Map<String, List<DailyMissionModel>> buckets =
        <String, List<DailyMissionModel>>{};
    for (final DailyMissionModel m in server) {
      final String key = _normalizeType(m.type);
      buckets.putIfAbsent(key, () => <DailyMissionModel>[]).add(m);
    }
    const Set<String> handled = <String>{
      'daily',
      'weekly',
      'onboarding',
      'milestone',
    };
    final List<MissionSection> out = <MissionSection>[];
    void addSection(
        String bucketKey, String title, List<MissionTemplate> pool) {
      final List<DailyMissionModel>? bucket = buckets[bucketKey];
      final List<DailyMissionModel> merged = _mergeBucketWithTemplates(
        bucket ?? <DailyMissionModel>[],
        pool,
        userId,
        now,
      );
      if (merged.isEmpty) return;
      out.add(MissionSection(title: title, missions: merged));
    }

    addSection('daily', 'Today', pickDailyTemplates(userId, now));
    addSection('weekly', 'This week', pickWeeklyTemplates(userId, now));
    addSection('onboarding', 'Getting started', onboardingTemplates());
    addSection('milestone', 'Milestones', <MissionTemplate>[]);
    for (final MapEntry<String, List<DailyMissionModel>> e in buckets.entries) {
      if (handled.contains(e.key)) continue;
      out.add(
        MissionSection(
          title: e.key,
          missions: _sortMissionsForDisplay(e.value),
        ),
      );
    }
    return out;
  }

  static List<DailyMissionModel> _mergeBucketWithTemplates(
    List<DailyMissionModel> serverRows,
    List<MissionTemplate> templates,
    String userId,
    DateTime now,
  ) {
    if (templates.isEmpty) {
      return _sortMissionsForDisplay(serverRows);
    }
    final Map<String, DailyMissionModel> byTemplateId =
        <String, DailyMissionModel>{};
    final List<DailyMissionModel> withoutTemplate = <DailyMissionModel>[];
    for (final DailyMissionModel m in serverRows) {
      final String? tid = m.templateId;
      if (tid != null && tid.isNotEmpty) {
        byTemplateId[tid] = m;
      } else {
        withoutTemplate.add(m);
      }
    }
    final Set<String> templateIdsInPool =
        templates.map((MissionTemplate t) => t.templateId).toSet();
    final List<DailyMissionModel> out = <DailyMissionModel>[];
    for (final MissionTemplate t in templates) {
      final DailyMissionModel? row = byTemplateId[t.templateId];
      if (row != null) {
        out.add(row);
      } else {
        out.add(templateToPlaceholder(t, userId, now));
      }
    }
    for (final DailyMissionModel m in serverRows) {
      final String? tid = m.templateId;
      if (tid == null || tid.isEmpty) continue;
      if (!templateIdsInPool.contains(tid)) {
        out.add(m);
      }
    }
    out.addAll(withoutTemplate);
    return _sortMissionsForDisplay(out);
  }

  static List<DailyMissionModel> _sortMissionsForDisplay(
    List<DailyMissionModel> missions,
  ) {
    final List<DailyMissionModel> active = <DailyMissionModel>[];
    final List<DailyMissionModel> done = <DailyMissionModel>[];
    for (final DailyMissionModel m in missions) {
      if (m.isClaimed || m.isCompleted) {
        done.add(m);
      } else {
        active.add(m);
      }
    }
    active.sort(
      (DailyMissionModel a, DailyMissionModel b) =>
          b.completionPercent.compareTo(a.completionPercent),
    );
    done.sort((DailyMissionModel a, DailyMissionModel b) {
      final DateTime? ca = a.completedAt;
      final DateTime? cb = b.completedAt;
      if (ca == null && cb == null) return 0;
      if (ca == null) return 1;
      if (cb == null) return -1;
      return cb.compareTo(ca);
    });
    return <DailyMissionModel>[...active, ...done];
  }

  static String _normalizeType(String type) {
    final String t = type.toLowerCase();
    if (t.contains('week')) return 'weekly';
    if (t.contains('onboard')) return 'onboarding';
    if (t.contains('mile')) return 'milestone';
    return 'daily';
  }

  static DailyMissionModel templateToPlaceholder(
    MissionTemplate template,
    String userId,
    DateTime now,
  ) {
    final String periodKey = template.period == MissionPeriod.weekly
        ? _utcWeekKey(now)
        : _utcDayKey(now);
    final String missionId = '${template.templateId}_${userId}_$periodKey';
    return DailyMissionModel(
      missionId: missionId,
      templateId: template.templateId,
      missionCategoryKey: template.category.name,
      type: template.period == MissionPeriod.weekly
          ? 'weekly'
          : template.period == MissionPeriod.onboarding
              ? 'onboarding'
              : 'daily',
      status: 'pending',
      title: template.title,
      description: template.description,
      objectiveType: 'count',
      target: template.target,
      progress: 0,
      rewardXp: template.rewardXp,
      startsAt: now.toUtc(),
      expiresAt: template.period == MissionPeriod.weekly
          ? _endOfUtcWeek(now)
          : _endOfUtcDay(now),
      completedAt: null,
      rewardClaimed: false,
    );
  }

  static List<MissionTemplate> _pickRotated(
    List<MissionTemplate> pool,
    int count,
    int seed,
  ) {
    if (pool.isEmpty) {
      return <MissionTemplate>[];
    }
    final List<MissionTemplate> sorted = List<MissionTemplate>.from(pool)
      ..sort(
        (MissionTemplate a, MissionTemplate b) =>
            b.priority.compareTo(a.priority),
      );
    final int n = sorted.length;
    final int take = count < n ? count : n;
    final int start = seed.abs() % n;
    return List<MissionTemplate>.generate(
      take,
      (int i) => sorted[(start + i) % n],
    );
  }

  static int _seed(String a, String b) => Object.hash(a, b);

  static String _utcDayKey(DateTime now) {
    final DateTime u = now.toUtc();
    final String m = u.month.toString().padLeft(2, '0');
    final String d = u.day.toString().padLeft(2, '0');
    return '${u.year}-$m-$d';
  }

  static String _utcWeekKey(DateTime now) {
    final DateTime u = now.toUtc();
    final int w = _isoWeekNumber(u);
    return '${u.year}-W$w';
  }

  static int _isoWeekNumber(DateTime d) {
    final DateTime thursday = d.add(Duration(days: 3 - ((d.weekday + 6) % 7)));
    final DateTime firstThursday = DateTime(thursday.year, 1, 4);
    return 1 + (thursday.difference(firstThursday).inDays ~/ 7);
  }

  static DateTime _endOfUtcDay(DateTime now) {
    final DateTime u = now.toUtc();
    return DateTime.utc(u.year, u.month, u.day, 23, 59, 59);
  }

  static DateTime _endOfUtcWeek(DateTime now) {
    final DateTime u = now.toUtc();
    final int daysToSunday = 7 - u.weekday;
    final DateTime sunday = DateTime.utc(
      u.year,
      u.month,
      u.day,
    ).add(Duration(days: daysToSunday));
    return DateTime.utc(
      sunday.year,
      sunday.month,
      sunday.day,
      23,
      59,
      59,
    );
  }
}

class MissionSection {
  final String title;
  final List<DailyMissionModel> missions;

  const MissionSection({
    required this.title,
    required this.missions,
  });
}
