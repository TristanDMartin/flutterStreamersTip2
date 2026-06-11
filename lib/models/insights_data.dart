/// Model for video insights analytics data
class InsightsData {
  final String videoId;
  final DateTime dateRange;
  final OverviewMetrics overview;
  final ViewerMetrics viewers;
  final EngagementMetrics engagement;

  InsightsData({
    required this.videoId,
    required this.dateRange,
    required this.overview,
    required this.viewers,
    required this.engagement,
  });

  factory InsightsData.fromJson(Map<String, dynamic> json) {
    return InsightsData(
      videoId: json['videoId'] ?? '',
      dateRange:
          DateTime.parse(json['dateRange'] ?? DateTime.now().toIso8601String()),
      overview: OverviewMetrics.fromJson(json['overview'] ?? {}),
      viewers: ViewerMetrics.fromJson(json['viewers'] ?? {}),
      engagement: EngagementMetrics.fromJson(json['engagement'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'dateRange': dateRange.toIso8601String(),
      'overview': overview.toJson(),
      'viewers': viewers.toJson(),
      'engagement': engagement.toJson(),
    };
  }
}

/// Overview metrics for video performance
class OverviewMetrics {
  final int totalViews;
  final Duration totalWatchTime;
  final int shares;
  final int comments;
  final double retentionRate;
  final List<TrafficSource> trafficSources;
  final List<String> searchQueries;

  OverviewMetrics({
    required this.totalViews,
    required this.totalWatchTime,
    required this.shares,
    required this.comments,
    required this.retentionRate,
    required this.trafficSources,
    required this.searchQueries,
  });

  factory OverviewMetrics.fromJson(Map<String, dynamic> json) {
    return OverviewMetrics(
      totalViews: json['totalViews'] ?? 0,
      totalWatchTime: Duration(seconds: json['totalWatchTime'] ?? 0),
      shares: json['shares'] ?? 0,
      comments: json['comments'] ?? 0,
      retentionRate: (json['retentionRate'] ?? 0.0).toDouble(),
      trafficSources: (json['trafficSources'] as List?)
              ?.map((e) => TrafficSource.fromJson(e))
              .toList() ??
          [],
      searchQueries: List<String>.from(json['searchQueries'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalViews': totalViews,
      'totalWatchTime': totalWatchTime.inSeconds,
      'shares': shares,
      'comments': comments,
      'retentionRate': retentionRate,
      'trafficSources': trafficSources.map((e) => e.toJson()).toList(),
      'searchQueries': searchQueries,
    };
  }
}

/// Traffic source data
class TrafficSource {
  final String source;
  final int views;
  final double percentage;

  TrafficSource({
    required this.source,
    required this.views,
    required this.percentage,
  });

  factory TrafficSource.fromJson(Map<String, dynamic> json) {
    return TrafficSource(
      source: json['source'] ?? '',
      views: json['views'] ?? 0,
      percentage: (json['percentage'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'views': views,
      'percentage': percentage,
    };
  }
}

/// Viewer demographics and behavior metrics
class ViewerMetrics {
  final int totalViews;
  final int uniqueViewers;
  final ViewerTypes viewerTypes;
  final GenderBreakdown genderBreakdown;
  final List<AgeGroup> ageGroups;
  final List<Location> topLocations;

  ViewerMetrics({
    required this.totalViews,
    required this.uniqueViewers,
    required this.viewerTypes,
    required this.genderBreakdown,
    required this.ageGroups,
    required this.topLocations,
  });

  factory ViewerMetrics.fromJson(Map<String, dynamic> json) {
    return ViewerMetrics(
      totalViews: json['totalViews'] ?? 0,
      uniqueViewers: json['uniqueViewers'] ?? 0,
      viewerTypes: ViewerTypes.fromJson(json['viewerTypes'] ?? {}),
      genderBreakdown: GenderBreakdown.fromJson(json['genderBreakdown'] ?? {}),
      ageGroups: (json['ageGroups'] as List?)
              ?.map((e) => AgeGroup.fromJson(e))
              .toList() ??
          [],
      topLocations: (json['topLocations'] as List?)
              ?.map((e) => Location.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalViews': totalViews,
      'uniqueViewers': uniqueViewers,
      'viewerTypes': viewerTypes.toJson(),
      'genderBreakdown': genderBreakdown.toJson(),
      'ageGroups': ageGroups.map((e) => e.toJson()).toList(),
      'topLocations': topLocations.map((e) => e.toJson()).toList(),
    };
  }
}

/// New vs returning viewers
class ViewerTypes {
  final int newViewers;
  final int returningViewers;

  ViewerTypes({
    required this.newViewers,
    required this.returningViewers,
  });

  factory ViewerTypes.fromJson(Map<String, dynamic> json) {
    return ViewerTypes(
      newViewers: json['newViewers'] ?? 0,
      returningViewers: json['returningViewers'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'newViewers': newViewers,
      'returningViewers': returningViewers,
    };
  }
}

/// Gender breakdown
class GenderBreakdown {
  final int male;
  final int female;
  final int other;
  final int unknown;

  GenderBreakdown({
    required this.male,
    required this.female,
    required this.other,
    required this.unknown,
  });

  factory GenderBreakdown.fromJson(Map<String, dynamic> json) {
    return GenderBreakdown(
      male: json['male'] ?? 0,
      female: json['female'] ?? 0,
      other: json['other'] ?? 0,
      unknown: json['unknown'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'male': male,
      'female': female,
      'other': other,
      'unknown': unknown,
    };
  }
}

/// Age group data
class AgeGroup {
  final String range;
  final int count;
  final double percentage;

  AgeGroup({
    required this.range,
    required this.count,
    required this.percentage,
  });

  factory AgeGroup.fromJson(Map<String, dynamic> json) {
    return AgeGroup(
      range: json['range'] ?? '',
      count: json['count'] ?? 0,
      percentage: (json['percentage'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'range': range,
      'count': count,
      'percentage': percentage,
    };
  }
}

/// Location data
class Location {
  final String name;
  final int views;
  final double percentage;

  Location({
    required this.name,
    required this.views,
    required this.percentage,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      name: json['name'] ?? '',
      views: json['views'] ?? 0,
      percentage: (json['percentage'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'views': views,
      'percentage': percentage,
    };
  }
}

/// Engagement metrics
class EngagementMetrics {
  final int likes;
  final int shares;
  final int comments;
  final int favorites;
  final double engagementRate;
  final List<EngagementTrend> trends;

  EngagementMetrics({
    required this.likes,
    required this.shares,
    required this.comments,
    required this.favorites,
    required this.engagementRate,
    required this.trends,
  });

  factory EngagementMetrics.fromJson(Map<String, dynamic> json) {
    return EngagementMetrics(
      likes: json['likes'] ?? 0,
      shares: json['shares'] ?? 0,
      comments: json['comments'] ?? 0,
      favorites: json['favorites'] ?? 0,
      engagementRate: (json['engagementRate'] ?? 0.0).toDouble(),
      trends: (json['trends'] as List?)
              ?.map((e) => EngagementTrend.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'likes': likes,
      'shares': shares,
      'comments': comments,
      'favorites': favorites,
      'engagementRate': engagementRate,
      'trends': trends.map((e) => e.toJson()).toList(),
    };
  }
}

/// Engagement trend over time
class EngagementTrend {
  final DateTime date;
  final int likes;
  final int shares;
  final int comments;
  final int favorites;

  EngagementTrend({
    required this.date,
    required this.likes,
    required this.shares,
    required this.comments,
    required this.favorites,
  });

  factory EngagementTrend.fromJson(Map<String, dynamic> json) {
    return EngagementTrend(
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      likes: json['likes'] ?? 0,
      shares: json['shares'] ?? 0,
      comments: json['comments'] ?? 0,
      favorites: json['favorites'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'likes': likes,
      'shares': shares,
      'comments': comments,
      'favorites': favorites,
    };
  }
}

extension InsightsDataAvailability on InsightsData {
  bool get hasAudienceBreakdown {
    final GenderBreakdown gender = viewers.genderBreakdown;
    final int genderTotal =
        gender.male + gender.female + gender.other + gender.unknown;
    if (genderTotal > 0) {
      return true;
    }
    if (viewers.viewerTypes.newViewers > 0 ||
        viewers.viewerTypes.returningViewers > 0) {
      return true;
    }
    if (viewers.ageGroups.any((AgeGroup group) => group.count > 0)) {
      return true;
    }
    if (viewers.topLocations.isNotEmpty) {
      return true;
    }
    return false;
  }

  bool get hasTrafficSources => overview.trafficSources.isNotEmpty;

  bool get hasEngagementTrends => engagement.trends.isNotEmpty;

  int get bookmarks => engagement.favorites;
}
