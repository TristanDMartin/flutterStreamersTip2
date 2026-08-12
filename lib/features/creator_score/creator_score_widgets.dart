import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/public_profile_firestore.dart';
import '../../utils/avatar_url_resolver.dart';
import '../../widgets/optimized_avatar_image.dart';
import '../../widgets/profile/profile_username_utils.dart';
import 'creator_score.dart';
import 'creator_score_service.dart';

const Color _scoreCardTop = Color(0xFF2A1F4D);
const Color _scoreCardBottom = Color(0xFF161320);
const Color _scoreAccent = Color(0xFF8B5CF6);
const Color _scoreMuted = Color(0xFFA99FC4);
const Color _scoreLavender = Color(0xFFC4B5FD);
const Color _improveCard = Color(0xFF14141C);
const Color _sheetBackground = Color(0xFF0A0A0F);
const Color _avatarRingBlue = Color(0xFF4F7CFF);
const Color _avatarRingPurple = Color(0xFFC060E0);
const Set<String> _roleHashtagKeys = <String>{
  'owner',
  'founder',
  'admin',
  'moderator',
  'staff',
  'official',
};

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
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (BuildContext context, ScrollController controller) {
        return Container(
          decoration: BoxDecoration(
            color: _sheetBackground,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomInset),
            children: <Widget>[
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _CreatorScoreProfileHeader(userId: userId),
              const SizedBox(height: 16),
              CreatorScoreSummaryPanel(
                score: score,
                isLoading: scoreAsync.isLoading,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Purple score card + improve list used by the sheet and streamer card back.
class CreatorScoreSummaryPanel extends StatelessWidget {
  const CreatorScoreSummaryPanel({
    super.key,
    required this.score,
    this.isLoading = false,
    this.showImprove = true,
  });

  final CreatorScore score;
  final bool isLoading;
  final bool showImprove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ScoreHeroCard(score: score, isLoading: isLoading),
        if (showImprove) ...<Widget>[
          const SizedBox(height: 24),
          const Text(
            'How to improve',
            style: TextStyle(
              color: Color(0xFFE0E0E5),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _ImproveCard(recommendations: score.recommendations),
        ],
      ],
    );
  }
}

/// Watches [creatorScoreProvider] and renders [CreatorScoreSummaryPanel].
class CreatorScoreInlinePanel extends ConsumerWidget {
  const CreatorScoreInlinePanel({
    super.key,
    required this.userId,
    this.showImprove = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final String userId;
  final bool showImprove;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CreatorScore> scoreAsync =
        ref.watch(creatorScoreProvider(userId));
    final CreatorScore score = scoreAsync.value ?? CreatorScore.fallback;
    if (!score.isAvailable) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: padding,
      child: CreatorScoreSummaryPanel(
        score: score,
        isLoading: scoreAsync.isLoading,
        showImprove: showImprove,
      ),
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

class _CreatorScoreProfileHeader extends StatelessWidget {
  const _CreatorScoreProfileHeader({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: PublicProfileFirestore.instance.watchProfile(userId),
      builder: (
        BuildContext context,
        AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
      ) {
        final Map<String, dynamic> data =
            snapshot.data?.data() ?? <String, dynamic>{};
        final String displayName =
            ProfileUsernameUtils.resolveDisplayName(data);
        final String username = ProfileUsernameUtils.resolveUsername(data);
        final String? avatarUrl = resolveAvatarUrl(data);
        final List<String> rolePills = _readRolePills(data);
        final String nameLabel =
            displayName.isNotEmpty ? displayName : 'Creator';
        final String handleLabel =
            username.isNotEmpty ? '@$username' : '';

        return Row(
          children: <Widget>[
            _GradientAvatarRing(avatarUrl: avatarUrl, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    nameLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (handleLabel.isNotEmpty)
                    Text(
                      handleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8A8A95),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
            if (rolePills.isNotEmpty) ...<Widget>[
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: rolePills
                    .map((String pill) => _RolePill(label: pill))
                    .toList(growable: false),
              ),
            ],
          ],
        );
      },
    );
  }

  static List<String> _readRolePills(Map<String, dynamic> data) {
    final Object? raw = data['hashtags'];
    final List<String> tags = <String>[];
    if (raw is List) {
      for (final Object? item in raw) {
        final String tag = item?.toString().trim() ?? '';
        if (tag.isNotEmpty) {
          tags.add(tag);
        }
      }
    } else if (raw is String && raw.trim().isNotEmpty) {
      tags.addAll(
        raw
            .split(RegExp(r'[,\s]+'))
            .map((String tag) => tag.trim())
            .where((String tag) => tag.isNotEmpty),
      );
    }
    final List<String> pills = <String>[];
    for (final String tag in tags) {
      final String cleaned =
          tag.replaceAll('#', '').trim().toLowerCase();
      if (!_roleHashtagKeys.contains(cleaned)) {
        continue;
      }
      final String label = cleaned[0].toUpperCase() + cleaned.substring(1);
      if (!pills.contains(label)) {
        pills.add(label);
      }
    }
    return pills;
  }
}

class _GradientAvatarRing extends StatelessWidget {
  const _GradientAvatarRing({
    required this.avatarUrl,
    required this.size,
  });

  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[_avatarRingBlue, _avatarRingPurple],
        ),
      ),
      child: ClipOval(
        child: OptimizedAvatarImage(
          imageUrl: avatarUrl,
          size: size - 4,
          backgroundColor: const Color(0xFF2A2A35),
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final bool isPrimary = label.toLowerCase() == 'owner';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPrimary
            ? const Color(0xFF8B5CF6).withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isPrimary ? _scoreLavender : const Color(0xFFC0C0C8),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ScoreHeroCard extends StatelessWidget {
  const _ScoreHeroCard({
    required this.score,
    required this.isLoading,
  });

  final CreatorScore score;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final String rankLine = isLoading
        ? 'Loading live score'
        : '${score.rankLabel} · level ${score.level}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_scoreCardTop, _scoreCardBottom],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _scoreAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                '${score.score}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '/ 100',
                style: TextStyle(
                  color: _scoreMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            rankLine,
            style: const TextStyle(
              color: _scoreLavender,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCell(
                  label: 'Consistency',
                  value: score.consistencyScore,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCell(
                  label: 'Content',
                  value: score.contentScore,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCell(
                  label: 'Networking',
                  value: score.networkingScore,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCell(
                  label: 'Engagement',
                  value: score.engagementScore,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final double progress = value.clamp(0, 100) / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                color: _scoreMuted,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              '$value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            color: _scoreAccent,
          ),
        ),
      ],
    );
  }
}

class _ImproveCard extends StatelessWidget {
  const _ImproveCard({required this.recommendations});

  final List<String> recommendations;

  @override
  Widget build(BuildContext context) {
    final List<String> items = recommendations.isEmpty
        ? CreatorScore.fallback.recommendations
        : recommendations;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _improveCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < items.length; i++) ...<Widget>[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            _ImproveRow(text: items[i]),
          ],
        ],
      ),
    );
  }
}

class _ImproveRow extends StatelessWidget {
  const _ImproveRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: <Widget>[
          Icon(
            _iconForRecommendation(text),
            color: _scoreLavender,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFE0E0E5),
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconForRecommendation(String text) {
    final String lower = text.toLowerCase();
    if (lower.contains('clip') ||
        lower.contains('post') ||
        lower.contains('video') ||
        lower.contains('upload')) {
      return Icons.videocam_outlined;
    }
    if (lower.contains('collaborat') ||
        lower.contains('creator') ||
        lower.contains('network')) {
      return Icons.people_outline;
    }
    if (lower.contains('platform') ||
        lower.contains('connect') ||
        lower.contains('link')) {
      return Icons.power_outlined;
    }
    if (lower.contains('academy') ||
        lower.contains('lesson') ||
        lower.contains('learn')) {
      return Icons.menu_book_outlined;
    }
    if (lower.contains('card') || lower.contains('profile')) {
      return Icons.badge_outlined;
    }
    return Icons.auto_awesome;
  }
}
