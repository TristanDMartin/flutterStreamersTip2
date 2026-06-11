import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/gamification/models/subscription_plan.dart';
import '../models/creator_command_snapshot.dart';
import '../providers/creator_command_provider.dart';
import '../qa/qa_keys.dart';
import '../routing/app_navigator.dart';
import '../routing/app_routes.dart';

Future<void> _executeTippyFromCommandCenter(
  BuildContext context, {
  required bool tippyEnabled,
}) async {
  HapticFeedback.mediumImpact();
  if (!tippyEnabled) {
    Navigator.of(context).pushNamed(AppRoutes.upgrade);
    return;
  }
  await AppNavigator.openTippyChat(context);
}

String _primaryRecommendation(CreatorCommandSnapshot s) {
  if (!s.tippyAiEnabled) {
    return 'Unlock Tippy to generate plans, hooks, and captions from this workspace.';
  }
  if (s.nextPostOverdue) {
    return 'Ask Tippy to rebuild today and move the overdue item back into motion.';
  }
  if (s.scheduledQueueCount == 0) {
    return 'Create a 7 or 14 day plan so the web planner and app schedule stay aligned.';
  }
  if (s.draftCount > 0) {
    return 'Turn one draft into a scheduled post before adding more ideas.';
  }
  return 'Use Tippy for the next caption, then review the schedule queue.';
}

String _momentumLabel(CreatorCommandSnapshot s) {
  if (s.nextPostOverdue || s.alertCount > 0) return 'Needs attention';
  final double? growth = s.growthPercent;
  if (growth != null && growth >= 10) return 'Rising';
  if (s.consistencyScorePercent >= 75) return 'Steady';
  if (s.scheduledQueueCount > 0) return 'Prepared';
  return 'Build rhythm';
}

String _briefLine(CreatorCommandSnapshot s, BuildContext context) {
  if (s.nextPostOverdue) {
    return 'Recover the overdue post before creating more.';
  }
  if (s.alertCount > 0) {
    return '${s.alertCount} item${s.alertCount == 1 ? '' : 's'} need review.';
  }
  if (s.nextPostDueAt != null) {
    final TimeOfDay time = TimeOfDay.fromDateTime(s.nextPostDueAt!.toLocal());
    return 'Next post is queued for ${MaterialLocalizations.of(context).formatTimeOfDay(time)}.';
  }
  if (s.draftCount > 0) return 'Turn one draft into a scheduled post today.';
  return 'Create a plan so your next move is ready.';
}

String _primaryActionLabel(CreatorCommandSnapshot s) {
  if (s.nextPostOverdue || s.alertCount > 0) return 'Fix Attention Items';
  if (s.draftCount > 0) return 'Schedule a Draft';
  if (s.scheduledQueueCount == 0) return 'Build Posting Plan';
  return s.tippyAiEnabled ? 'Ask Tippy What Is Next' : 'Unlock Tippy';
}

String _primaryActionHint(CreatorCommandSnapshot s) {
  if (s.nextPostOverdue || s.alertCount > 0) {
    return 'Open planner and clear what is blocking momentum.';
  }
  if (s.draftCount > 0) {
    return '${s.draftCount} draft${s.draftCount == 1 ? '' : 's'} ready to move forward.';
  }
  if (s.scheduledQueueCount == 0) {
    return 'Create a 7-day rhythm before the feed goes quiet.';
  }
  return _primaryRecommendation(s);
}

IconData _primaryActionIcon(CreatorCommandSnapshot s) {
  if (s.nextPostOverdue || s.alertCount > 0) {
    return Icons.priority_high_rounded;
  }
  if (s.draftCount > 0) return Icons.edit_calendar_rounded;
  if (s.scheduledQueueCount == 0) return Icons.event_repeat_rounded;
  return s.tippyAiEnabled
      ? Icons.auto_awesome_rounded
      : Icons.lock_open_rounded;
}

void _executePrimaryAction(BuildContext context, CreatorCommandSnapshot s) {
  HapticFeedback.selectionClick();
  if (s.nextPostOverdue || s.alertCount > 0 || s.draftCount > 0) {
    AppNavigator.openManagePostsWithArgs(
      context,
      initialTab: ManagePostsInitialTab.scheduled,
      launchSource: ManagePostsLaunchSource.commandCenter,
    );
    return;
  }
  if (s.scheduledQueueCount == 0) {
    _executeTippyFromCommandCenter(context, tippyEnabled: s.tippyAiEnabled);
    return;
  }
  _executeTippyFromCommandCenter(context, tippyEnabled: s.tippyAiEnabled);
}

class StreamersTipCommandCenterTrigger extends StatelessWidget {
  const StreamersTipCommandCenterTrigger({
    super.key,
    required this.onTap,
    this.size = 40,
    this.showAlertPulse = false,
  });

  final VoidCallback onTap;
  final double size;
  final bool showAlertPulse;

  @override
  Widget build(BuildContext context) {
    final BoxShadow glow = BoxShadow(
      color: const Color(0xFF9248D2)
          .withValues(alpha: showAlertPulse ? 0.38 : 0.24),
      blurRadius: showAlertPulse ? 20 : 14,
      offset: const Offset(0, 6),
    );

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFF9248D2), Color(0xFF4897D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: <BoxShadow>[glow],
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0F172A).withValues(alpha: 0.95),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Image.asset(
              'assets/091225_ST_logo_white.PNG',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class CreatorCommandCenterOverlay extends ConsumerStatefulWidget {
  const CreatorCommandCenterOverlay({
    super.key,
    required this.state,
    required this.onDismiss,
    required this.onExpand,
  });

  final CreatorCommandCenterState state;
  final VoidCallback onDismiss;
  final VoidCallback onExpand;

  @override
  ConsumerState<CreatorCommandCenterOverlay> createState() =>
      _CreatorCommandCenterOverlayState();
}

class _CreatorCommandCenterOverlayState
    extends ConsumerState<CreatorCommandCenterOverlay> {
  @override
  Widget build(BuildContext context) {
    if (widget.state == CreatorCommandCenterState.closed) {
      return const SizedBox.shrink();
    }

    final AsyncValue<CreatorCommandSnapshot?> snapshotAsync =
        ref.watch(creatorCommandSnapshotProvider);
    final double bottomOffset = MediaQuery.paddingOf(context).bottom + 92;
    final bool isExpanded = widget.state == CreatorCommandCenterState.expanded;

    return Positioned.fill(
      key: QaKeys.commandCenterOverlay,
      child: Stack(
        children: <Widget>[
          if (isExpanded)
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onDismiss,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 220),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (BuildContext context, double value, Widget? child) {
                  return BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 2 * value,
                      sigmaY: 2 * value,
                    ),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.08 * value),
                    ),
                  );
                },
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            bottom: bottomOffset,
            right: 10,
            child: snapshotAsync.when(
              data: (CreatorCommandSnapshot? snapshot) {
                if (snapshot == null) {
                  return _GlassShell(
                    key: const ValueKey<String>('signedOut'),
                    width: 272,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Expanded(
                                child: Text(
                                  'Creator Command Center',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                key: QaKeys.commandCenterDismiss,
                                onPressed: widget.onDismiss,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: Colors.white.withValues(alpha: 0.74),
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to load streaks, drafts, '
                            'schedule, and Tippy AI.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.92, end: 1).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: widget.state == CreatorCommandCenterState.collapsed
                      ? _CollapsedSummaryBar(
                          key: const ValueKey<String>('collapsed'),
                          snapshot: snapshot,
                          onTap: widget.onExpand,
                        )
                      : _ExpandedCommandCard(
                          key: const ValueKey<String>('expanded'),
                          snapshot: snapshot,
                          onDismiss: widget.onDismiss,
                        ),
                );
              },
              loading: () {
                return _GlassShell(
                  key: const ValueKey<String>('loading'),
                  width: 220,
                  child: const Padding(
                    padding: EdgeInsets.all(18),
                    child: SizedBox(
                      height: 28,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                );
              },
              error: (Object error, StackTrace stackTrace) {
                return _GlassShell(
                  key: const ValueKey<String>('error'),
                  width: 276,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Expanded(
                              child: Text(
                                'Could not load hub',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              key: QaKeys.commandCenterDismiss,
                              onPressed: widget.onDismiss,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              icon: Icon(
                                Icons.close_rounded,
                                color: Colors.white.withValues(alpha: 0.74),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Check your connection, stay on For You, '
                          'then reopen the hub.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsedSummaryBar extends StatelessWidget {
  const _CollapsedSummaryBar({
    super.key,
    required this.snapshot,
    required this.onTap,
  });

  final CreatorCommandSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: _GlassShell(
        width: 280,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: <Widget>[
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4897D2).withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  snapshot.collapsedSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.expand_less_rounded,
                color: Colors.white.withValues(alpha: 0.5),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandedHeader extends StatelessWidget {
  const _ExpandedHeader({
    required this.snapshot,
    required this.onDismiss,
  });

  final CreatorCommandSnapshot snapshot;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            snapshot.identityLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _PlanBadge(plan: snapshot.subscriptionPlan),
        const SizedBox(width: 6),
        IconButton(
          key: QaKeys.commandCenterDismiss,
          onPressed: onDismiss,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          icon: Icon(
            Icons.close_rounded,
            color: Colors.white.withValues(alpha: 0.65),
            size: 20,
          ),
        ),
      ],
    );
  }
}

class _QuickCommandRow extends StatelessWidget {
  const _QuickCommandRow({required this.snapshot});

  final CreatorCommandSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _CommandButton(
            icon: Icons.calendar_month_rounded,
            label: 'Planner',
            onTap: () {
              HapticFeedback.selectionClick();
              AppNavigator.openContentPlanner(context);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CommandButton(
            icon: Icons.auto_awesome_rounded,
            label: snapshot.tippyAiEnabled ? 'Tippy' : 'Tippy (locked)',
            onTap: () => _executeTippyFromCommandCenter(
              context,
              tippyEnabled: snapshot.tippyAiEnabled,
            ),
          ),
        ),
      ],
    );
  }
}

class _CommandButton extends StatelessWidget {
  const _CommandButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: Colors.white.withValues(alpha: 0.82), size: 16),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatorBriefCard extends StatelessWidget {
  const _CreatorBriefCard({required this.snapshot});

  final CreatorCommandSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final double progress =
        (snapshot.consistencyScorePercent / 100).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.radar_rounded,
                color: const Color(0xFF93C5FD).withValues(alpha: 0.92),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _briefLine(snapshot, context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    height: 1.22,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SignalChip(label: _momentumLabel(snapshot)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF38BDF8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Consistency ${snapshot.consistencyScorePercent}%',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard({required this.snapshot});

  final CreatorCommandSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final bool urgent = snapshot.nextPostOverdue || snapshot.alertCount > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _executePrimaryAction(context, snapshot),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: urgent
                ? const Color(0xFF3B1117).withValues(alpha: 0.82)
                : const Color(0xFF10223A).withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: urgent
                  ? const Color(0xFFFCA5A5).withValues(alpha: 0.34)
                  : const Color(0xFF60A5FA).withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Icon(
                  _primaryActionIcon(snapshot),
                  color: urgent ? const Color(0xFFFCA5A5) : Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _primaryActionLabel(snapshot),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _primaryActionHint(snapshot),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandedCommandCard extends StatelessWidget {
  const _ExpandedCommandCard({
    super.key,
    required this.snapshot,
    required this.onDismiss,
  });

  final CreatorCommandSnapshot snapshot;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return _GlassShell(
      width: 320,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ExpandedHeader(
              snapshot: snapshot,
              onDismiss: onDismiss,
            ),
            const SizedBox(height: 8),
            _CreatorBriefCard(snapshot: snapshot),
            const SizedBox(height: 8),
            _PrimaryActionCard(snapshot: snapshot),
            const SizedBox(height: 8),
            _QuickCommandRow(snapshot: snapshot),
            const SizedBox(height: 8),
            _ActionStatusBlock(snapshot: snapshot),
          ],
        ),
      ),
    );
  }
}

class _ActionStatusBlock extends StatelessWidget {
  const _ActionStatusBlock({required this.snapshot});

  final CreatorCommandSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final String dueLabel;
    if (snapshot.nextPostDueAt == null) {
      dueLabel = 'No video post scheduled';
    } else {
      final TimeOfDay time =
          TimeOfDay.fromDateTime(snapshot.nextPostDueAt!.toLocal());
      final MaterialLocalizations l10n = MaterialLocalizations.of(context);
      dueLabel =
          '${l10n.formatFullDate(snapshot.nextPostDueAt!.toLocal())} ${l10n.formatTimeOfDay(time)}';
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: snapshot.nextPostOverdue
              ? const Color(0xFFF97373).withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _StatusRow(
            label: snapshot.nextPostOverdue ? 'Due' : 'Next',
            value: dueLabel,
            highlight: snapshot.nextPostOverdue,
          ),
          const SizedBox(height: 6),
          _StatusRow(
            label: 'Due alerts',
            value: snapshot.alertCount > 0 ? '${snapshot.alertCount}' : '0',
          ),
          const SizedBox(height: 6),
          _StatusRow(
            label: 'Queue',
            value: snapshot.scheduledQueueCount > 0
                ? '${snapshot.scheduledQueueCount} scheduled'
                : '0 scheduled',
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final Color color = highlight ? const Color(0xFFF97373) : Colors.white;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.92),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: color.withValues(alpha: 0.86),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    final String label = switch (plan) {
      SubscriptionPlan.pro => 'PRO',
      SubscriptionPlan.studio => 'STUDIO',
      SubscriptionPlan.starter => 'FREE',
      SubscriptionPlan.unknown => 'PLAN',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.35,
        ),
      ),
    );
  }
}

class _GlassShell extends StatelessWidget {
  const _GlassShell({
    super.key,
    required this.child,
    required this.width,
  });

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
