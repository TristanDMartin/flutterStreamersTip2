import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/calendar_event.dart';
import 'platform_rules.dart';

/// Canonical Firestore paths aligned with the website (do not add parallel schemas).
abstract final class UserProfileFirestore {
  static const String usersCollection = 'users';
  static const String platformsField = 'platforms';
  /// Stable Edit Profile / linked-URL SoT. Tippy onboarding may still overwrite
  /// [platformsField] with selection stubs — prefer this field when present.
  static const String linkedPlatformsField = 'linkedPlatforms';
  static const String calendarEventsField = 'calendarEvents';
  /// Phase 4 read-only projection rebuilt from contentItems.
  static const String contentPlanProfileCalendarEventsField =
      'contentPlanProfileCalendarEvents';
  /// Phase 4 read-only projection rebuilt from contentItems.
  static const String contentPlanStreamerCalendarEventsField =
      'contentPlanStreamerCalendarEvents';
  /// Public streamer-page mirror on `publicUsers/{uid}` (public events only).
  static const String publicStreamerCalendarEventsField =
      'streamerCalendarEvents';
  static const String connectedPlatformsLegacyField = 'connectedPlatforms';
  static const String connectedPlatformsSubcollection = 'connectedPlatforms';
  static const String contentPlansSubcollection = 'contentPlans';
  static const String onboardingField = 'onboarding';
  static const String onboardingPlatformsField = 'platforms';
  static const String publicUsersCollection = 'publicUsers';

  static String platformsSavePath(String uid) =>
      '$usersCollection/$uid.$platformsField';

  static String calendarSavePath(String uid) =>
      '$usersCollection/$uid.$calendarEventsField';

  static String contentPlansReadPath(String uid) =>
      '$usersCollection/$uid/$contentPlansSubcollection';

  static String profileCalendarProjectionPath(String uid) =>
      '$usersCollection/$uid.$contentPlanProfileCalendarEventsField';

  static String streamerCalendarProjectionPath(String uid) =>
      '$usersCollection/$uid.$contentPlanStreamerCalendarEventsField';

  static String publicStreamerCalendarPath(String uid) =>
      '$publicUsersCollection/$uid.$publicStreamerCalendarEventsField';

  static void logPlatformSave({
    required String uid,
    required String view,
    required int count,
  }) {
    debugPrint(
      'PLATFORM_FIRESTORE_AUDIT uid=$uid view=$view '
      'savePath=${platformsSavePath(uid)} count=$count',
    );
  }

  static void logPlatformRead({
    required String uid,
    required String view,
    required int count,
    String readPath = 'users/{uid}.platforms',
  }) {
    debugPrint(
      'PLATFORM_FIRESTORE_AUDIT uid=$uid view=$view readPath=$readPath '
      'count=$count',
    );
  }

  static void logCalendarSave({
    required String uid,
    required String source,
    required int count,
    String? platformTargets,
  }) {
    debugPrint(
      'CALENDAR_FIRESTORE_AUDIT uid=$uid source=$source '
      'savePath=${calendarSavePath(uid)} count=$count'
      '${platformTargets == null ? '' : ' platformTargets=$platformTargets'}',
    );
  }

  static void logCalendarRead({
    required String uid,
    required String source,
    required int count,
    String readPath = 'users/{uid}.calendarEvents',
  }) {
    debugPrint(
      'CALENDAR_FIRESTORE_AUDIT uid=$uid source=$source '
      'readPath=$readPath count=$count',
    );
  }

  /// Merges a live `users/{uid}` document into a display map for profile UIs.
  /// Preserves [platforms] and [calendarEvents] from Firestore (website + app).
  static Map<String, dynamic> mergeDisplayUserData({
    required Map<String, dynamic> fresh,
    Map<String, dynamic>? seed,
  }) {
    final Map<String, dynamic> base = seed != null
        ? Map<String, dynamic>.from(seed)
        : <String, dynamic>{};
    base.addAll(fresh);
    if (fresh.containsKey(linkedPlatformsField)) {
      base[linkedPlatformsField] = fresh[linkedPlatformsField];
    }
    if (fresh.containsKey(platformsField)) {
      base[platformsField] = fresh[platformsField];
    }
    if (fresh.containsKey(calendarEventsField)) {
      base[calendarEventsField] = fresh[calendarEventsField];
    }
    if (fresh.containsKey(contentPlanProfileCalendarEventsField)) {
      base[contentPlanProfileCalendarEventsField] =
          fresh[contentPlanProfileCalendarEventsField];
    }
    if (fresh.containsKey(contentPlanStreamerCalendarEventsField)) {
      base[contentPlanStreamerCalendarEventsField] =
          fresh[contentPlanStreamerCalendarEventsField];
    }
    if (fresh.containsKey(publicStreamerCalendarEventsField)) {
      base[publicStreamerCalendarEventsField] =
          fresh[publicStreamerCalendarEventsField];
    }
    final String? uid = (fresh['uid'] ?? fresh['id'] ?? base['uid'] ?? base['id'])
        ?.toString();
    if (uid != null && uid.isNotEmpty) {
      base['id'] ??= uid;
      base['uid'] ??= uid;
    }
    return base;
  }

  static String readPlatformType(Map<String, dynamic> raw) {
    final Object? type = raw['type'] ?? raw['platformType'];
    return PlatformRules.normalizePlatformType(type?.toString() ?? 'other');
  }

  static List<Map<String, dynamic>> parsePlatformsFromUserData(
    Map<String, dynamic>? userData, {
    List<Map<String, dynamic>>? legacyConnectedPlatforms,
    bool connectedOnly = false,
  }) {
    if (userData == null) {
      return <Map<String, dynamic>>[];
    }
    final List<Map<String, dynamic>> fromLinked =
        _parsePlatformsArray(
      userData[linkedPlatformsField],
      connectedOnly: connectedOnly,
    );
    if (fromLinked.isNotEmpty) {
      return fromLinked;
    }
    final List<Map<String, dynamic>> fromArray =
        _parsePlatformsArray(
      userData[platformsField],
      connectedOnly: connectedOnly,
    );
    if (fromArray.isNotEmpty) {
      return fromArray;
    }
    final List<Map<String, dynamic>> fromLegacyField =
        _parsePlatformsArray(
      userData[connectedPlatformsLegacyField],
      connectedOnly: connectedOnly,
    );
    if (fromLegacyField.isNotEmpty) {
      return fromLegacyField;
    }
    if (legacyConnectedPlatforms != null &&
        legacyConnectedPlatforms.isNotEmpty) {
      return _parsePlatformsArray(
        legacyConnectedPlatforms,
        connectedOnly: connectedOnly,
      );
    }
    if (connectedOnly) {
      return <Map<String, dynamic>>[];
    }
    final Object? onboardingRaw = userData[onboardingField];
    if (onboardingRaw is Map) {
      final Object? selectedRaw =
          onboardingRaw[onboardingPlatformsField];
      if (selectedRaw is List && selectedRaw.isNotEmpty) {
        return platformStubsFromSelection(
          selectedRaw.map((Object? e) => e.toString()).toList(),
        );
      }
    }
    return <Map<String, dynamic>>[];
  }

  /// Seeds canonical [platformsField] rows from onboarding platform picks.
  static List<Map<String, dynamic>> platformStubsFromSelection(
    List<String> selectedPlatforms,
  ) {
    final List<Map<String, dynamic>> stubs = <Map<String, dynamic>>[];
    final Set<String> seenTypes = <String>{};
    for (final String raw in selectedPlatforms) {
      final String type = PlatformRules.normalizePlatformType(raw);
      if (type.isEmpty || seenTypes.contains(type)) {
        continue;
      }
      seenTypes.add(type);
      stubs.add(<String, dynamic>{
        'id': 'onboarding_$type',
        'type': type,
        'platformType': type,
        'displayName': PlatformRules.displayNameForType(type),
        'username': '',
        'followers': 0,
        'url': null,
        'isConnected': false,
        'isVerified': false,
        'isAdultGated': PlatformRules.isAgeRestrictedType(type),
      });
    }
    return stubs;
  }

  static List<Map<String, dynamic>> _parsePlatformsArray(
    Object? raw, {
    bool connectedOnly = false,
  }) {
    final List<Object?> entries = _coercePlatformEntries(raw);
    if (entries.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    for (final Object? entry in entries) {
      final Map<String, dynamic>? map = _asMap(entry);
      if (map == null) {
        continue;
      }
      final String type = readPlatformType(map);
      String username = (map['username']?.toString() ?? '').trim();
      if (username.startsWith('@')) {
        username = username.substring(1);
      }
      String url = (map['url']?.toString() ?? '').trim();
      if (url.isEmpty && username.isNotEmpty) {
        url = PlatformRules.previewPlatformUrl(type, username) ?? '';
      }
      if (username.isEmpty && url.isNotEmpty) {
        username = _usernameFromPlatformUrl(type, url);
      }
      final String id = map['id']?.toString() ?? '';
      final bool isOnboardingStub = map['isConnected'] == false ||
          id.startsWith('tippy_') ||
          id.startsWith('onboarding_') ||
          (username.isEmpty &&
              url.isEmpty &&
              PlatformRules.editablePlatformTypes.contains(type));
      final bool hasLink = username.isNotEmpty || url.isNotEmpty;
      if (!hasLink && (connectedOnly || !isOnboardingStub)) {
        continue;
      }
      if (connectedOnly && !hasLink) {
        continue;
      }
      out.add(<String, dynamic>{
        'id': id.isNotEmpty
            ? id
            : '${type}_${out.length}_${DateTime.now().millisecondsSinceEpoch}',
        'type': type,
        'platformType': type,
        'displayName':
            map['displayName']?.toString() ?? PlatformRules.displayNameForType(type),
        'username': username,
        'followers': (map['followers'] as num?)?.toInt() ?? 0,
        'url': url.isEmpty ? null : url,
        'isConnected': map['isConnected'] ?? hasLink,
        'isVerified': map['isVerified'] ?? false,
        'isAdultGated': map['isAdultGated'] ?? PlatformRules.isAgeRestrictedType(type),
      });
    }
    return out;
  }

  /// Accepts List rows or legacy Map keyed by platform type.
  static List<Object?> _coercePlatformEntries(Object? raw) {
    if (raw is List) {
      return raw;
    }
    if (raw is Map) {
      final List<Object?> out = <Object?>[];
      raw.forEach((Object? key, Object? value) {
        if (value is Map) {
          out.add(<String, dynamic>{
            'type': key?.toString() ?? 'other',
            ...Map<String, dynamic>.from(value),
          });
          return;
        }
        if (value is String && value.trim().isNotEmpty) {
          final String type = key?.toString() ?? 'other';
          final String trimmed = value.trim();
          final bool looksLikeUrl = trimmed.startsWith('http') ||
              trimmed.contains('.');
          out.add(<String, dynamic>{
            'type': type,
            'url': looksLikeUrl
                ? (trimmed.startsWith('http') ? trimmed : 'https://$trimmed')
                : PlatformRules.previewPlatformUrl(type, trimmed),
            'username': looksLikeUrl ? '' : trimmed.replaceFirst(RegExp(r'^@+'), ''),
          });
        }
      });
      return out;
    }
    return const <Object?>[];
  }

  static String _usernameFromPlatformUrl(String type, String url) {
    try {
      final Uri uri = Uri.parse(
        url.startsWith('http') ? url : 'https://$url',
      );
      final List<String> parts = uri.pathSegments
          .where((String s) => s.isNotEmpty)
          .toList(growable: false);
      if (parts.isEmpty) {
        return '';
      }
      final String normalized = PlatformRules.normalizePlatformType(type);
      if (normalized == 'reddit' &&
          parts.length >= 2 &&
          (parts.first == 'user' || parts.first == 'u')) {
        return parts[1].replaceFirst(RegExp(r'^@+'), '');
      }
      if (normalized == 'discord' &&
          parts.isNotEmpty &&
          (parts.first == 'invite' || parts.first == 'channels')) {
        return parts.length > 1 ? parts[1] : parts.first;
      }
      return parts.last.replaceFirst(RegExp(r'^@+'), '');
    } catch (_) {
      return '';
    }
  }

  static List<CalendarEvent> parseCalendarEventsFromUserData(
    Map<String, dynamic>? userData,
  ) {
    return _parseCalendarEventList(
      userData == null ? null : userData[calendarEventsField],
    );
  }

  /// Phase 4: profile calendar projection (`contentPlanProfileCalendarEvents`).
  static List<CalendarEvent> parseProfileCalendarProjection(
    Map<String, dynamic>? userData,
  ) {
    return _parseCalendarEventList(
      userData == null ? null : userData[contentPlanProfileCalendarEventsField],
    );
  }

  /// Phase 4: streamer calendar projection (`contentPlanStreamerCalendarEvents`).
  static List<CalendarEvent> parseStreamerCalendarProjection(
    Map<String, dynamic>? userData,
  ) {
    return _parseCalendarEventList(
      userData == null
          ? null
          : userData[contentPlanStreamerCalendarEventsField],
    );
  }

  /// Public streamer page mirror (`publicUsers.streamerCalendarEvents`).
  static List<CalendarEvent> parsePublicStreamerCalendarEvents(
    Map<String, dynamic>? userData,
  ) {
    return _parseCalendarEventList(
      userData == null ? null : userData[publicStreamerCalendarEventsField],
    );
  }

  /// Streamer-facing calendar rows — matches website `subscribeToCalendarEvents`.
  /// Owner: `users.contentPlanStreamerCalendarEvents`.
  /// Visitor: `publicUsers.streamerCalendarEvents`.
  static List<CalendarEvent> parseStreamerFacingCalendarEvents(
    Map<String, dynamic>? userData, {
    required bool viewerIsOwner,
  }) {
    if (viewerIsOwner) {
      return parseStreamerCalendarProjection(userData);
    }
    final List<CalendarEvent> publicEvents =
        parsePublicStreamerCalendarEvents(userData);
    if (publicEvents.isNotEmpty) {
      return publicEvents;
    }
    // Older public docs may still carry the private-users field name.
    return parseStreamerCalendarProjection(userData);
  }

  static List<CalendarEvent> _parseCalendarEventList(Object? raw) {
    if (raw is! List) {
      return <CalendarEvent>[];
    }
    final List<CalendarEvent> events = <CalendarEvent>[];
    for (final Object? entry in raw) {
      final Map<String, dynamic>? map = _asMap(entry);
      if (map == null) {
        continue;
      }
      final String title = (map['title']?.toString() ?? '').trim();
      if (title.isEmpty) {
        continue;
      }
      final DateTime? date = _parseEventDate(
        map['date'] ??
            map['startsAt'] ??
            map['scheduledAt'] ??
            map['startTime'] ??
            map['startDate'] ??
            map['eventDate'],
      );
      if (date == null) {
        continue;
      }
      final String id = map['id']?.toString().trim().isNotEmpty == true
          ? map['id'].toString()
          : 'evt_${title.hashCode}_${date.millisecondsSinceEpoch}';
      events.add(
        CalendarEvent(
          id: id,
          title: title,
          description: (map['description']?.toString() ?? '').trim(),
          date: date,
        ),
      );
    }
    events.sort((CalendarEvent a, CalendarEvent b) => a.date.compareTo(b.date));
    return events;
  }

  /// Read-only fallback: map Tippy / content planner docs into calendar rows.
  /// Prefer [parseProfileCalendarProjection] when mirrors are present (Phase 4).
  /// Event ids match website mirrors: `cp-{planId}-{itemId}`.
  static List<CalendarEvent> calendarEventsFromContentPlanDocs(
    Iterable<Map<String, dynamic>> planDocs,
  ) {
    final List<CalendarEvent> derived = <CalendarEvent>[];
    for (final Map<String, dynamic> plan in planDocs) {
      final String planId = plan['id']?.toString() ?? '';
      final String planTitle =
          (plan['title']?.toString() ?? 'Content plan').trim();
      final Object? itemsRaw = plan['items'];
      if (itemsRaw is! List) {
        final DateTime? planDate = _parseEventDate(
          plan['scheduledAt'] ?? plan['scheduledFor'],
        );
        if (planDate != null && planTitle.isNotEmpty) {
          derived.add(
            CalendarEvent(
              id: planId.isEmpty ? 'plan_root' : 'cp-$planId-root',
              title: planTitle,
              description: (plan['description']?.toString() ?? '').trim(),
              date: planDate,
            ),
          );
        }
        continue;
      }
      for (final Object? itemRaw in itemsRaw) {
        final Map<String, dynamic>? item = _asMap(itemRaw);
        if (item == null) {
          continue;
        }
        final String itemId = (item['id']?.toString() ?? '').trim();
        if (itemId.isEmpty || planId.isEmpty) {
          continue;
        }
        final String itemTitle =
            (item['title']?.toString() ?? planTitle).trim();
        final String profileVis =
            (item['profileCalendar']?.toString() ?? 'public').toLowerCase();
        if (profileVis == 'hidden') {
          continue;
        }
        final Object? platformsRaw = item['platforms'];
        DateTime? when;
        String platName = '';
        if (platformsRaw is List && platformsRaw.isNotEmpty) {
          final Map<String, dynamic>? plat = _asMap(platformsRaw.first);
          when = _parseEventDate(plat?['scheduledAt']);
          platName = plat?['platform']?.toString() ?? '';
        } else {
          when = _parseEventDate(item['scheduledAt'] ?? plan['scheduledAt']);
        }
        if (when == null || itemTitle.isEmpty) {
          continue;
        }
        derived.add(
          CalendarEvent(
            id: 'cp-$planId-$itemId',
            title: itemTitle,
            description: platName.isEmpty
                ? 'Content plan'
                : 'Content plan · $platName',
            date: when,
          ),
        );
      }
    }
    derived.sort((CalendarEvent a, CalendarEvent b) => a.date.compareTo(b.date));
    return derived;
  }

  /// Parse website-style `cp-{planId}-{itemId}` calendar event ids.
  static ({String planId, String itemId})? parseContentPlanEventRef(
    String eventId,
  ) {
    final String id = eventId.trim();
    if (!id.startsWith('cp-')) {
      return null;
    }
    final RegExpMatch? match = RegExp(r'^cp-([A-Za-z0-9_-]+)-(.+)$').firstMatch(id);
    if (match == null) {
      return null;
    }
    final String planId = match.group(1) ?? '';
    final String itemId = match.group(2) ?? '';
    if (planId.isEmpty || itemId.isEmpty || itemId == 'root') {
      return null;
    }
    return (planId: planId, itemId: itemId);
  }

  static List<CalendarEvent> mergeCalendarEventLists(
    List<CalendarEvent> primary,
    List<CalendarEvent> secondary,
  ) {
    final Map<String, CalendarEvent> byId = <String, CalendarEvent>{};
    for (final CalendarEvent event in primary) {
      byId[event.id] = event;
    }
    for (final CalendarEvent event in secondary) {
      byId.putIfAbsent(event.id, () => event);
    }
    final List<CalendarEvent> merged = byId.values.toList(growable: false);
    merged.sort((CalendarEvent a, CalendarEvent b) => a.date.compareTo(b.date));
    return merged;
  }

  static List<Map<String, dynamic>> normalizePlatformsForFirestore(
    List<Map<String, dynamic>> platforms,
  ) {
    final List<Map<String, dynamic>> base =
        PlatformRules.normalizePlatformsForSave(platforms);
    final List<Map<String, dynamic>> enriched = <Map<String, dynamic>>[];
    final DateTime now = DateTime.now();
    for (final Map<String, dynamic> raw in base) {
      final String type = readPlatformType(raw);
      final String username = (raw['username']?.toString() ?? '').trim();
      final String url = (raw['url']?.toString() ?? '').trim();
      final bool isStub =
          raw['isConnected'] == false || (username.isEmpty && url.isEmpty);
      final Map<String, dynamic> row = <String, dynamic>{
        'id': raw['id']?.toString() ??
            '${type}_${now.millisecondsSinceEpoch}',
        'type': type,
        'platformType': type,
        'displayName': PlatformRules.displayNameForType(type),
        'username': username,
        'followers': (raw['followers'] as num?)?.toInt() ?? 0,
        'isConnected': raw['isConnected'] ?? !isStub,
        'isVerified': raw['isVerified'] ?? false,
        'isAdultGated': PlatformRules.isAgeRestrictedType(type),
        'updatedAt': Timestamp.fromDate(now),
        if (!raw.containsKey('createdAt')) 'createdAt': Timestamp.fromDate(now),
      };
      if (url.isNotEmpty) {
        row['url'] = url;
      }
      if (raw.containsKey('isConnected')) {
        row['isConnected'] = raw['isConnected'];
      }
      enriched.add(row);
    }
    return enriched;
  }

  /// Public mirror payload for [publicUsers] (peer profile / streamer card reads).
  /// Only linked platforms — never Tippy empty stubs.
  static List<Map<String, dynamic>> platformsForPublicMirror(
    List<Map<String, dynamic>> platforms,
  ) {
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    for (final Map<String, dynamic> raw in platforms) {
      final String type = readPlatformType(raw);
      final String username = (raw['username']?.toString() ?? '').trim();
      final String url = (raw['url']?.toString() ?? '').trim();
      if (username.isEmpty && url.isEmpty) {
        continue;
      }
      final Map<String, dynamic> row = <String, dynamic>{
        'id': raw['id']?.toString() ?? 'platform_$type',
        'type': type,
        'platformType': type,
        'displayName':
            raw['displayName']?.toString() ?? PlatformRules.displayNameForType(type),
        'username': username,
        'followers': (raw['followers'] as num?)?.toInt() ?? 0,
        'isConnected': true,
        'isVerified': raw['isVerified'] ?? false,
        'isAdultGated':
            raw['isAdultGated'] ?? PlatformRules.isAgeRestrictedType(type),
      };
      if (url.isNotEmpty) {
        row['url'] = url;
      } else if (username.isNotEmpty) {
        final String? preview =
            PlatformRules.previewPlatformUrl(type, username);
        if (preview != null && preview.isNotEmpty) {
          row['url'] = preview;
        }
      }
      out.add(row);
    }
    return out;
  }

  static List<Map<String, dynamic>> calendarEventsToFirestore(
    List<CalendarEvent> events,
  ) {
    return events.map((CalendarEvent e) => e.toMap()).toList(growable: false);
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static DateTime? _parseEventDate(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }
}
