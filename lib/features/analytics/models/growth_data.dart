class PlatformGrowthPoint {
  const PlatformGrowthPoint({
    required this.date,
    required this.value,
  });

  final String date;
  final int value;

  factory PlatformGrowthPoint.fromJson(Map<String, dynamic> raw) {
    return PlatformGrowthPoint(
      date: raw['date']?.toString() ?? '',
      value: _readInt(raw['value'], 0),
    );
  }
}

class PlatformStatusSnapshot {
  const PlatformStatusSnapshot({
    required this.connected,
    this.username,
    this.lastFetched,
    this.followers,
    this.views,
  });

  final bool connected;
  final String? username;
  final String? lastFetched;
  final int? followers;
  final int? views;

  factory PlatformStatusSnapshot.fromJson(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return const PlatformStatusSnapshot(connected: false);
    }
    final Map<String, dynamic>? metrics =
        raw['metrics'] is Map<String, dynamic>
            ? raw['metrics'] as Map<String, dynamic>
            : null;
    return PlatformStatusSnapshot(
      connected: raw['connected'] == true,
      username: raw['username']?.toString(),
      lastFetched: raw['lastFetched']?.toString(),
      followers: metrics != null ? _readInt(metrics['followers'], 0) : null,
      views: metrics != null ? _readInt(metrics['views'], 0) : null,
    );
  }
}

class GrowthTopContentItem {
  const GrowthTopContentItem({
    required this.title,
    required this.platform,
    required this.views,
    required this.uplift,
    required this.rank,
  });

  final String title;
  final String platform;
  final String views;
  final String uplift;
  final String rank;

  factory GrowthTopContentItem.fromJson(Map<String, dynamic> raw) {
    return GrowthTopContentItem(
      title: raw['title']?.toString() ?? 'Untitled',
      platform: raw['platform']?.toString() ?? '',
      views: raw['views']?.toString() ?? '0',
      uplift: raw['uplift']?.toString() ?? '',
      rank: raw['rank']?.toString() ?? '',
    );
  }
}

class GrowthCrossPostItem {
  const GrowthCrossPostItem({
    required this.date,
    required this.title,
    required this.platforms,
    required this.followGain,
  });

  final String date;
  final String title;
  final List<String> platforms;
  final String followGain;

  factory GrowthCrossPostItem.fromJson(Map<String, dynamic> raw) {
    final Object? platformsRaw = raw['platforms'];
    final List<String> platforms = platformsRaw is List
        ? platformsRaw.map((dynamic e) => e.toString()).toList()
        : const <String>[];
    return GrowthCrossPostItem(
      date: raw['date']?.toString() ?? '',
      title: raw['title']?.toString() ?? '',
      platforms: platforms,
      followGain: raw['followGain']?.toString() ?? '',
    );
  }
}

class GrowthData {
  const GrowthData({
    this.twitch = const <PlatformGrowthPoint>[],
    this.youtube = const <PlatformGrowthPoint>[],
    this.tiktok = const <PlatformGrowthPoint>[],
    this.kick = const <PlatformGrowthPoint>[],
    this.crosspost = const <GrowthCrossPostItem>[],
    this.topContent = const <GrowthTopContentItem>[],
    this.lastUpdated,
    this.platformStatus = const <String, PlatformStatusSnapshot>{},
  });

  final List<PlatformGrowthPoint> twitch;
  final List<PlatformGrowthPoint> youtube;
  final List<PlatformGrowthPoint> tiktok;
  final List<PlatformGrowthPoint> kick;
  final List<GrowthCrossPostItem> crosspost;
  final List<GrowthTopContentItem> topContent;
  final String? lastUpdated;
  final Map<String, PlatformStatusSnapshot> platformStatus;

  static const GrowthData empty = GrowthData();

  List<PlatformGrowthPoint> seriesFor(String platformKey) {
    switch (platformKey) {
      case 'twitch':
        return twitch;
      case 'youtube':
        return youtube;
      case 'tiktok':
        return tiktok;
      case 'kick':
        return kick;
      default:
        return const <PlatformGrowthPoint>[];
    }
  }

  factory GrowthData.fromJson(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return GrowthData.empty;
    }
    final Map<String, PlatformStatusSnapshot> status =
        <String, PlatformStatusSnapshot>{};
    final Object? statusRaw = raw['platformStatus'];
    if (statusRaw is Map<String, dynamic>) {
      statusRaw.forEach((String key, dynamic value) {
        if (value is Map<String, dynamic>) {
          status[key] = PlatformStatusSnapshot.fromJson(value);
        }
      });
    } else if (statusRaw is Map) {
      statusRaw.forEach((dynamic key, dynamic value) {
        if (value is Map<String, dynamic>) {
          status[key.toString()] = PlatformStatusSnapshot.fromJson(value);
        }
      });
    }
    return GrowthData(
      twitch: _readSeries(raw['twitch']),
      youtube: _readSeries(raw['youtube']),
      tiktok: _readSeries(raw['tiktok']),
      kick: _readSeries(raw['kick']),
      crosspost: _readCrosspost(raw['crosspost']),
      topContent: _readTopContent(raw['topContent']),
      lastUpdated: raw['lastUpdated']?.toString(),
      platformStatus: status,
    );
  }
}

List<PlatformGrowthPoint> _readSeries(Object? raw) {
  if (raw is! List) {
    return const <PlatformGrowthPoint>[];
  }
  return raw
      .whereType<Map<String, dynamic>>()
      .map(PlatformGrowthPoint.fromJson)
      .toList();
}

List<GrowthCrossPostItem> _readCrosspost(Object? raw) {
  if (raw is! List) {
    return const <GrowthCrossPostItem>[];
  }
  return raw
      .whereType<Map<String, dynamic>>()
      .map(GrowthCrossPostItem.fromJson)
      .toList();
}

List<GrowthTopContentItem> _readTopContent(Object? raw) {
  if (raw is! List) {
    return const <GrowthTopContentItem>[];
  }
  return raw
      .whereType<Map<String, dynamic>>()
      .map(GrowthTopContentItem.fromJson)
      .toList();
}

int _readInt(Object? value, int fallback) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}
