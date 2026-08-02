import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });
}
