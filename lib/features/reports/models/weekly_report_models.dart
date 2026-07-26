class WeeklyReportPeriod {
  const WeeklyReportPeriod({
    required this.label,
    required this.weekKey,
  });

  final String label;
  final String weekKey;

  factory WeeklyReportPeriod.fromJson(Map<String, dynamic>? raw) {
    return WeeklyReportPeriod(
      label: _str(raw?['label'], 'This week'),
      weekKey: _str(raw?['weekKey'], ''),
    );
  }
}

class WeeklyReportBasic {
  const WeeklyReportBasic({
    required this.postsPublished,
    required this.targetPosts,
    required this.uploadStreak,
    required this.missionsCompletedApprox,
    required this.nextFocus,
    required this.tip,
  });

  final int postsPublished;
  final int? targetPosts;
  final int uploadStreak;
  final int missionsCompletedApprox;
  final String nextFocus;
  final String tip;

  factory WeeklyReportBasic.fromJson(Map<String, dynamic>? raw) {
    return WeeklyReportBasic(
      postsPublished: _int(raw?['postsPublished'], 0),
      targetPosts: raw?['targetPosts'] is num
          ? (raw!['targetPosts'] as num).round()
          : null,
      uploadStreak: _int(raw?['uploadStreak'], 0),
      missionsCompletedApprox: _int(raw?['missionsCompletedApprox'], 0),
      nextFocus: _str(raw?['nextFocus'], ''),
      tip: _str(raw?['tip'], ''),
    );
  }
}

class WeeklyReportGrowth {
  const WeeklyReportGrowth({
    required this.creatorScore,
    required this.growthMomentum,
    required this.strongestCategory,
    required this.weakestCategory,
    required this.wins,
    required this.experiments,
    required this.actions,
    required this.topContentTitles,
  });

  final int? creatorScore;
  final int? growthMomentum;
  final String? strongestCategory;
  final String? weakestCategory;
  final List<String> wins;
  final List<String> experiments;
  final List<String> actions;
  final List<String> topContentTitles;

  factory WeeklyReportGrowth.fromJson(Map<String, dynamic>? raw) {
    if (raw == null) {
      return const WeeklyReportGrowth(
        creatorScore: null,
        growthMomentum: null,
        strongestCategory: null,
        weakestCategory: null,
        wins: <String>[],
        experiments: <String>[],
        actions: <String>[],
        topContentTitles: <String>[],
      );
    }
    final List<String> titles = <String>[];
    final Object? top = raw['topContent'];
    if (top is List) {
      for (final Object? item in top) {
        if (item is Map && item['title'] is String) {
          titles.add(item['title'] as String);
        }
      }
    }
    return WeeklyReportGrowth(
      creatorScore: raw['creatorScore'] is num
          ? (raw['creatorScore'] as num).round()
          : null,
      growthMomentum: raw['growthMomentum'] is num
          ? (raw['growthMomentum'] as num).round()
          : null,
      strongestCategory: raw['strongestCategory'] is String
          ? raw['strongestCategory'] as String
          : null,
      weakestCategory: raw['weakestCategory'] is String
          ? raw['weakestCategory'] as String
          : null,
      wins: _stringList(raw['wins']),
      experiments: _stringList(raw['experiments']),
      actions: _stringList(raw['actions']),
      topContentTitles: titles,
    );
  }
}

class WeeklyReportBusiness {
  const WeeklyReportBusiness({
    required this.partnershipReadiness,
    required this.exportAvailable,
    required this.teamHint,
    required this.benchmarks,
    required this.campaignNotes,
  });

  final String partnershipReadiness;
  final bool exportAvailable;
  final String? teamHint;
  final List<String> benchmarks;
  final List<String> campaignNotes;

  factory WeeklyReportBusiness.fromJson(Map<String, dynamic>? raw) {
    if (raw == null) {
      return const WeeklyReportBusiness(
        partnershipReadiness: '',
        exportAvailable: false,
        teamHint: null,
        benchmarks: <String>[],
        campaignNotes: <String>[],
      );
    }
    return WeeklyReportBusiness(
      partnershipReadiness: _str(raw['partnershipReadiness'], ''),
      exportAvailable: raw['exportAvailable'] == true,
      teamHint: raw['teamHint'] is String ? raw['teamHint'] as String : null,
      benchmarks: _stringList(raw['benchmarks']),
      campaignNotes: _stringList(raw['campaignNotes']),
    );
  }
}

class WeeklyReportPreview {
  const WeeklyReportPreview({
    required this.level,
    required this.title,
    required this.teaser,
    required this.upgradeTo,
    required this.upgradeLabel,
  });

  final String level;
  final String title;
  final String teaser;
  final String upgradeTo;
  final String upgradeLabel;

  factory WeeklyReportPreview.fromJson(Map<String, dynamic> raw) {
    return WeeklyReportPreview(
      level: _str(raw['level'], 'growth'),
      title: _str(raw['title'], 'Upgrade'),
      teaser: _str(raw['teaser'], ''),
      upgradeTo: _str(raw['upgradeTo'], 'pro'),
      upgradeLabel: _str(raw['upgradeLabel'], 'Upgrade'),
    );
  }
}

class WeeklyReport {
  const WeeklyReport({
    required this.level,
    required this.period,
    required this.headline,
    required this.summary,
    required this.basic,
    required this.growth,
    required this.business,
    required this.previews,
  });

  final String level;
  final WeeklyReportPeriod period;
  final String headline;
  final String summary;
  final WeeklyReportBasic basic;
  final WeeklyReportGrowth? growth;
  final WeeklyReportBusiness? business;
  final List<WeeklyReportPreview> previews;

  factory WeeklyReport.fromJson(Map<String, dynamic> raw) {
    final Object? growthRaw = raw['growth'];
    final Object? businessRaw = raw['business'];
    final List<WeeklyReportPreview> previews = <WeeklyReportPreview>[];
    final Object? previewRaw = raw['previews'];
    if (previewRaw is List) {
      for (final Object? item in previewRaw) {
        if (item is Map<String, dynamic>) {
          previews.add(WeeklyReportPreview.fromJson(item));
        } else if (item is Map) {
          previews.add(
            WeeklyReportPreview.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return WeeklyReport(
      level: _str(raw['level'], 'basic'),
      period: WeeklyReportPeriod.fromJson(
        raw['period'] is Map<String, dynamic>
            ? raw['period'] as Map<String, dynamic>
            : null,
      ),
      headline: _str(raw['headline'], 'Weekly report'),
      summary: _str(raw['summary'], ''),
      basic: WeeklyReportBasic.fromJson(
        raw['basic'] is Map<String, dynamic>
            ? raw['basic'] as Map<String, dynamic>
            : null,
      ),
      growth: growthRaw is Map<String, dynamic>
          ? WeeklyReportGrowth.fromJson(growthRaw)
          : null,
      business: businessRaw is Map<String, dynamic>
          ? WeeklyReportBusiness.fromJson(businessRaw)
          : null,
      previews: previews,
    );
  }
}

class WeeklyReportResponse {
  const WeeklyReportResponse({
    required this.report,
    required this.weeklyReportLevel,
  });

  final WeeklyReport report;
  final String weeklyReportLevel;

  factory WeeklyReportResponse.fromJson(Map<String, dynamic> raw) {
    final Map<String, dynamic> reportMap =
        raw['report'] is Map<String, dynamic>
            ? raw['report'] as Map<String, dynamic>
            : raw;
    return WeeklyReportResponse(
      report: WeeklyReport.fromJson(reportMap),
      weeklyReportLevel: _str(
        raw['weeklyReportLevel'],
        _str(reportMap['level'], 'basic'),
      ),
    );
  }
}

int _int(Object? value, int fallback) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return fallback;
}

String _str(Object? value, String fallback) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return fallback;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return <String>[];
  }
  return value
      .whereType<String>()
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty)
      .toList(growable: false);
}
