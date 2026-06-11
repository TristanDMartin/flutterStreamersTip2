import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/support_shell_style.dart';
import '../../../models/profile_video.dart';
import '../../../utils/insights_metrics.dart';

class CreatorInsightsHero extends StatelessWidget {
  const CreatorInsightsHero({
    super.key,
    required this.video,
    required this.isLive,
    this.lastUpdated,
    required this.views,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.bookmarks,
    this.onPlayTap,
  });

  final ProfileVideo video;
  final bool isLive;
  final DateTime? lastUpdated;
  final int views;
  final int likes;
  final int comments;
  final int shares;
  final int bookmarks;
  final VoidCallback? onPlayTap;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final String caption =
        video.caption.isNotEmpty ? video.caption : 'Untitled video';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: shell.surfaceCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _LiveBadge(isLive: isLive, lastUpdated: lastUpdated),
              const Spacer(),
              if (video.categoryId.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: shell.chipUnselectedBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: shell.chipUnselectedBorder),
                  ),
                  child: Text(
                    video.categoryId,
                    style: TextStyle(
                      color: shell.chipUnselectedFg,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              GestureDetector(
                onTap: onPlayTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 92,
                    height: 128,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        if (video.thumbnailURL != null &&
                            video.thumbnailURL!.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: video.thumbnailURL!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _ThumbnailFallback(shell: shell),
                          )
                        else
                          _ThumbnailFallback(shell: shell),
                        if (onPlayTap != null)
                          Container(
                            color: Colors.black.withValues(alpha: 0.28),
                            child: const Center(
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: shell.onChrome,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _postedLabel(video.createdAt),
                      style: TextStyle(
                        color: shell.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (video.duration > 0) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        'Duration ${InsightsMetrics.formatDurationSeconds(video.duration)}',
                        style: TextStyle(
                          color: shell.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              _QuickStat(
                shell: shell,
                label: 'Views',
                value: InsightsMetrics.formatCount(views),
              ),
              _QuickStat(
                shell: shell,
                label: 'Likes',
                value: InsightsMetrics.formatCount(likes),
              ),
              _QuickStat(
                shell: shell,
                label: 'Comments',
                value: InsightsMetrics.formatCount(comments),
              ),
              _QuickStat(
                shell: shell,
                label: 'Shares',
                value: InsightsMetrics.formatCount(shares),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _QuickStat(
                shell: shell,
                label: 'Saves',
                value: InsightsMetrics.formatCount(bookmarks),
              ),
              Expanded(
                child: Text(
                  'Engagement ${InsightsMetrics.formatPercent(InsightsMetrics.engagementRatePercent(views: views, likes: likes, comments: comments, shares: shares, bookmarks: bookmarks))}',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: shell.mutedStrong,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _postedLabel(DateTime createdAt) {
    final Duration ago = DateTime.now().difference(createdAt);
    if (ago.inDays >= 1) {
      return 'Posted ${ago.inDays}d ago';
    }
    if (ago.inHours >= 1) {
      return 'Posted ${ago.inHours}h ago';
    }
    return 'Posted recently';
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({
    required this.isLive,
    this.lastUpdated,
  });

  final bool isLive;
  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) {
    final Color color = isLive ? const Color(0xFF34D399) : const Color(0xFFFBBF24);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isLive ? 'Live' : 'Syncing',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (lastUpdated != null) ...<Widget>[
          const SizedBox(width: 8),
          Text(
            'Updated ${_formatTime(lastUpdated!)}',
            style: TextStyle(
              color: StSupportShellStyle.of(context).muted,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime value) {
    final TimeOfDay time = TimeOfDay.fromDateTime(value.toLocal());
    final String hour = time.hourOfPeriod == 0 ? '12' : '${time.hourOfPeriod}';
    final String minute = time.minute.toString().padLeft(2, '0');
    final String period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({
    required this.shell,
    required this.label,
    required this.value,
  });

  final StSupportShellStyle shell;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: shell.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: shell.onChrome,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbnailFallback extends StatelessWidget {
  const _ThumbnailFallback({required this.shell});

  final StSupportShellStyle shell;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: shell.skeletonFill,
      child: Icon(Icons.videocam_outlined, color: shell.iconDim, size: 32),
    );
  }
}
