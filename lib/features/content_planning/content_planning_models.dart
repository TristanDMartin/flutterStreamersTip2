import 'package:cloud_firestore/cloud_firestore.dart';

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
    this.platforms = const <Map<String, dynamic>>[],
  });

  final String id;
  final String title;
  final String? description;
  final String? caption;
  final String? type;
  final String? status;
  final String? notes;
  final List<Map<String, dynamic>> platforms;

  factory ContentPlanItem.fromJson(dynamic raw) {
    if (raw == null) {
      return const ContentPlanItem(id: '', title: '', platforms: <Map<String, dynamic>>[]);
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
      type: _readString(m['type'] ?? m['contentType']),
      status: _readString(m['status']),
      notes: _readString(m['notes']),
      platforms: plats,
    );
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
      }
      return when.isEmpty ? plat : '$plat · $when';
    }).join('\n');
  }
}

class ContentPlan {
  const ContentPlan({
    required this.id,
    required this.title,
    required this.itemCount,
    this.description,
    this.updatedAt,
    this.items = const <ContentPlanItem>[],
  });

  final String id;
  final String title;
  final int itemCount;
  final String? description;
  final DateTime? updatedAt;
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
      description: _readString(json['description']),
      itemCount: count,
      updatedAt: _readDate(json['updatedAt'] ?? json['createdAt']),
      items: parsedItems,
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

String? _readString(Object? raw) {
  if (raw is String && raw.trim().isNotEmpty) {
    return raw.trim();
  }
  return null;
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
