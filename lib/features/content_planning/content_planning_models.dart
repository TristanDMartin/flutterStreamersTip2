import 'package:cloud_firestore/cloud_firestore.dart';

import 'content_planning_contract.dart';

/// One row inside a saved content plan (Firestore / Tippy).
class ContentPlanItem {
  const ContentPlanItem({
    required this.id,
    required this.title,
    this.description,
    this.caption,
    this.type,
    this.status,
    this.notes,
    this.tags = const <String>[],
    this.platforms = const <Map<String, dynamic>>[],
    this.version,
  });

  final String id;
  final String title;
  final String? description;
  final String? caption;
  final String? type;
  final String? status;
  final String? notes;
  final List<String> tags;
  final List<Map<String, dynamic>> platforms;
  /// Workspace optimistic concurrency counter (Phase 5).
  final int? version;

  factory ContentPlanItem.fromJson(dynamic raw) {
    if (raw == null) {
      return const ContentPlanItem(
        id: '',
        title: '',
        tags: <String>[],
        platforms: <Map<String, dynamic>>[],
      );
    }
    final Map<String, dynamic> m = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    final Object? rawPlats = m['platforms'];
    final List<Map<String, dynamic>> plats = <Map<String, dynamic>>[];
    if (rawPlats is List) {
      for (final Object? p in rawPlats) {
        if (p is Map<String, dynamic>) {
          plats.add(p);
        } else if (p is Map) {
          plats.add(Map<String, dynamic>.from(p));
        }
      }
    }
    return ContentPlanItem(
      id: _readString(m['id']) ?? '',
      title: _readString(m['title']) ?? 'Untitled step',
      description: _readString(m['description']),
      caption: _readString(m['caption']),
      type: normalizeContentItemType(m['type'] ?? m['contentType']),
      status: normalizeContentItemStatus(m['status']),
      notes: _readString(m['notes']),
      tags: _readStringList(m['tags']),
      platforms: plats,
      version: _readNullableInt(m['version']),
    );
  }

  ContentPlanItem copyWith({
    String? id,
    String? title,
    String? description,
    String? caption,
    String? type,
    String? status,
    String? notes,
    List<String>? tags,
    List<Map<String, dynamic>>? platforms,
    int? version,
  }) {
    return ContentPlanItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      caption: caption ?? this.caption,
      type: type ?? this.type,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      platforms: platforms ?? this.platforms,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      if (description != null && description!.trim().isNotEmpty)
        'description': description,
      if (caption != null && caption!.trim().isNotEmpty) 'caption': caption,
      if (type != null && type!.trim().isNotEmpty) 'type': type,
      if (status != null && status!.trim().isNotEmpty) 'status': status,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes,
      if (tags.isNotEmpty) 'tags': tags,
      'platforms': platforms.map(_platformEntryToFirestore).toList(),
      if (version != null) 'version': version,
    };
  }

  String get platformsSummary {
    if (platforms.isEmpty) {
      return '';
    }
    return platforms.map((Map<String, dynamic> p) {
      final String plat = _readString(p['platform']) ?? 'platform';
      final Object? at = p['scheduledAt'];
      String when = '';
      if (at is Timestamp) {
        when = at.toDate().toLocal().toString().split('.').first;
      } else if (at is DateTime) {
        when = at.toLocal().toString().split('.').first;
      }
      return when.isEmpty ? plat : '$plat · $when';
    }).join('\n');
  }

  /// Earliest platform schedule time for this plan item.
  DateTime? get earliestScheduledAt {
    final List<DateTime> candidates = <DateTime>[];
    for (final Map<String, dynamic> platform in platforms) {
      final DateTime? at = _readDate(
        platform['scheduledAt'] ?? platform['scheduledAtUtc'],
      );
      if (at != null) {
        candidates.add(at);
      }
    }
    if (candidates.isEmpty) {
      return null;
    }
    candidates.sort((DateTime a, DateTime b) => a.compareTo(b));
    return candidates.first;
  }

  bool get isClosed {
    return isClosedContentItemStatus(status);
  }

  /// Open item with a concrete schedule (Tippy plans keep these on platforms).
  bool get isQueuedSchedule {
    if (!isQueuedScheduleStatus(status)) {
      return false;
    }
    return earliestScheduledAt != null;
  }
}

Map<String, dynamic> _platformEntryToFirestore(Map<String, dynamic> raw) {
  final Map<String, dynamic> out = Map<String, dynamic>.from(raw);
  final Object? at = out['scheduledAt'];
  if (at is DateTime) {
    out['scheduledAt'] = Timestamp.fromDate(at);
  } else if (at is String) {
    final DateTime? parsed = DateTime.tryParse(at);
    if (parsed != null) {
      out['scheduledAt'] = Timestamp.fromDate(parsed.toUtc());
    }
  }
  return out;
}

class ContentPlan {
  const ContentPlan({
    required this.id,
    required this.title,
    required this.itemCount,
    required this.userId,
    this.description,
    this.platform,
    this.contentType,
    this.caption,
    this.hashtags = const <String>[],
    this.status = 'draft',
    this.scheduledAt,
    this.createdAt,
    this.updatedAt,
    this.source,
    this.checklist = const <String>[],
    this.notes,
    this.draftIdeas = const <String>[],
    this.items = const <ContentPlanItem>[],
  });

  final String id;
  final String title;
  final int itemCount;
  final String userId;
  final String? description;
  final String? platform;
  final String? contentType;
  final String? caption;
  final List<String> hashtags;
  final String status;
  final DateTime? scheduledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? source;
  final List<String> checklist;
  final String? notes;
  final List<String> draftIdeas;
  final List<ContentPlanItem> items;

  factory ContentPlan.fromJson(Map<String, dynamic> json) {
    final Object? rawItems = json['items'];
    final List<ContentPlanItem> parsedItems = _parseItems(rawItems);
    final int count = parsedItems.isNotEmpty
        ? parsedItems.length
        : _readInt(json['itemCount'] ?? json['itemsCount']);
    return ContentPlan(
      id: _readString(json['id']) ?? _readString(json['planId']) ?? '',
      title: _readString(json['title']) ?? 'Untitled plan',
      userId: _readString(json['ownerUid'] ?? json['userId']) ?? '',
      description: _readString(json['description']),
      platform: _readString(json['platform']) ??
          _firstString(_readStringList(json['platformTargets'])),
      contentType: normalizeContentItemType(json['contentType'] ?? json['type']),
      caption: _readString(json['caption']),
      hashtags: _readStringList(
          json['hashtags'] ?? json['tags'] ?? json['platformTargets']),
      status: normalizeContentItemStatus(json['status']),
      scheduledAt: _readDate(
        json['scheduledFor'] ?? json['scheduledAt'] ?? json['scheduledAtUtc'],
      ),
      createdAt: _readDate(json['createdAt']),
      itemCount: count,
      updatedAt: _readDate(json['updatedAt'] ?? json['createdAt']),
      source: normalizeContentSource(json['source']) ??
          _readString(json['source']),
      checklist: _readStringList(json['checklist']),
      notes: _readString(json['notes']),
      draftIdeas: _readStringList(json['draftIdeas'] ?? json['ideas']),
      items: parsedItems,
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return <String, dynamic>{
      'title': title,
      'ownerUid': userId,
      'description': description,
      'platform': platform,
      'platformTargets': platform == null || platform!.trim().isEmpty
          ? hashtags
          : <String>[platform!, ...hashtags.where((h) => h != platform)],
      'contentType': contentType,
      'caption': caption,
      'hashtags': hashtags,
      'status': status,
      'scheduledAt':
          scheduledAt == null ? null : Timestamp.fromDate(scheduledAt!),
      'scheduledFor':
          scheduledAt == null ? null : Timestamp.fromDate(scheduledAt!),
      'checklist': checklist,
      'notes': notes,
      'draftIdeas': draftIdeas,
      'items': items.map((ContentPlanItem e) => e.toFirestoreMap()).toList(),
      'itemCount': items.isEmpty ? itemCount : items.length,
    };
  }

  ContentPlan copyWith({
    String? title,
    String? description,
    String? platform,
    String? contentType,
    String? caption,
    List<String>? hashtags,
    String? status,
    DateTime? scheduledAt,
    List<String>? checklist,
    String? notes,
    List<String>? draftIdeas,
    List<ContentPlanItem>? items,
    int? itemCount,
  }) {
    return ContentPlan(
      id: id,
      title: title ?? this.title,
      userId: userId,
      description: description ?? this.description,
      platform: platform ?? this.platform,
      contentType: contentType ?? this.contentType,
      caption: caption ?? this.caption,
      hashtags: hashtags ?? this.hashtags,
      status: status ?? this.status,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      createdAt: createdAt,
      itemCount: itemCount ?? this.itemCount,
      updatedAt: updatedAt,
      source: source,
      checklist: checklist ?? this.checklist,
      notes: notes ?? this.notes,
      draftIdeas: draftIdeas ?? this.draftIdeas,
      items: items ?? this.items,
    );
  }
}

List<ContentPlanItem> _parseItems(Object? raw) {
  if (raw is! List) {
    return const <ContentPlanItem>[];
  }
  final List<ContentPlanItem> out = <ContentPlanItem>[];
  for (final Object? e in raw) {
    if (e == null) {
      continue;
    }
    final ContentPlanItem item = ContentPlanItem.fromJson(e);
    if (item.title.isNotEmpty || item.id.isNotEmpty) {
      out.add(item);
    }
  }
  return out;
}

String? _firstString(List<String> values) {
  for (final String value in values) {
    if (value.trim().isNotEmpty) return value;
  }
  return null;
}

String? _readString(Object? raw) {
  if (raw is String && raw.trim().isNotEmpty) {
    return raw.trim();
  }
  return null;
}

List<String> _readStringList(Object? raw) {
  if (raw is! List) return const <String>[];
  return raw.map(_readString).whereType<String>().toList(growable: false);
}

int _readInt(Object? raw) {
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.round();
  }
  if (raw is String) {
    return int.tryParse(raw) ?? 0;
  }
  return 0;
}

int? _readNullableInt(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.round();
  }
  if (raw is String) {
    return int.tryParse(raw);
  }
  return null;
}

DateTime? _readDate(Object? raw) {
  if (raw is Timestamp) {
    return raw.toDate();
  }
  if (raw is DateTime) {
    return raw;
  }
  if (raw is String) {
    return DateTime.tryParse(raw);
  }
  return null;
}
