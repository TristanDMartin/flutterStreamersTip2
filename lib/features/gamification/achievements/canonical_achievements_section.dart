import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/support_shell_style.dart';
import '../../../widgets/streamer_card_sections.dart';
import '../gamification_providers.dart';
import 'achievement_catalog.dart';
import 'achievement_definition.dart';
import 'achievement_hex_badge.dart';

class CanonicalAchievementsSection extends ConsumerWidget {
  const CanonicalAchievementsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AchievementSnapshot snapshot =
        ref.watch(achievementSnapshotProvider).valueOrNull ??
            AchievementSnapshot.empty;
    final Map<AchievementFamily, List<AchievementDefinition>> grouped =
        <AchievementFamily, List<AchievementDefinition>>{};
    for (final AchievementDefinition def
        in AchievementCatalog.launchDefinitions) {
      grouped
          .putIfAbsent(def.family, () => <AchievementDefinition>[])
          .add(def);
    }
    return Column(
      children: grouped.entries
          .map(
            (MapEntry<AchievementFamily, List<AchievementDefinition>> entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _FamilyGroup(
                  familyLabel: entry.value.first.familyLabel,
                  definitions: entry.value,
                  snapshot: snapshot,
                ),
              );
            },
          )
          .toList(),
    );
  }
}

class _FamilyGroup extends StatelessWidget {
  const _FamilyGroup({
    required this.familyLabel,
    required this.definitions,
    required this.snapshot,
  });

  final String familyLabel;
  final List<AchievementDefinition> definitions;
  final AchievementSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          familyLabel,
          style: TextStyle(
            color: shell.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        ...definitions.map((AchievementDefinition def) {
          final AchievementUnlock? unlock = snapshot.unlocked[def.key];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CanonicalAchievementCard(
              definition: def,
              unlock: unlock,
            ),
          );
        }),
      ],
    );
  }
}

class _CanonicalAchievementCard extends StatelessWidget {
  const _CanonicalAchievementCard({
    required this.definition,
    required this.unlock,
  });

  final AchievementDefinition definition;
  final AchievementUnlock? unlock;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final bool isLight = shell.isLight;
    final bool unlocked = unlock != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isLight ? shell.surfaceCard : StreamerCardBackStyle.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: unlocked
                  ? AchievementHexBadge.glowFor(definition.rarity)
                      .withValues(alpha: 0.28)
                  : (isLight
                      ? shell.surfaceCardBorder
                      : Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: Row(
            children: <Widget>[
              AchievementHexBadge(
                definition: definition,
                unlocked: unlocked,
                size: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      definition.title,
                      style: TextStyle(
                        color: isLight
                            ? shell.onChrome
                            : StreamerCardBackStyle.softText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      definition.description,
                      style: TextStyle(
                        color: isLight
                            ? shell.muted
                            : StreamerCardBackStyle.muted,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                unlocked ? 'Earned' : definition.rarity.name,
                style: TextStyle(
                  color: unlocked
                      ? AchievementHexBadge.glowFor(definition.rarity)
                      : shell.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final bool unlocked = unlock != null;
    final String earned = unlock?.unlockedAt != null
        ? DateFormat.yMMMd().format(unlock!.unlockedAt!.toLocal())
        : 'Locked';
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              color: shell.isLight
                  ? shell.panelSurface
                  : StreamerCardBackStyle.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: shell.isLight
                    ? shell.panelBorder
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AchievementHexBadge(
                  definition: definition,
                  unlocked: unlocked,
                  size: 88,
                ),
                const SizedBox(height: 12),
                Text(
                  definition.title,
                  style: TextStyle(
                    color: shell.onChrome,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  definition.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: shell.muted, height: 1.35),
                ),
                const SizedBox(height: 12),
                Text(
                  '${definition.familyLabel} · ${definition.rarity.name}'
                  '${definition.xpReward > 0 ? ' · +${definition.xpReward} XP' : ''}',
                  style: TextStyle(color: shell.muted, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  unlocked ? 'Earned $earned' : 'Not earned yet',
                  style: TextStyle(color: shell.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
