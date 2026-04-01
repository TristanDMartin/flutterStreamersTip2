/// Forum author model - Regular class (NOT freezed)
class ForumAuthor {
  final String uid;
  final String username;
  final String displayName;
  final String? avatarUrl;

  ForumAuthor({
    required this.uid,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  factory ForumAuthor.fromMap(Map<String, dynamic> map) {
    return ForumAuthor(
      uid: (map['uid'] ?? map['id'] ?? '') as String,
      username: (map['username'] ?? 'user') as String,
      displayName: (map['displayName'] ?? map['name'] ?? 'Anonymous') as String,
      avatarUrl: (map['avatarUrl'] ?? map['avatarURL']) as String?,
    );
  }

  factory ForumAuthor.fromUserData(String uid, Map<String, dynamic> data) {
    return ForumAuthor(
      uid: uid,
      username: data['username'] as String? ?? 'user',
      displayName: data['displayName'] as String? ?? 'Anonymous',
      avatarUrl:
          data['avatarUrl'] as String? ?? data['avatarURL'] as String?,
    );
  }

  ForumAuthor copyWith({
    String? uid,
    String? username,
    String? displayName,
    String? avatarUrl,
  }) {
    return ForumAuthor(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
    };
  }
}
