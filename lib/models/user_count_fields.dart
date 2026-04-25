class UserCountFields {
  /// Picks a sensible follow total when the doc has mixed legacy fields
  /// (e.g. [followersCount] was initialized to 0 but [followerCount] is live).
  static int readFollowersCount(Map<String, dynamic> data) {
    final int? plural = _readInt(data['followersCount']);
    final int? singular = _readInt(data['followerCount']);
    if (plural == null && singular == null) return 0;
    if (plural == null) return singular!;
    if (singular == null) return plural;
    return singular > plural ? singular : plural;
  }

  static int readFollowingCount(Map<String, dynamic> data) {
    return _readInt(data['followingCount']) ??
        _readInt(data['followingsCount']) ??
        0;
  }

  static int readConnectionsCount(Map<String, dynamic> data) {
    return _readInt(data['connectionsCount']) ?? 0;
  }

  static Map<String, dynamic> writeCanonicalCounts({
    required int followersCount,
    required int followingCount,
    int? connectionsCount,
  }) {
    return <String, dynamic>{
      'followerCount': followersCount,
      'followersCount': followersCount,
      'followingCount': followingCount,
      if (connectionsCount != null) 'connectionsCount': connectionsCount,
    };
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}

