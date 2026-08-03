import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/models/calendar_event.dart';
import 'package:streamers_tip/utils/user_profile_firestore.dart';

void main() {
  group('UserProfileFirestore', () {
    test('parsePlatforms supports type and platformType', () {
      final List<Map<String, dynamic>> platforms =
          UserProfileFirestore.parsePlatformsFromUserData(<String, dynamic>{
        'platforms': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': '1',
            'platformType': 'patreon',
            'username': 'creator',
            'url': 'https://www.patreon.com/creator',
          },
        ],
      });
      expect(platforms.length, 1);
      expect(platforms.first['type'], 'patreon');
      expect(platforms.first['isAdultGated'], true);
    });

    test('connectedOnly hides empty tippy stubs', () {
      final List<Map<String, dynamic>> connected =
          UserProfileFirestore.parsePlatformsFromUserData(
        <String, dynamic>{
          'platforms': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'tippy_twitch',
              'type': 'twitch',
              'username': '',
              'url': null,
              'isConnected': false,
            },
            <String, dynamic>{
              'id': '2',
              'type': 'youtube',
              'username': 'technqs',
              'url': '',
            },
          ],
        },
        connectedOnly: true,
      );
      expect(connected.length, 1);
      expect(connected.first['type'], 'youtube');
      expect(connected.first['url'], 'https://www.youtube.com/@technqs');
    });

    test('parses legacy map-shaped platforms', () {
      final List<Map<String, dynamic>> platforms =
          UserProfileFirestore.parsePlatformsFromUserData(
        <String, dynamic>{
          'platforms': <String, dynamic>{
            'twitch': 'technqs',
            'instagram': <String, dynamic>{
              'username': 'tech',
              'url': 'https://instagram.com/tech',
            },
          },
        },
        connectedOnly: true,
      );
      expect(platforms.length, 2);
      expect(
        platforms.any((Map<String, dynamic> p) => p['type'] == 'twitch'),
        isTrue,
      );
    });

    test('parseCalendarEvents generates id when missing', () {
      final events = UserProfileFirestore.parseCalendarEventsFromUserData(
        <String, dynamic>{
          'calendarEvents': <Map<String, dynamic>>[
            <String, dynamic>{
              'title': 'Live',
              'date': Timestamp.fromDate(DateTime(2026, 6, 2)),
            },
          ],
        },
      );
      expect(events.length, 1);
      expect(events.first.id.isNotEmpty, true);
    });

    test('parseCalendarEvents allows empty description', () {
      final events = UserProfileFirestore.parseCalendarEventsFromUserData(
        <String, dynamic>{
          'calendarEvents': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'e1',
              'title': 'Stream',
              'date': Timestamp.fromDate(DateTime(2026, 6, 2)),
            },
          ],
        },
      );
      expect(events.length, 1);
      expect(events.first.description, '');
    });

    test('parseProfileCalendarProjection reads Phase 4 mirrors', () {
      final events = UserProfileFirestore.parseProfileCalendarProjection(
        <String, dynamic>{
          'contentPlanProfileCalendarEvents': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'cp-plan1-item1',
              'title': 'Tippy stream',
              'description': 'plan · stream',
              'date': Timestamp.fromDate(DateTime(2026, 7, 1)),
            },
          ],
        },
      );
      expect(events.length, 1);
      expect(events.first.id, 'cp-plan1-item1');
      expect(events.first.title, 'Tippy stream');
    });

    test('parseStreamerCalendarProjection reads Phase 4 mirrors', () {
      final events = UserProfileFirestore.parseStreamerCalendarProjection(
        <String, dynamic>{
          'contentPlanStreamerCalendarEvents': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'cp-plan1-item2',
              'title': 'Public clip',
              'date': Timestamp.fromDate(DateTime(2026, 7, 2)),
            },
          ],
        },
      );
      expect(events.length, 1);
      expect(events.first.id, 'cp-plan1-item2');
    });

    test('parsePublicStreamerCalendarEvents reads publicUsers mirror', () {
      final events = UserProfileFirestore.parsePublicStreamerCalendarEvents(
        <String, dynamic>{
          'streamerCalendarEvents': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'cp-plan1-item3',
              'title': 'Public stream',
              'startsAt': Timestamp.fromDate(DateTime(2026, 8, 1, 18)),
            },
          ],
        },
      );
      expect(events.length, 1);
      expect(events.first.id, 'cp-plan1-item3');
      expect(events.first.title, 'Public stream');
    });

    test('parseStreamerFacingCalendarEvents uses public mirror for visitors',
        () {
      final List<CalendarEvent> events =
          UserProfileFirestore.parseStreamerFacingCalendarEvents(
        <String, dynamic>{
          'streamerCalendarEvents': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'cp-a-b',
              'title': 'Visitor visible',
              'date': Timestamp.fromDate(DateTime(2026, 8, 2)),
            },
          ],
          'contentPlanStreamerCalendarEvents': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'cp-private',
              'title': 'Should not win',
              'date': Timestamp.fromDate(DateTime(2026, 8, 3)),
            },
          ],
          'calendarEvents': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'legacy',
              'title': 'Profile only',
              'date': Timestamp.fromDate(DateTime(2026, 8, 4)),
            },
          ],
        },
        viewerIsOwner: false,
      );
      expect(events.length, 1);
      expect(events.first.id, 'cp-a-b');
    });

    test('parseStreamerFacingCalendarEvents uses streamer projection for owner',
        () {
      final List<CalendarEvent> events =
          UserProfileFirestore.parseStreamerFacingCalendarEvents(
        <String, dynamic>{
          'contentPlanStreamerCalendarEvents': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'cp-owner',
              'title': 'Owner stream',
              'date': Timestamp.fromDate(DateTime(2026, 8, 5)),
            },
          ],
          'calendarEvents': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'legacy',
              'title': 'Profile only',
              'date': Timestamp.fromDate(DateTime(2026, 8, 6)),
            },
          ],
        },
        viewerIsOwner: true,
      );
      expect(events.length, 1);
      expect(events.first.id, 'cp-owner');
    });

    test('parsePlatforms falls back to onboarding platform selection', () {
      final List<Map<String, dynamic>> platforms =
          UserProfileFirestore.parsePlatformsFromUserData(<String, dynamic>{
        'onboarding': <String, dynamic>{
          'platforms': <String>['twitch', 'youtube'],
        },
      });
      expect(platforms.length, 2);
      expect(platforms.first['type'], 'twitch');
      expect(platforms.first['isConnected'], false);
    });

    test('normalizePlatformsForFirestore preserves Tippy empty stubs', () {
      final List<Map<String, dynamic>> normalized =
          UserProfileFirestore.normalizePlatformsForFirestore(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'tippy_twitch',
            'type': 'twitch',
            'platformType': 'twitch',
            'username': '',
            'url': null,
            'isConnected': false,
            'followers': 0,
          },
        ],
      );
      expect(normalized.length, 1);
      expect(normalized.first['isConnected'], false);
      final List<Map<String, dynamic>> parsed =
          UserProfileFirestore.parsePlatformsFromUserData(<String, dynamic>{
        'platforms': normalized,
      });
      expect(parsed.length, 1);
      expect(parsed.first['type'], 'twitch');
      expect(parsed.first['isConnected'], false);
    });

    test('parsePlatforms keeps tippy stubs even when isConnected was lost', () {
      final List<Map<String, dynamic>> platforms =
          UserProfileFirestore.parsePlatformsFromUserData(<String, dynamic>{
        'platforms': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'tippy_youtube',
            'type': 'youtube',
            'username': '',
            'url': null,
            'isConnected': true,
          },
        ],
      });
      expect(platforms.length, 1);
      expect(platforms.first['type'], 'youtube');
    });

    test('normalizePlatformsForFirestore avoids serverTimestamp in arrays', () {
      final List<Map<String, dynamic>> normalized =
          UserProfileFirestore.normalizePlatformsForFirestore(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'twitch',
            'username': 'creator',
            'url': 'https://twitch.tv/creator',
          },
        ],
      );
      expect(normalized.length, 1);
      expect(normalized.first['updatedAt'], isA<Timestamp>());
      expect(normalized.first['createdAt'], isA<Timestamp>());
    });

    test('platformStubsFromSelection normalizes facebook_gaming', () {
      final List<Map<String, dynamic>> stubs =
          UserProfileFirestore.platformStubsFromSelection(
        <String>['facebook_gaming'],
      );
      expect(stubs.length, 1);
      expect(stubs.first['type'], 'facebook');
    });

    test('mergeDisplayUserData keeps platforms from fresh doc', () {
      final Map<String, dynamic> merged =
          UserProfileFirestore.mergeDisplayUserData(
        fresh: <String, dynamic>{
          'displayName': 'Live',
          'platforms': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': '1',
              'type': 'twitch',
              'username': 'live',
              'url': 'https://twitch.tv/live',
            },
          ],
        },
        seed: <String, dynamic>{
          'displayName': 'Seed',
          'platforms': <Map<String, dynamic>>[],
        },
      );
      expect(merged['displayName'], 'Live');
      expect(
        UserProfileFirestore.parsePlatformsFromUserData(merged).length,
        1,
      );
    });

    test('platformsForPublicMirror keeps linked rows for peer profiles', () {
      final List<Map<String, dynamic>> mirrored =
          UserProfileFirestore.platformsForPublicMirror(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'p1',
            'type': 'twitch',
            'username': 'creator',
            'url': 'https://twitch.tv/creator',
            'followers': 12,
          },
        ],
      );
      expect(mirrored.length, 1);
      expect(mirrored.first['type'], 'twitch');
      expect(mirrored.first['platformType'], 'twitch');
      expect(mirrored.first['displayName'], 'Twitch');
      expect(mirrored.first['username'], 'creator');
    });
  });
}
