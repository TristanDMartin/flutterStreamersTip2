import 'package:flutter/material.dart';

import '../core/theme/support_shell_style.dart';
import '../models/creator_activity.dart';

/// Reusable creator activity line (Network, Profile, Streamer Card, Inbox, Search).
class CreatorActivityBadge extends StatelessWidget {
  const CreatorActivityBadge({
    super.key,
    required this.activity,
    this.compact = false,
    this.showPlatform = true,
    this.showTimestamp = false,
    this.fallbackLabel,
  });

  final CreatorActivity activity;
  final bool compact;
  final bool showPlatform;
  final bool showTimestamp;
  final String? fallbackLabel;

  @override
  Widget build(BuildContext context) {
    if (activity.isNone) {
      final String? fallback = fallbackLabel;
      if (fallback == null || fallback.isEmpty) {
        return const SizedBox.shrink();
      }
      return _BadgeShell(
        compact: compact,
        label: fallback,
        accent: Theme.of(context).colorScheme.outline,
      );
    }

    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color accent = _accentForType(cs, activity.type);
    String label = activity.displayLine;
    if (!showPlatform && activity.platform != null) {
      label = '${activity.emoji} ${activity.label}'.trim();
    }
    if (showTimestamp && activity.updatedAt != null) {
      final Duration ago = DateTime.now().difference(activity.updatedAt!);
      final String suffix =
          ago.inMinutes < 60 ? '${ago.inMinutes}m ago' : '${ago.inHours}h ago';
      label = '$label · $suffix';
    }

    return _BadgeShell(
      compact: compact,
      label: label,
      accent: accent,
    );
  }

  static Color _accentForType(ColorScheme cs, CreatorActivityType type) {
    switch (type) {
      case CreatorActivityType.live:
        return Colors.greenAccent.shade400;
      case CreatorActivityType.postedToday:
      case CreatorActivityType.uploadedClip:
      case CreatorActivityType.trendingPost:
        return cs.primary;
      case CreatorActivityType.lookingForCollabs:
      case CreatorActivityType.openToNetwork:
        return cs.tertiary;
      case CreatorActivityType.editingContent:
      case CreatorActivityType.workingOnClips:
        return cs.secondary;
      case CreatorActivityType.streamingSoon:
        return Colors.orangeAccent;
      case CreatorActivityType.takingBreak:
        return cs.outline;
      case CreatorActivityType.newCreatorCard:
        return cs.primary;
      case CreatorActivityType.none:
        return cs.outline;
    }
  }
}

class _BadgeShell extends StatelessWidget {
  const _BadgeShell({
    required this.compact,
    required this.label,
    required this.accent,
  });

  final bool compact;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final double fontSize = compact ? 10.5 : 12;
    final EdgeInsets padding = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 5);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: shell.isLight ? 0.12 : 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        maxLines: compact ? 1 : 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: accent.withValues(alpha: 0.95),
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1.15,
        ),
      ),
    );
  }
}
