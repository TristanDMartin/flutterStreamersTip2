import 'user_count_fields.dart';

class UserStats {
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final int connectionsCount;

  const UserStats({
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.connectionsCount,
  });

  factory UserStats.empty() => const UserStats(
        postsCount: 0,
        followersCount: 0,
        followingCount: 0,
        connectionsCount: 0,
      );

  static UserStats fromUserDocData(Map<String, Object?> data) {
    final Map<String, dynamic> normalizedData = Map<String, dynamic>.from(data);
    final int postsCount = _readInt(data, 'postCount') ??
        _readInt(data, 'postsCount') ??
        _readInt(data, 'videoCount') ??
        _readInt(data, 'videos') ??
        0;
    final int followersCount =
        UserCountFields.readFollowersCount(normalizedData);
    final int followingCount =
        UserCountFields.readFollowingCount(normalizedData);
    final int connectionsCount =
        UserCountFields.readConnectionsCount(normalizedData);
    return UserStats(
      postsCount: postsCount,
      followersCount: followersCount,
      followingCount: followingCount,
      connectionsCount: connectionsCount,
    );
  }

  static int? _readInt(Map<String, Object?> data, String key) {
    final Object? value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}
