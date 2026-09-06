import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/gamification/achievements/achievement_catalog.dart';
import 'package:streamers_tip/features/gamification/achievements/achievement_definition.dart';

void main() {
  group('AchievementCatalog', () {
    test('matches frozen achievements.v1.json launch keys', () {
      final File file = File('contracts/achievements.v1.json');
      final Map<String, dynamic> contract =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final List<String> launchKeys =
          (contract['launchKeys'] as List<dynamic>).cast<String>();
      expect(AchievementCatalog.launchKeys, launchKeys);
      expect(AchievementCatalog.launchKeys, hasLength(22));
      expect(AchievementCatalog.launchKeys, contains('level_15'));
      expect(AchievementCatalog.launchKeys, isNot(contains('level_25')));
      for (final String key in launchKeys) {
        final Map<String, dynamic> raw =
            (contract['achievements'] as Map<String, dynamic>)[key]
                as Map<String, dynamic>;
        final AchievementDefinition def = AchievementCatalog.byKey[key]!;
        expect(def.title, raw['title']);
        expect(def.description, raw['description']);
        expect(def.rarity.name, raw['rarity']);
        expect(def.xpReward, raw['xpReward']);
        expect(def.iconName, raw['icon']);
      }
    });

    test('aliases legacy ids without inventing product keys', () {
      expect(AchievementCatalog.canonicalizeKey('first_steps'), 'onboarding_done');
      expect(AchievementCatalog.canonicalizeKey('seven_day_streak'), 'streak_7');
      expect(AchievementCatalog.canonicalizeKey('first_video'), 'first_video');
      expect(AchievementCatalog.byKey['showcase_first_video'], isNull);
    });

    test('queues pending keys and acknowledges one at a time', () {
      final List<String> pending = AchievementCatalog.canonicalizePending(
        <String>['first_video', 'posts_10', 'level_5', 'first_video'],
      );
      expect(pending, <String>['first_video', 'posts_10', 'level_5']);
      pending.remove('first_video');
      expect(pending, <String>['posts_10', 'level_5']);
      pending.remove('posts_10');
      expect(pending, <String>['level_5']);
    });
  });
}
