import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/creator_intelligence_analytics_service.dart';
import '../../../../core/theme/st_theme_tokens.dart';
import '../../../../models/trending_creator.dart';
import '../../../../providers/discover_provider.dart';
import 'creator_avatar_ring.dart';
import 'follower_count_text.dart';

class TrendingCreatorCard extends ConsumerStatefulWidget {
  const TrendingCreatorCard({
    super.key,
    required this.creator,
    required this.isDark,
    required this.onOpenProfile,
  });

  final TrendingCreator creator;
  final bool isDark;
  final VoidCallback onOpenProfile;

  @override
  ConsumerState<TrendingCreatorCard> createState() =>
      _TrendingCreatorCardState();
}

class _TrendingCreatorCardState extends ConsumerState<TrendingCreatorCard> {
  @override
  Widget build(BuildContext context) {
    final List<TrendingCreator> list =
        ref.watch(discoverProvider).trendingCreators;
    TrendingCreator c = widget.creator;
    for (final TrendingCreator x in list) {
      if (x.id == widget.creator.id) {
        c = x;
        break;
      }
    }
    final Color cardBg = widget.isDark
        ? const Color(0xFF0F172A).withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.94);
    final Color border = widget.isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFF0F172A).withValues(alpha: 0.08);
    final Color onCard = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final Color muted = onCard.withValues(alpha: 0.72);
    final String handle = c.username.isNotEmpty
        ? (c.username.startsWith('@') ? c.username : '@${c.username}')
        : '@creator';
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.20 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  unawaited(
                    CreatorIntelligenceAnalyticsService()
                        .trackCreatorCardOpened(creatorId: widget.creator.id),
                  );
                  widget.onOpenProfile();
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[
                      CreatorAvatarRing(
                        avatarUrl: c.avatarURL,
                        username: c.username,
                        isLive: c.isActive,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        handle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: onCard,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c.trendingStatusLine,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FollowerCountText(
                        count: math.max(0, c.followerCount),
                        color: StThemeColors.brandBlue,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
