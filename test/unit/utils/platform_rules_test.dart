import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/utils/platform_rules.dart';

void main() {
  group('PlatformRules', () {
    test('rejects more than one Other platform', () {
      final List<Map<String, dynamic>> platforms = <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'other',
          'url': 'https://example.com',
          'username': '',
        },
        <String, dynamic>{
          'type': 'other',
          'url': 'https://example.org',
          'username': '',
        },
      ];
      expect(
        PlatformRules.validatePlatformsList(platforms),
        'You can only add one custom Other platform.',
      );
    });

    test('rejects Patreon URL saved as Other', () {
      final List<Map<String, dynamic>> platforms = <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'other',
          'url': 'https://patreon.com/creator',
          'username': '',
        },
      ];
      expect(
        PlatformRules.validatePlatformsList(platforms),
        contains('Patreon'),
      );
    });

    test('normalizes twitter to x and detects Patreon type from URL', () {
      expect(PlatformRules.normalizePlatformType('twitter'), 'x');
      final List<Map<String, dynamic>> normalized =
          PlatformRules.normalizePlatformsForSave(<Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'patreon',
          'url': 'patreon.com/foo',
          'username': 'foo',
        },
      ]);
      expect(normalized.first['type'], 'patreon');
      expect(normalized.first['url'], 'https://patreon.com/foo');
    });

    test('bare handle does not become https://handle', () {
      final List<Map<String, dynamic>> normalized =
          PlatformRules.normalizePlatformsForSave(<Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'twitch',
          'url': 'technqs',
          'username': '',
        },
      ]);
      expect(normalized.first['username'], 'technqs');
      expect(normalized.first['url'], 'https://www.twitch.tv/technqs');
    });

    test('accepts www Patreon and OnlyFans URLs without protocol', () {
      expect(PlatformRules.hostMatchesUrl('www.patreon.com/smove', 'patreon.com'),
          isTrue);
      expect(
        PlatformRules.hostMatchesUrl(
          'www.onlyfans.com/rybabytv',
          'onlyfans.com',
        ),
        isTrue,
      );
      expect(
        PlatformRules.validatePlatformEntry(
          type: 'patreon',
          url: 'www.patreon.com/smove',
          username: 'smove',
        ),
        isNull,
      );
    });

    test('synthesizes URL from username when url is empty', () {
      final List<Map<String, dynamic>> normalized =
          PlatformRules.normalizePlatformsForSave(<Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'twitch',
          'url': '',
          'username': 'technqs',
        },
      ]);
      expect(normalized.first['url'], 'https://www.twitch.tv/technqs');
      expect(normalized.first['type'], 'twitch');
    });

    test('maps website type to other', () {
      expect(PlatformRules.normalizePlatformType('website'), 'other');
    });

    test('mergePlatformsForSave keeps non-editable rows', () {
      final List<Map<String, dynamic>> merged =
          PlatformRules.mergePlatformsForSave(
        existingPlatforms: <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'linkedin',
            'username': 'creator',
            'url': 'https://linkedin.com/in/creator',
          },
          <String, dynamic>{
            'type': 'twitch',
            'username': 'old',
            'url': 'https://twitch.tv/old',
          },
        ],
        editorDraft: <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'twitch',
            'username': 'new',
            'url': 'https://www.twitch.tv/new',
          },
        ],
      );
      expect(merged.length, 2);
      expect(
        merged.any((Map<String, dynamic> p) => p['type'] == 'linkedin'),
        isTrue,
      );
      expect(
        merged.firstWhere(
          (Map<String, dynamic> p) => p['type'] == 'twitch',
        )['username'],
        'new',
      );
    });

    test('flags Patreon and OnlyFans as age restricted', () {
      expect(PlatformRules.isAgeRestrictedType('patreon'), isTrue);
      expect(
        PlatformRules.isAgeRestrictedEntry(<String, dynamic>{
          'type': 'onlyfans',
          'url': 'https://onlyfans.com/u',
        }),
        isTrue,
      );
    });
  });
}
