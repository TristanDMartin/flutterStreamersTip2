/// Growth OS levels from `GET /api/user/entitlements` (website SoT).
/// Prefer these over inventing local tier tables for report/brief depth.
class GrowthEntitlementLevels {
  const GrowthEntitlementLevels({
    required this.dailyBriefLevel,
    required this.creatorMemoryLevel,
    required this.creatorScoreLevel,
    required this.weeklyReportLevel,
    required this.academyAccessLevel,
  });

  final String dailyBriefLevel;
  final String creatorMemoryLevel;
  final String creatorScoreLevel;
  final String weeklyReportLevel;
  final String academyAccessLevel;

  bool get hasGrowthWeeklyReport =>
      weeklyReportLevel == 'growth' || weeklyReportLevel == 'business';

  bool get hasBusinessWeeklyReport => weeklyReportLevel == 'business';

  factory GrowthEntitlementLevels.forTierApi(String tierApi) {
    switch (tierApi.trim().toLowerCase()) {
      case 'studio':
        return const GrowthEntitlementLevels(
          dailyBriefLevel: 'business',
          creatorMemoryLevel: 'business',
          creatorScoreLevel: 'advanced',
          weeklyReportLevel: 'business',
          academyAccessLevel: 'professional',
        );
      case 'pro':
        return const GrowthEntitlementLevels(
          dailyBriefLevel: 'advanced',
          creatorMemoryLevel: 'persistent',
          creatorScoreLevel: 'detailed',
          weeklyReportLevel: 'growth',
          academyAccessLevel: 'full',
        );
      default:
        return const GrowthEntitlementLevels(
          dailyBriefLevel: 'basic',
          creatorMemoryLevel: 'basic',
          creatorScoreLevel: 'basic',
          weeklyReportLevel: 'basic',
          academyAccessLevel: 'foundation',
        );
    }
  }

  factory GrowthEntitlementLevels.fromJson(
    Map<String, dynamic>? raw, {
    required String tierApi,
  }) {
    final GrowthEntitlementLevels fallback = GrowthEntitlementLevels.forTierApi(
      tierApi,
    );
    if (raw == null || raw.isEmpty) {
      return fallback;
    }
    return GrowthEntitlementLevels(
      dailyBriefLevel: _readLevel(
        raw['dailyBriefLevel'],
        fallback.dailyBriefLevel,
      ),
      creatorMemoryLevel: _readLevel(
        raw['creatorMemoryLevel'],
        fallback.creatorMemoryLevel,
      ),
      creatorScoreLevel: _readLevel(
        raw['creatorScoreLevel'],
        fallback.creatorScoreLevel,
      ),
      weeklyReportLevel: _readLevel(
        raw['weeklyReportLevel'],
        fallback.weeklyReportLevel,
      ),
      academyAccessLevel: _readLevel(
        raw['academyAccessLevel'],
        fallback.academyAccessLevel,
      ),
    );
  }
}

String _readLevel(Object? value, String fallback) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return fallback;
}
