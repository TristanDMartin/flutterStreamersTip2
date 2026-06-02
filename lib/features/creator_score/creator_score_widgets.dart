import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'creator_score.dart';
import 'creator_score_service.dart';

class CreatorScoreBadge extends ConsumerWidget {
  const CreatorScoreBadge({
    super.key,
    required this.userId,
    this.compact = false,
    this.onTap,
  });

  final String userId;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CreatorScore> scoreAsync =
        ref.watch(creatorScoreProvider(userId));
    final CreatorScore? score = scoreAsync.valueOrNull;
    if (score == null || !score.isAvailable) {
      return const SizedBox.shrink();
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final double size = compact ? 48 : 58;
    final Color fill = isLight
        ? scheme.surfaceContainerHighest
        : scheme.surfaceContainerHigh.withValues(alpha: 0.94);
    final Color border = scheme.primary.withValues(alpha: isLight ? 0.34 : 0.5);
    final Color textColor = scheme.onSurface;

    return Semantics(
      label: 'Creator Score ${score.score}',
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          if (onTap != null) {
            onTap!();
            return;
          }
          showCreatorScoreBottomSheet(context, userId: userId);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 1.5),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: scheme.shadow.withValues(alpha: isLight ? 0.12 : 0.28),
                blurRadius: compact ? 10 : 14,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: scheme.primary.withValues(alpha: isLight ? 0.08 : 0.14),
                blurRadius: compact ? 12 : 16,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${score.score}',
              maxLines: 1,
              style: TextStyle(
                color: textColor,
                fontSize: compact ? 19 : 23,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showCreatorScoreBottomSheet(
  BuildContext context, {
  required String userId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return CreatorScoreBottomSheet(userId: userId);
    },
  );
}

class CreatorScoreBottomSheet extends ConsumerWidget {
  const CreatorScoreBottomSheet({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CreatorScore> scoreAsync =
        ref.watch(creatorScoreProvider(userId));
    final CreatorScore score = scoreAsync.value ?? CreatorScore.fallback;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      minChildSize: 0.42,
      maxChildSize: 0.92,
      builder: (BuildContext context, ScrollController controller) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.22)),
          ),
          child: ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(22, 12, 22, 24 + bottomInset),
            children: <Widget>[
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Creator Score',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              _ScoreHero(score: score, isLoading: scoreAsync.isLoading),
              const SizedBox(height: 24),
              _SectionTitle(text: 'Breakdown'),
              const SizedBox(height: 10),
              CreatorScoreBreakdownRow(
                label: 'Consistency',
                value: score.consistencyScore,
              ),
              CreatorScoreBreakdownRow(
                label: 'Content',
                value: score.contentScore,
              ),
              CreatorScoreBreakdownRow(
                label: 'Networking',
                value: score.networkingScore,
              ),
              CreatorScoreBreakdownRow(
                label: 'Engagement',
                value: score.engagementScore,
              ),
              const SizedBox(height: 24),
              _SectionTitle(text: 'How to improve'),
              const SizedBox(height: 8),
              ...score.recommendations.map(
                (String item) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.auto_awesome,
                        color: scheme.primary,
                        size: 17,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.78),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CreatorScoreBreakdownRow extends StatelessWidget {
  const CreatorScoreBreakdownRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.76),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 116,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: value.clamp(0, 100) / 100,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.end,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreHero extends StatelessWidget {
  const _ScoreHero({required this.score, required this.isLoading});

  final CreatorScore score;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            '${score.score}',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 54,
              fontWeight: FontWeight.w900,
              height: 0.95,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '/100',
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.64),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  score.rankLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isLoading ? 'Loading live score' : 'Level ${score.level}',
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.68),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
