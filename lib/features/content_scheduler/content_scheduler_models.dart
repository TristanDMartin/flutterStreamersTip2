enum SchedulerQueueSource { job, draft }

enum SchedulerQueueStatus {
  scheduled,
  publishing,
  published,
  failed,
  draft,
}

class SchedulerQueueItem {
  const SchedulerQueueItem({
    required this.id,
    required this.source,
    required this.title,
    required this.caption,
    required this.platforms,
    required this.status,
    required this.sortTime,
    required this.rawStatus,
  });

  final String id;
  final SchedulerQueueSource source;
  final String title;
  final String caption;
  final List<String> platforms;
  final SchedulerQueueStatus status;
  final DateTime sortTime;
  final String rawStatus;

  bool get isDraft => source == SchedulerQueueSource.draft;

  static SchedulerQueueItem fromJob(Map<String, dynamic> job) {
    final String rawId = _readString(job['id']) ?? '';
    final String caption = _readString(job['caption']) ?? '';
    final DateTime time = _readDate(job['scheduledAt']) ??
        _readDate(job['createdAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final String rawStatus = _readString(job['status']) ?? 'pending';
    return SchedulerQueueItem(
      id: 'job:$rawId',
      source: SchedulerQueueSource.job,
      title: _deriveTitle(job, caption),
      caption: caption,
      platforms: _readJobPlatforms(job),
      status: _deriveJobStatus(job, rawStatus),
      sortTime: time,
      rawStatus: rawStatus,
    );
  }

  static SchedulerQueueItem fromDraft(Map<String, dynamic> draft) {
    final String rawId = _readString(draft['id']) ?? '';
    final String caption = _readString(draft['caption']) ?? '';
    final DateTime time = _readDate(draft['updatedAt']) ??
        _readDate(draft['createdAt']) ??
        _readDate(draft['scheduledAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return SchedulerQueueItem(
      id: 'draft:$rawId',
      source: SchedulerQueueSource.draft,
      title: _readString(draft['title']) ?? _deriveTitle(draft, caption),
      caption: caption,
      platforms: _readKnownPlatforms(draft['platforms']),
      status: SchedulerQueueStatus.draft,
      sortTime: time,
      rawStatus: 'draft',
    );
  }
}

const Set<String> _knownSchedulerPlatforms = <String>{
  'instagram',
  'tiktok',
  'youtube',
  'twitter',
  'x',
  'linkedin',
  'facebook',
};

String schedulerStatusLabel(SchedulerQueueStatus status) {
  return switch (status) {
    SchedulerQueueStatus.scheduled => 'Scheduled',
    SchedulerQueueStatus.publishing => 'Publishing',
    SchedulerQueueStatus.published => 'Published',
    SchedulerQueueStatus.failed => 'Failed',
    SchedulerQueueStatus.draft => 'Draft',
  };
}

DateTime? _readDate(Object? raw) {
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

String? _readString(Object? raw) {
  if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  return null;
}

String _deriveTitle(Map<String, dynamic> data, String caption) {
  final String? title = _readString(data['title']) ??
      _readString(data['youtubeTitle']) ??
      _readString(data['videoTitle']);
  if (title != null) return title;
  final String cleaned = caption.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isEmpty) return 'Queued post';
  return cleaned.length > 52 ? '${cleaned.substring(0, 52)}...' : cleaned;
}

List<String> _readJobPlatforms(Map<String, dynamic> job) {
  final Object? destinations = job['destinations'];
  if (destinations is Map<String, dynamic>) {
    final Object? external = destinations['external'];
    final List<String> fromExternal = _readKnownPlatforms(external);
    if (fromExternal.isNotEmpty) return fromExternal;
  }
  return _readKnownPlatforms(job['platforms']);
}

List<String> _readKnownPlatforms(Object? raw) {
  final Iterable<Object?> values;
  if (raw is List) {
    values = raw;
  } else if (raw is Map<String, dynamic>) {
    values = raw.entries
        .where((MapEntry<String, dynamic> entry) => entry.value != false)
        .map((MapEntry<String, dynamic> entry) => entry.key);
  } else {
    values = const <Object?>[];
  }
  return values
      .whereType<String>()
      .map((String value) => value.toLowerCase().trim())
      .where(_knownSchedulerPlatforms.contains)
      .toSet()
      .toList(growable: false);
}

SchedulerQueueStatus _deriveJobStatus(
  Map<String, dynamic> job,
  String rawStatus,
) {
  final String normalized = rawStatus.toLowerCase();
  if (normalized == 'failed') return SchedulerQueueStatus.failed;
  if (normalized == 'posted') return SchedulerQueueStatus.published;
  if (normalized == 'processing') return SchedulerQueueStatus.publishing;

  final Object? destinationJobs = job['destinationJobs'];
  if (destinationJobs is List) {
    final List<String> statuses = destinationJobs
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> item) => _readString(item['status']) ?? '')
        .map((String value) => value.toLowerCase())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    if (statuses.any((String value) => value == 'failed')) {
      return SchedulerQueueStatus.failed;
    }
    if (statuses.any(
      (String value) => value == 'processing' || value == 'publishing',
    )) {
      return SchedulerQueueStatus.publishing;
    }
    if (statuses.isNotEmpty &&
        statuses.every((String value) => value == 'posted')) {
      return SchedulerQueueStatus.published;
    }
  }
  return SchedulerQueueStatus.scheduled;
}
