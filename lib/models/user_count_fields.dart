class UserCountFields {
  static int readFollowersCount(Map<String, dynamic> data) {
    return _readInt(data['followersCount']) ??
        _readInt(data['followerCount']) ??
        0;
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

