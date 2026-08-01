import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/scheduled_post.dart';
import 'content_planning_contract.dart';

/// Cutover PR2: map workspace publishJobs docs → Manage Posts UI model.
ScheduledPost mapPublishJobToScheduledPost({
  required String ownerUserId,
  required Map<String, dynamic> job,
  Map<String, dynamic>? legacyScheduledPost,
}) {
  final String scheduledPostId = (job['scheduledPostId'] ??
          _stripPublishJobPrefix((job['id'] ?? '').toString()))
      .toString()
      .trim();
  final String id =
      scheduledPostId.isNotEmpty ? scheduledPostId : (job['id'] ?? '').toString();
  final Map<String, dynamic> legacy = legacyScheduledPost ?? <String, dynamic>{};
  final String statusName = mapPublishJobStatusToPostStatusName(job['status']);
  final PostStatus status = PostStatus.values.firstWhere(
    (PostStatus s) => s.name == statusName,
    orElse: () => PostStatus.scheduled,
  );
  final DateTime? scheduledAt = parsePublishJobDate(job['scheduledAt']) ??
      parsePublishJobDate(legacy['scheduledAt']) ??
      parsePublishJobDate(
        (legacy['schedule'] is Map)
            ? (legacy['schedule'] as Map)['scheduledAtUtc']
            : null,
      );
  final String timezone = (job['timezone'] ??
          (legacy['schedule'] is Map
              ? (legacy['schedule'] as Map)['timezone']
              : null) ??
          'UTC')
      .toString();
  final DateTime createdAt = parsePublishJobDate(job['createdAt']) ??
      parsePublishJobDate(legacy['createdAt']) ??
      DateTime.now().toUtc();
  final DateTime updatedAt = parsePublishJobDate(job['updatedAt']) ??
      parsePublishJobDate(legacy['updatedAt']) ??
      createdAt;
  final String caption =
      (job['caption'] ?? legacy['caption'] ?? '').toString();
  final String? videoUrl =
      (job['videoUrl'] ?? legacy['videoUrl'])?.toString();
  final String? thumbnailUrl =
      (job['thumbnailUrl'] ?? legacy['thumbnailUrl'])?.toString();
  final String? videoId = (job['videoId'] ?? legacy['videoId'])?.toString();
  final List<PostMedia> media = <PostMedia>[];
  if (videoUrl != null && videoUrl.isNotEmpty) {
    media.add(
      PostMedia(
        id: '${id}_media',
        type: MediaType.video,
        src: (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
            ? thumbnailUrl
            : videoUrl,
        aspectRatio: 9.0 / 16.0,
        durationMs:
            ((legacy['metadata'] is Map ? legacy['metadata']['duration'] : null)
                    as num?)
                ?.toInt() ??
            30000,
      ),
    );
  }
  final List<PlatformConfig> platforms = _mapJobPlatforms(job, legacy);
  final PostSchedule? schedule = scheduledAt == null
      ? null
      : PostSchedule(
          scheduledAtUtc: scheduledAt,
          timezone: timezone,
          perPlatform: <String, PlatformSchedule>{},
          createdAtUtc: createdAt,
          updatedAtUtc: updatedAt,
        );
  return ScheduledPost(
    id: id,
    authorId: (job['ownerId'] ?? legacy['authorId'] ?? ownerUserId).toString(),
    status: status,
    caption: caption,
    tags: List<String>.from(legacy['tags'] ?? const <String>[]),
    visibility: PostVisibility.values.firstWhere(
      (PostVisibility v) => v.name == (legacy['visibility'] ?? 'public'),
      orElse: () => PostVisibility.public,
    ),
    media: media,
    platforms: platforms,
    schedule: schedule,
    analyticsHints: <String, dynamic>{
      ...Map<String, dynamic>.from(
        (legacy['metadata'] is Map)
            ? Map<String, dynamic>.from(legacy['metadata'] as Map)
            : const <String, dynamic>{},
      ),
      if (videoId != null && videoId.isNotEmpty) 'videoId': videoId,
      'postStatus': statusName,
      'publishJobId': job['id'] ?? publishJobIdForScheduledPost(id),
      'contentItemId':
          job['contentItemId'] ?? contentItemIdForScheduledPost(id),
      'idempotencyKey': job['idempotencyKey'] ??
          publishIdempotencyKey(ownerUserId, id),
      'source': 'publishJobs',
      'publishingHistory': (legacy['history'] as List<dynamic>? ?? const [])
          .map(
            (dynamic entry) => Map<String, dynamic>.from(entry as Map),
          )
          .toList(),
    },
    idempotencyKey: (job['idempotencyKey'] ?? legacy['idempotencyKey'])
        ?.toString(),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

String _stripPublishJobPrefix(String jobId) {
  if (jobId.startsWith('pj_')) {
    return jobId.substring(3);
  }
  return jobId;
}

List<PlatformConfig> _mapJobPlatforms(
  Map<String, dynamic> job,
  Map<String, dynamic> legacy,
) {
  final List<dynamic> raw = (job['platforms'] as List<dynamic>?) ??
      (legacy['platforms'] as List<dynamic>?) ??
      const <dynamic>[];
  final List<PlatformConfig> out = <PlatformConfig>[];
  for (final dynamic row in raw) {
    if (row is! Map) {
      continue;
    }
    final Map<String, dynamic> platformData =
        Map<String, dynamic>.from(row);
    final String key = (platformData['platform'] ??
            platformData['key'] ??
            '')
        .toString()
        .toLowerCase();
    if (key.isEmpty) {
      continue;
    }
    out.add(
      PlatformConfig(
        key: key,
        enabled: platformData['enabled'] as bool? ?? true,
        payload: platformData['payload'] is Map
            ? Map<String, dynamic>.from(platformData['payload'] as Map)
            : null,
        status: PlatformStatus.values.firstWhere(
          (PlatformStatus s) =>
              s.name == (platformData['status'] ?? 'pending'),
          orElse: () => PlatformStatus.pending,
        ),
        error: platformData['error']?.toString(),
        scheduledAtUtc: _platformScheduledAt(platformData),
      ),
    );
  }
  return out;
}

DateTime? _platformScheduledAt(Map<String, dynamic> platformData) {
  final Object? raw =
      platformData['scheduledAtUtc'] ?? platformData['scheduledAt'];
  if (raw is Timestamp) {
    return raw.toDate().toUtc();
  }
  return parsePublishJobDate(raw);
}
