import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../constants/app_colors.dart';
import '../../../core/theme/st_theme_tokens.dart';
import '../../../widgets/enhanced_like_button.dart';
import 'video_player_action_rail_metrics.dart';
import 'video_player_count_format.dart';

class VideoPlayerActionRail extends StatelessWidget {
  const VideoPlayerActionRail({
    super.key,
    required this.tabId,
    required this.videoId,
    required this.initialLikeCount,
    required this.initialIsLiked,
    required this.onLikeChanged,
    required this.likeButtonKey,
    required this.commentCount,
    required this.onComment,
    required this.isBookmarked,
    required this.favoriteCount,
    required this.isBookmarkPending,
    required this.onBookmark,
    required this.shareCount,
    required this.onShare,
    required this.trailing,
  });

  final String tabId;
  final String videoId;
  final int initialLikeCount;
  final bool initialIsLiked;
  final VoidCallback onLikeChanged;
  final GlobalKey likeButtonKey;
  final int commentCount;
  final VoidCallback onComment;
  final bool isBookmarked;
  final int favoriteCount;
  final bool isBookmarkPending;
  final VoidCallback onBookmark;
  final int shareCount;
  final VoidCallback onShare;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final VideoPlayerActionRailMetrics railMetrics =
        VideoPlayerActionRailMetrics.of(context);
    final double rightInset = railMetrics.rightInset;
    final double safeBottom = media.viewPadding.bottom;
    final bool isCategoryFeed = tabId.startsWith('discoverView_');
    final bool isProfileView =
        tabId.startsWith('profile_') || tabId == 'playerScreen';
    final double bottom;
    if (isCategoryFeed) {
      bottom = safeBottom + 20.0;
    } else if (isProfileView) {
      bottom = safeBottom + 20.0;
    } else {
      final double dockBase =
          railMetrics.bottomNavHeight + railMetrics.bottomNavMargin;
      final double platformHomeLift =
          defaultTargetPlatform == TargetPlatform.iOS ? -40.0 : 0.0;
      bottom = safeBottom +
          dockBase +
          railMetrics.railPaddingAboveNav +
          66.0 +
          platformHomeLift;
    }

    return Positioned(
      bottom: bottom,
      right: rightInset,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            EnhancedLikeButton(
              videoId: videoId,
              initialLikeCount: initialLikeCount,
              initialIsLiked: initialIsLiked,
              onLikeChanged: onLikeChanged,
              iconKey: likeButtonKey,
              source: 'button',
              width: railMetrics.likeWidth,
              height: railMetrics.likeHeight,
              iconSize: railMetrics.likeIconSize,
              labelFontSize: railMetrics.likeLabelFontSize,
              labelGap: railMetrics.labelGap,
              sparkleSize: railMetrics.sparkleSize,
            ),
            SizedBox(height: railMetrics.itemGap),
            VideoPlayerActionRailButton(
              icon: Icons.chat_bubble_outline,
              count: formatCompactVideoCount(commentCount),
              onTap: onComment,
              metrics: railMetrics,
            ),
            SizedBox(height: railMetrics.itemGap),
            VideoPlayerActionRailButton(
              icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              count: formatCompactVideoCount(favoriteCount),
              onTap: isBookmarkPending ? null : onBookmark,
              isActive: isBookmarked,
              metrics: railMetrics,
            ),
            SizedBox(height: railMetrics.itemGap),
            VideoPlayerActionRailButton(
              icon: Icons.share,
              count: shareCount > 0
                  ? formatCompactVideoCount(shareCount)
                  : 'Share',
              onTap: onShare,
              metrics: railMetrics,
            ),
            SizedBox(height: railMetrics.avatarGap),
            trailing,
          ],
        ),
      ),
    );
  }
}

class VideoPlayerActionRailButton extends StatelessWidget {
  const VideoPlayerActionRailButton({
    super.key,
    required this.icon,
    required this.count,
    required this.onTap,
    required this.metrics,
    this.isActive = false,
    this.isLoading = false,
  });

  final IconData icon;
  final String count;
  final VoidCallback? onTap;
  final VideoPlayerActionRailMetrics metrics;
  final bool isActive;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final double btnSize = metrics.buttonSize;
    final bool isShareAction = count == 'Share';
    final Color labelColor = isActive
        ? AppColors.textPrimary.withValues(alpha: 0.98)
        : Colors.white.withValues(alpha: 0.92);

    return SizedBox(
      width: btnSize,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: btnSize,
            height: btnSize,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap != null
                    ? () {
                        HapticFeedback.lightImpact();
                        onTap!();
                      }
                    : null,
                borderRadius: BorderRadius.circular(btnSize / 2),
                child: Center(
                  child: Container(
                    width: btnSize - 4,
                    height: btnSize - 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.28),
                      border: Border.all(
                        color: isActive
                            ? StThemeColors.brandPurple.withValues(alpha: 0.55)
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: isLoading
                          ? SizedBox(
                              width: metrics.progressSize,
                              height: metrics.progressSize,
                              child: CircularProgressIndicator(
                                strokeWidth: metrics.progressStrokeWidth,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isActive
                                      ? AppColors.primary
                                      : Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            )
                          : Icon(
                              icon,
                              color: isActive
                                  ? StThemeColors.brandPurple
                                  : Colors.white.withValues(alpha: 0.96),
                              size: isShareAction
                                  ? metrics.shareIconSize
                                  : metrics.iconSize,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: metrics.labelGap),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.16),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              count,
              key: ValueKey<String>(
                '${icon.codePoint}-$count-$isActive-$isLoading',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: labelColor,
                fontSize: isShareAction
                    ? metrics.shareLabelFontSize
                    : metrics.labelFontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
                shadows: <Shadow>[
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
