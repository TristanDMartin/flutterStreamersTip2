import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_stats.dart';
import '../providers/user_stats_provider.dart';

class UserStatsRow extends ConsumerStatefulWidget {
  const UserStatsRow({
    super.key,
    required this.userId,
    this.showConnections = false,
    this.spacing = 54,
    this.valueTextStyle,
    this.labelTextStyle,
  });

  final String userId;
  final bool showConnections;
  final double spacing;
  final TextStyle? valueTextStyle;
  final TextStyle? labelTextStyle;

  @override
  ConsumerState<UserStatsRow> createState() => _UserStatsRowState();
}

class _UserStatsRowState extends ConsumerState<UserStatsRow> {
  UserStats? _lastStableStats;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<UserStats> statsAsync =
        ref.watch(watchUserStatsProvider(widget.userId));

    statsAsync.whenData((UserStats stats) {
      _lastStableStats = stats;
    });

    final UserStats? fallbackStats = _lastStableStats;

    return statsAsync.when(
      data: (UserStats stats) => _StatsRowContent(
        postsCount: stats.postsCount,
        followersCount: stats.followersCount,
        followingCount: stats.followingCount,
        connectionsCount: stats.connectionsCount,
        showConnections: widget.showConnections,
        spacing: widget.spacing,
        valueTextStyle: widget.valueTextStyle,
        labelTextStyle: widget.labelTextStyle,
      ),
      loading: () => fallbackStats != null
          ? _StatsRowContent(
              postsCount: fallbackStats.postsCount,
              followersCount: fallbackStats.followersCount,
              followingCount: fallbackStats.followingCount,
              connectionsCount: fallbackStats.connectionsCount,
              showConnections: widget.showConnections,
              spacing: widget.spacing,
              valueTextStyle: widget.valueTextStyle,
              labelTextStyle: widget.labelTextStyle,
            )
          : _StatsRowContent.loading(
              showConnections: widget.showConnections,
              spacing: widget.spacing,
              valueTextStyle: widget.valueTextStyle,
              labelTextStyle: widget.labelTextStyle,
            ),
      error: (Object err, StackTrace stackTrace) => fallbackStats != null
          ? _StatsRowContent(
              postsCount: fallbackStats.postsCount,
              followersCount: fallbackStats.followersCount,
              followingCount: fallbackStats.followingCount,
              connectionsCount: fallbackStats.connectionsCount,
              showConnections: widget.showConnections,
              spacing: widget.spacing,
              valueTextStyle: widget.valueTextStyle,
              labelTextStyle: widget.labelTextStyle,
            )
          : const SizedBox.shrink(),
    );
  }
}

class _StatsRowContent extends StatelessWidget {
  const _StatsRowContent({
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.connectionsCount,
    required this.showConnections,
    required this.spacing,
    required this.valueTextStyle,
    required this.labelTextStyle,
  });

  const _StatsRowContent.loading({
    required this.showConnections,
    required this.spacing,
    required this.valueTextStyle,
    required this.labelTextStyle,
  })  : postsCount = null,
        followersCount = null,
        followingCount = null,
        connectionsCount = null;

  final int? postsCount;
  final int? followersCount;
  final int? followingCount;
  final int? connectionsCount;
  final bool showConnections;
  final double spacing;
  final TextStyle? valueTextStyle;
  final TextStyle? labelTextStyle;

  @override
  Widget build(BuildContext context) {
    final TextStyle resolvedValueTextStyle = valueTextStyle ??
        const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w900,
          height: 1.0,
        );
    final TextStyle resolvedLabelTextStyle = labelTextStyle ??
        TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.0,
        );
    final String postsValue = postsCount?.toString() ?? '...';
    final String followersValue = followersCount?.toString() ?? '...';
    final String followingValue = followingCount?.toString() ?? '...';
    final String connectionsValue = connectionsCount?.toString() ?? '...';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _StatItem(
          label: 'Posts',
          value: postsValue,
          valueTextStyle: resolvedValueTextStyle,
          labelTextStyle: resolvedLabelTextStyle,
        ),
        SizedBox(width: spacing),
        _StatItem(
          label: 'Followers',
          value: followersValue,
          valueTextStyle: resolvedValueTextStyle,
          labelTextStyle: resolvedLabelTextStyle,
        ),
        SizedBox(width: spacing),
        _StatItem(
          label: 'Following',
          value: followingValue,
          valueTextStyle: resolvedValueTextStyle,
          labelTextStyle: resolvedLabelTextStyle,
        ),
        if (showConnections) ...<Widget>[
          SizedBox(width: spacing),
          _StatItem(
            label: 'Connections',
            value: connectionsValue,
            valueTextStyle: resolvedValueTextStyle,
            labelTextStyle: resolvedLabelTextStyle,
          ),
        ],
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.valueTextStyle,
    required this.labelTextStyle,
  });

  final String label;
  final String value;
  final TextStyle valueTextStyle;
  final TextStyle labelTextStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(value, style: valueTextStyle),
        const SizedBox(height: 4),
        Text(label, style: labelTextStyle),
      ],
    );
  }
}
