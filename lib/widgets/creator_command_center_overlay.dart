import 'dart:io';
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/gamification/models/subscription_plan.dart';
import '../models/creator_command_snapshot.dart';
import '../providers/creator_command_provider.dart';
import '../routing/app_navigator.dart';
import '../routing/app_routes.dart';
import '../services/local_draft_service.dart';
import 'drafts_sheet_view.dart';
import 'video_publishing_screen.dart';

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

String _tippyHeroSubtitle(CreatorCommandSnapshot snapshot) {
  if (!snapshot.tippyAiEnabled) {
    return 'Planning & captions on Pro+';
  }
  if (snapshot.nextPostOverdue) {
    return 'Get back on schedule';
  }
  if (snapshot.pendingWorkCount > 0) {
    return 'Help with your queue';
  }
  if (snapshot.alertCount > 0) {
    return 'Prioritize what matters';
  }
  return 'What to post next';
}

String _nextMoveLine(
  CreatorCommandSnapshot s,
  BuildContext context,
) {
  if (s.nextPostOverdue) {
    return 'Overdue: catch up on your next post';
  }
  if (s.nextPostDueAt != null) {
    final DateTime t = s.nextPostDueAt!.toLocal();
    final MaterialLocalizations l10n = MaterialLocalizations.of(context);
    final String date = l10n.formatFullDate(t);
    final String time = l10n.formatTimeOfDay(
      TimeOfDay.fromDateTime(t),
    );
    return 'Next: $date · $time';
  }
  if (s.pendingWorkCount > 0) {
    return '${s.pendingWorkCount} draft'
        '${s.pendingWorkCount == 1 ? '' : 's'} in review';
  }
  if (s.alertCount > 0) {
    return '${s.alertCount} active alert'
        '${s.alertCount == 1 ? '' : 's'}';
  }
  return 'No scheduled post';
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
      color: const Color(0xFF9248D2).withValues(alpha: showAlertPulse ? 0.38 : 0.24),
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
  bool _isOpeningPulseActive = true;
  Timer? _pulseTimer;

  @override
  void initState() {
    super.initState();
    _pulseTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _isOpeningPulseActive = false;
      });
    });
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

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
                          streakPulse: _isOpeningPulseActive,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.35,
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

class _TippyHeroSection extends StatelessWidget {
  const _TippyHeroSection({required this.snapshot});

  final CreatorCommandSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final bool unlocked = snapshot.tippyAiEnabled;
    final String title = unlocked ? 'Tippy' : 'Tippy (locked)';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _executeTippyFromCommandCenter(
          context,
          tippyEnabled: unlocked,
        ),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF4897D2).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 3,
                height: 32,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0xFF9248D2), Color(0xFF4897D2)],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                unlocked
                    ? Icons.auto_awesome_rounded
                    : Icons.lock_outline_rounded,
                color: Colors.white.withValues(alpha: 0.92),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _tippyHeroSubtitle(snapshot),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.45),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HudStatLine extends StatelessWidget {
  const _HudStatLine({required this.snapshot, required this.streakPulse});

  final CreatorCommandSnapshot snapshot;
  final bool streakPulse;

  @override
  Widget build(BuildContext context) {
    final String streak = snapshot.streakDays > 0
        ? '🔥 ${snapshot.streakDays}d'
        : 'Streak: —';
    final String? growth = snapshot.growthPercent != null
        ? '↑${snapshot.growthPercent!.abs().toStringAsFixed(0)}%'
        : null;
    return Text(
      growth == null ? streak : '$streak  ·  $growth',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: streakPulse
            ? Colors.orangeAccent.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.7),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _ExpandedCommandCard extends StatelessWidget {
  const _ExpandedCommandCard({
    super.key,
    required this.snapshot,
    required this.streakPulse,
    required this.onDismiss,
  });

  final CreatorCommandSnapshot snapshot;
  final bool streakPulse;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final bool hasQueue =
        snapshot.draftCount > 0 || snapshot.pendingWorkCount > 0;
    final int reviewBadge = snapshot.pendingWorkCount > 0
        ? snapshot.pendingWorkCount
        : snapshot.draftCount;

    return _GlassShell(
      width: 300,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ExpandedHeader(
              snapshot: snapshot,
              onDismiss: onDismiss,
            ),
            const SizedBox(height: 6),
            Text(
              _nextMoveLine(snapshot, context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            _TippyHeroSection(snapshot: snapshot),
            const SizedBox(height: 8),
            _HudStatLine(snapshot: snapshot, streakPulse: streakPulse),
            const SizedBox(height: 8),
            Text(
              'Consistency ${snapshot.consistencyScorePercent}%',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (snapshot.consistencyScorePercent / 100).clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF4897D2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _ActionStatusBlock(snapshot: snapshot),
            const SizedBox(height: 10),
            const _SectionTitle(title: 'Shortcuts'),
            const SizedBox(height: 8),
            _QuickActionRows(
              rowOne: <_QuickActionConfig>[
                _QuickActionConfig.review(
                  hasQueue,
                  badgeCount: reviewBadge,
                ),
                const _QuickActionConfig.publish(),
                _QuickActionConfig.drafts(
                  snapshot.draftCount > 0,
                  badgeCount: snapshot.draftCount,
                ),
              ],
              rowTwo: const <_QuickActionConfig>[
                _QuickActionConfig.discover(),
                _QuickActionConfig.analytics(),
                _QuickActionConfig.schedule(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionRows extends StatelessWidget {
  const _QuickActionRows({
    required this.rowOne,
    required this.rowTwo,
  });

  final List<_QuickActionConfig> rowOne;
  final List<_QuickActionConfig> rowTwo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            for (int i = 0; i < rowOne.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i < rowOne.length - 1 ? 8 : 0,
                  ),
                  child: _QuickActionChip(
                    action: rowOne[i],
                    stretchHorizontally: true,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            for (int i = 0; i < rowTwo.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i < rowTwo.length - 1 ? 8 : 0,
                  ),
                  child: _QuickActionChip(
                    action: rowTwo[i],
                    stretchHorizontally: true,
                  ),
                ),
              ),
          ],
        ),
      ],
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
      dueLabel = '—';
    } else {
      final TimeOfDay time = TimeOfDay.fromDateTime(snapshot.nextPostDueAt!.toLocal());
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
            label: 'Alerts',
            value: snapshot.alertCount > 0
                ? '${snapshot.alertCount}'
                : '0',
          ),
          const SizedBox(height: 6),
          _StatusRow(
            label: 'Queue',
            value: snapshot.pendingWorkCount > 0
                ? '${snapshot.pendingWorkCount} draft'
                    '${snapshot.pendingWorkCount == 1 ? '' : 's'}'
                : '—',
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
          width: 48,
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

class _QuickActionChip extends ConsumerWidget {
  const _QuickActionChip({
    required this.action,
    this.stretchHorizontally = false,
  });

  final _QuickActionConfig action;
  final bool stretchHorizontally;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color foreground = action.enabled
        ? Colors.white
        : Colors.white.withValues(alpha: 0.46);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.enabled
            ? () => _handleActionTap(context, ref, action)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: stretchHorizontally ? double.infinity : 86,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: action.enabled
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: action.enabled
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Icon(action.icon, color: foreground, size: 20),
                  if (action.badgeCount != null && action.badgeCount! > 0)
                    Positioned(
                      right: -8,
                      top: -6,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${action.badgeCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleActionTap(
    BuildContext context,
    WidgetRef ref,
    _QuickActionConfig action,
  ) async {
    HapticFeedback.lightImpact();
    switch (action.kind) {
      case _QuickActionKind.publish:
        Navigator.of(context).pushNamed(AppRoutes.camera);
        return;
      case _QuickActionKind.discover:
        await AppNavigator.openDiscover(context);
        return;
      case _QuickActionKind.analytics:
        await AppNavigator.openManagePostsWithArgs(
          context,
          initialTab: ManagePostsInitialTab.published,
          launchSource: ManagePostsLaunchSource.commandCenter,
        );
        return;
      case _QuickActionKind.schedule:
        await AppNavigator.openManagePostsWithArgs(
          context,
          initialTab: ManagePostsInitialTab.scheduled,
          launchSource: ManagePostsLaunchSource.commandCenter,
        );
        return;
      case _QuickActionKind.review:
      case _QuickActionKind.drafts:
        await _openDrafts(context);
        return;
    }
  }

  Future<void> _openDrafts(BuildContext context) async {
    final List<Map<String, dynamic>> drafts = await LocalDraftService().getAllDrafts();
    if (!context.mounted) return;
    if (drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No drafts are available right now.'),
          backgroundColor: Color(0xFF1E293B),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => DraftsSheetView(
          drafts: drafts,
          onDraftTap: (Map<String, dynamic> selectedDraft) {
            _openDraftEditor(context, selectedDraft);
          },
          onDelete: (Map<String, dynamic> draftToDelete) async {
            return LocalDraftService().deleteDraft(draftToDelete['id'] as String);
          },
        ),
      ),
    );
  }

  Future<void> _openDraftEditor(
    BuildContext context,
    Map<String, dynamic> draft,
  ) async {
    final String? draftId = draft['id'] as String?;
    if (draftId == null || draftId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft is missing its ID.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final File? videoFile = await LocalDraftService().ensureLocalVideoFile(draftId);
    if (!context.mounted) return;
    if (videoFile == null || !videoFile.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft video is not available on this device yet.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final List<String> hashtags = (draft['hashtags'] as List<dynamic>?)
            ?.map((dynamic item) => item.toString())
            .toList(growable: false) ??
        const <String>[];

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => VideoPublishingScreen(
          videoFile: videoFile,
          caption: draft['caption'] as String? ?? '',
          hashtags: hashtags,
          onPublish: () {
            LocalDraftService().deleteDraft(draftId);
            Navigator.of(context).pop();
          },
          onCancel: () {
            Navigator.of(context).pop();
          },
          draftId: draftId,
          draftData: draft,
        ),
      ),
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

enum _QuickActionKind {
  review,
  publish,
  drafts,
  discover,
  analytics,
  schedule,
}

class _QuickActionConfig {
  const _QuickActionConfig({
    required this.kind,
    required this.label,
    required this.icon,
    required this.enabled,
    this.badgeCount,
  });

  const _QuickActionConfig.publish()
      : kind = _QuickActionKind.publish,
        label = 'Publish',
        icon = Icons.publish_rounded,
        enabled = true,
        badgeCount = null;

  const _QuickActionConfig.discover()
      : kind = _QuickActionKind.discover,
        label = 'Discover',
        icon = Icons.explore_rounded,
        enabled = true,
        badgeCount = null;

  const _QuickActionConfig.analytics()
      : kind = _QuickActionKind.analytics,
        label = 'Analytics',
        icon = Icons.insights_rounded,
        enabled = true,
        badgeCount = null;

  const _QuickActionConfig.schedule()
      : kind = _QuickActionKind.schedule,
        label = 'Schedule',
        icon = Icons.schedule_rounded,
        enabled = true,
        badgeCount = null;

  factory _QuickActionConfig.review(bool enabled, {int badgeCount = 0}) {
    return _QuickActionConfig(
      kind: _QuickActionKind.review,
      label: 'Review Clips',
      icon: Icons.content_cut_rounded,
      enabled: enabled,
      badgeCount: enabled && badgeCount > 0 ? badgeCount : null,
    );
  }

  factory _QuickActionConfig.drafts(bool enabled, {int badgeCount = 0}) {
    return _QuickActionConfig(
      kind: _QuickActionKind.drafts,
      label: 'Drafts',
      icon: Icons.drafts_rounded,
      enabled: enabled,
      badgeCount: enabled && badgeCount > 0 ? badgeCount : null,
    );
  }

  final _QuickActionKind kind;
  final String label;
  final IconData icon;
  final bool enabled;
  final int? badgeCount;
}
