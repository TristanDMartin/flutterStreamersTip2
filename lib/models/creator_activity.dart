import 'package:cloud_firestore/cloud_firestore.dart';

/// Creator activity shown on Network, Profile, Streamer Card, Inbox, Search.
enum CreatorActivityType {
  none,
  live,
  postedToday,
  uploadedClip,
  lookingForCollabs,
  editingContent,
  openToNetwork,
  workingOnClips,
  streamingSoon,
  takingBreak,
  newCreatorCard,
  trendingPost,
}

enum CreatorActivitySource {
  manual,
  system,
  integration,
}

enum CreatorActivityPlatform {
  twitch,
  youtube,
  kick,
  tiktok,
}

class CreatorActivity {
  const CreatorActivity({
    required this.type,
    required this.label,
    required this.emoji,
    required this.source,
    this.platform,
    this.updatedAt,
    this.expiresAt,
    this.isVisible = true,
  });

  final CreatorActivityType type;
  final String label;
  final String emoji;
  final CreatorActivitySource source;
  final CreatorActivityPlatform? platform;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final bool isVisible;

  bool get isNone => type == CreatorActivityType.none || !isVisible;

  bool isExpiredAt(DateTime now) {
    if (expiresAt == null) return false;
    return !expiresAt!.isAfter(now);
  }

  bool isActiveAt(DateTime now) {
    if (isNone) return false;
    return !isExpiredAt(now);
  }

  String get displayLine {
    if (emoji.isNotEmpty) return '$emoji $label';
    return label;
  }

  static const CreatorActivity noneValue = CreatorActivity(
    type: CreatorActivityType.none,
    label: '',
    emoji: '',
    source: CreatorActivitySource.manual,
    isVisible: false,
  );

  factory CreatorActivity.none() => noneValue;

  factory CreatorActivity.fromMap(Object? raw) {
    if (raw is! Map) return CreatorActivity.none();
    final Map<String, dynamic> data = Map<String, dynamic>.from(raw);
    final String typeRaw = (data['type'] ?? 'none').toString();
    return CreatorActivity(
      type: _typeFromString(typeRaw),
      label: (data['label'] ?? '').toString(),
      emoji: (data['emoji'] ?? '').toString(),
      source: _sourceFromString((data['source'] ?? 'manual').toString()),
      platform: _platformFromString(data['platform']?.toString()),
      updatedAt: _readDate(data['updatedAt']),
      expiresAt: _readDate(data['expiresAt']),
      isVisible: data['isVisible'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'type': type.name,
      'label': label,
      'emoji': emoji,
      'source': source.name,
      if (platform != null) 'platform': platform!.name,
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      'isVisible': isVisible,
    };
  }

  CreatorActivity copyWith({
    CreatorActivityType? type,
    String? label,
    String? emoji,
    CreatorActivitySource? source,
    CreatorActivityPlatform? platform,
    DateTime? updatedAt,
    DateTime? expiresAt,
    bool? isVisible,
  }) {
    return CreatorActivity(
      type: type ?? this.type,
      label: label ?? this.label,
      emoji: emoji ?? this.emoji,
      source: source ?? this.source,
      platform: platform ?? this.platform,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}

class CreatorActivityPrivacy {
  const CreatorActivityPrivacy({
    this.showCreatorActivity = true,
    this.showLiveStatus = true,
    this.showPostActivity = true,
    this.showCollaborationStatus = true,
    this.connectionsOnly = false,
    this.hideFromEveryone = false,
  });

  final bool showCreatorActivity;
  final bool showLiveStatus;
  final bool showPostActivity;
  final bool showCollaborationStatus;
  final bool connectionsOnly;
  final bool hideFromEveryone;

  factory CreatorActivityPrivacy.fromMap(Object? raw) {
    if (raw is! Map) return const CreatorActivityPrivacy();
    final Map<String, dynamic> data = Map<String, dynamic>.from(raw);
    return CreatorActivityPrivacy(
      showCreatorActivity: data['showCreatorActivity'] != false,
      showLiveStatus: data['showLiveStatus'] != false,
      showPostActivity: data['showPostActivity'] != false,
      showCollaborationStatus: data['showCollaborationStatus'] != false,
      connectionsOnly: data['connectionsOnly'] == true,
      hideFromEveryone: data['hideFromEveryone'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'showCreatorActivity': showCreatorActivity,
      'showLiveStatus': showLiveStatus,
      'showPostActivity': showPostActivity,
      'showCollaborationStatus': showCollaborationStatus,
      'connectionsOnly': connectionsOnly,
      'hideFromEveryone': hideFromEveryone,
    };
  }

  CreatorActivityPrivacy copyWith({
    bool? showCreatorActivity,
    bool? showLiveStatus,
    bool? showPostActivity,
    bool? showCollaborationStatus,
    bool? connectionsOnly,
    bool? hideFromEveryone,
  }) {
    return CreatorActivityPrivacy(
      showCreatorActivity: showCreatorActivity ?? this.showCreatorActivity,
      showLiveStatus: showLiveStatus ?? this.showLiveStatus,
      showPostActivity: showPostActivity ?? this.showPostActivity,
      showCollaborationStatus:
          showCollaborationStatus ?? this.showCollaborationStatus,
      connectionsOnly: connectionsOnly ?? this.connectionsOnly,
      hideFromEveryone: hideFromEveryone ?? this.hideFromEveryone,
    );
  }
}

class CreatorActivityPreset {
  const CreatorActivityPreset({
    required this.type,
    required this.label,
    required this.emoji,
  });

  final CreatorActivityType type;
  final String label;
  final String emoji;
}

const List<CreatorActivityPreset> kCreatorActivityManualPresets =
    <CreatorActivityPreset>[
  CreatorActivityPreset(
    type: CreatorActivityType.lookingForCollabs,
    label: 'Looking for collabs',
    emoji: '🤝',
  ),
  CreatorActivityPreset(
    type: CreatorActivityType.editingContent,
    label: 'Editing content',
    emoji: '✂️',
  ),
  CreatorActivityPreset(
    type: CreatorActivityType.openToNetwork,
    label: 'Open to networking',
    emoji: '🌐',
  ),
  CreatorActivityPreset(
    type: CreatorActivityType.workingOnClips,
    label: 'Working on clips',
    emoji: '🎬',
  ),
  CreatorActivityPreset(
    type: CreatorActivityType.streamingSoon,
    label: 'Streaming soon',
    emoji: '⏳',
  ),
  CreatorActivityPreset(
    type: CreatorActivityType.takingBreak,
    label: 'Taking a break',
    emoji: '☕',
  ),
];

CreatorActivityType _typeFromString(String raw) {
  final String key = raw.trim();
  for (final CreatorActivityType type in CreatorActivityType.values) {
    if (type.name == key) return type;
  }
  switch (key) {
    case 'open_to_network':
      return CreatorActivityType.openToNetwork;
    case 'working_on_clips':
      return CreatorActivityType.workingOnClips;
    case 'streaming_soon':
      return CreatorActivityType.streamingSoon;
    case 'taking_break':
      return CreatorActivityType.takingBreak;
    case 'posted_today':
      return CreatorActivityType.postedToday;
    case 'uploaded_clip':
      return CreatorActivityType.uploadedClip;
    case 'new_creator_card':
      return CreatorActivityType.newCreatorCard;
    case 'trending_post':
      return CreatorActivityType.trendingPost;
    case 'looking_for_collabs':
      return CreatorActivityType.lookingForCollabs;
    case 'editing_content':
      return CreatorActivityType.editingContent;
    default:
      return CreatorActivityType.none;
  }
}

CreatorActivitySource _sourceFromString(String raw) {
  switch (raw) {
    case 'system':
      return CreatorActivitySource.system;
    case 'integration':
      return CreatorActivitySource.integration;
    default:
      return CreatorActivitySource.manual;
  }
}

CreatorActivityPlatform? _platformFromString(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  for (final CreatorActivityPlatform p in CreatorActivityPlatform.values) {
    if (p.name == raw) return p;
  }
  return null;
}

DateTime? _readDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}

CreatorActivity buildLiveActivity(CreatorActivityPlatform platform) {
  final String platformLabel = switch (platform) {
    CreatorActivityPlatform.twitch => 'Twitch',
    CreatorActivityPlatform.youtube => 'YouTube',
    CreatorActivityPlatform.kick => 'Kick',
    CreatorActivityPlatform.tiktok => 'TikTok',
  };
  return CreatorActivity(
    type: CreatorActivityType.live,
    label: 'LIVE on $platformLabel',
    emoji: '🟢',
    source: CreatorActivitySource.integration,
    platform: platform,
    updatedAt: DateTime.now(),
    isVisible: true,
  );
}

CreatorActivity buildSystemActivity({
  required CreatorActivityType type,
  String? platformName,
}) {
  final DateTime now = DateTime.now();
  switch (type) {
    case CreatorActivityType.postedToday:
      return CreatorActivity(
        type: type,
        label: 'Posted today',
        emoji: '📝',
        source: CreatorActivitySource.system,
        updatedAt: now,
        expiresAt: _endOfLocalDay(now),
        isVisible: true,
      );
    case CreatorActivityType.uploadedClip:
      return CreatorActivity(
        type: type,
        label: 'Uploaded clip',
        emoji: '🎥',
        source: CreatorActivitySource.system,
        updatedAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
        isVisible: true,
      );
    case CreatorActivityType.newCreatorCard:
      return CreatorActivity(
        type: type,
        label: 'New creator card',
        emoji: '✨',
        source: CreatorActivitySource.system,
        updatedAt: now,
        expiresAt: now.add(const Duration(hours: 48)),
        isVisible: true,
      );
    case CreatorActivityType.trendingPost:
      return CreatorActivity(
        type: type,
        label: 'Trending post',
        emoji: '🔥',
        source: CreatorActivitySource.system,
        updatedAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
        isVisible: true,
      );
    case CreatorActivityType.live:
      final CreatorActivityPlatform platform =
          _platformFromString(platformName) ?? CreatorActivityPlatform.twitch;
      return buildLiveActivity(platform);
    default:
      return CreatorActivity.none();
  }
}

DateTime _endOfLocalDay(DateTime now) {
  return DateTime(now.year, now.month, now.day, 23, 59, 59);
}
