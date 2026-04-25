import 'dart:io';
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../features/gamification/models/subscription_plan.dart';
import '../models/creator_command_snapshot.dart';
import '../providers/creator_command_provider.dart';
import '../routing/app_navigator.dart';
import '../routing/app_routes.dart';
import '../services/local_draft_service.dart';
import 'drafts_sheet_view.dart';
import 'video_publishing_screen.dart';

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
        padding: const EdgeInsets.all(2),
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
            color: const Color(0xFF1E293B),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: 1,
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

    return snapshotAsync.when(
      data: (CreatorCommandSnapshot? snapshot) {
        if (snapshot == null) return const SizedBox.shrink();
        return Positioned.fill(
          child: Stack(
            children: <Widget>[
              if (widget.state == CreatorCommandCenterState.expanded)
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: widget.onDismiss,
                  child: Container(color: Colors.transparent),
                ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                top: widget.state == CreatorCommandCenterState.expanded ? 104 : 84,
                right: 12,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
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
                ),
              ),
            ],
          ),
        );
      },
      loading: () {
        return Positioned(
          top: 104,
          right: 12,
          child: _GlassShell(
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
          ),
        );
      },
      error: (Object error, StackTrace stackTrace) {
        return Positioned(
          top: 104,
          right: 12,
          child: _GlassShell(
            width: 260,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Creator command center is unavailable right now.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      },
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
        width: 250,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Text(
            snapshot.collapsedSummary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
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
    final List<_QuickActionConfig> actions = <_QuickActionConfig>[
      _QuickActionConfig.review(
        snapshot.draftCount > 0,
        badgeCount: snapshot.draftCount,
      ),
      const _QuickActionConfig.publish(),
      _QuickActionConfig.drafts(
        snapshot.draftCount > 0,
        badgeCount: snapshot.draftCount,
      ),
      _QuickActionConfig.tippy(snapshot.tippyAiEnabled),
      const _QuickActionConfig.discover(),
      const _QuickActionConfig.analytics(),
      const _QuickActionConfig.schedule(),
    ];

    return _GlassShell(
      width: 312,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    snapshot.identityLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _PlanBadge(plan: snapshot.subscriptionPlan),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDismiss,
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.74),
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MiniStatPill(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: Colors.orangeAccent,
                    title: snapshot.streakDays > 0
                        ? '🔥 ${snapshot.streakDays} Day Streak'
                        : 'Streak ready',
                    subtitle: streakPulse ? 'Momentum is live' : 'Keep it going',
                    emphasize: streakPulse,
                  ),
                ),
                if (snapshot.growthPercent != null) ...<Widget>[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStatPill(
                      icon: Icons.trending_up_rounded,
                      iconColor: const Color(0xFF5AD6A0),
                      title:
                          '↑${snapshot.growthPercent!.abs().toStringAsFixed(0)}% Growth',
                      subtitle: 'Existing creator metrics',
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Consistency Score: ${snapshot.consistencyScorePercent}%',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (snapshot.consistencyScorePercent / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4897D2)),
              ),
            ),
            const SizedBox(height: 16),
            _ActionStatusBlock(snapshot: snapshot),
            const SizedBox(height: 16),
            Text(
              'Quick Actions',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: actions
                  .map(( _QuickActionConfig action) => _QuickActionChip(action: action))
                  .toList(growable: false),
            ),
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
      dueLabel = 'No scheduled post yet';
    } else {
      final TimeOfDay time = TimeOfDay.fromDateTime(snapshot.nextPostDueAt!.toLocal());
      final MaterialLocalizations l10n = MaterialLocalizations.of(context);
      dueLabel =
          '${l10n.formatFullDate(snapshot.nextPostDueAt!.toLocal())} • ${l10n.formatTimeOfDay(time)}';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: snapshot.nextPostOverdue
              ? const Color(0xFFF97373).withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: <Widget>[
          _StatusRow(
            label: snapshot.nextPostOverdue ? 'Post overdue' : 'Next Post Due',
            value: dueLabel,
            highlight: snapshot.nextPostOverdue,
          ),
          const SizedBox(height: 10),
          _StatusRow(
            label: 'Alerts',
            value: snapshot.alertCount > 0
                ? '${snapshot.alertCount} creator attention item${snapshot.alertCount == 1 ? '' : 's'}'
                : 'No live alerts right now',
          ),
          const SizedBox(height: 10),
          _StatusRow(
            label: 'Pending Work',
            value: snapshot.pendingWorkCount > 0
                ? '${snapshot.pendingWorkCount} draft${snapshot.pendingWorkCount == 1 ? '' : 's'} to review'
                : 'No pending draft work',
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
          width: 92,
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
  const _QuickActionChip({required this.action});

  final _QuickActionConfig action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color foreground = action.enabled
        ? Colors.white
        : Colors.white.withValues(alpha: 0.46);

    return GestureDetector(
      onTap: action.enabled
          ? () => _handleActionTap(context, ref, action)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 86,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: action.enabled ? 0.08 : 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: action.enabled
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.06),
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
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
      case _QuickActionKind.tippy:
        if (action.isLocked) {
          Navigator.of(context).pushNamed(AppRoutes.upgrade);
        } else {
          await AppNavigator.openManagePostsWithArgs(
            context,
            initialTab: ManagePostsInitialTab.scheduled,
            launchSource: ManagePostsLaunchSource.tippy,
          );
        }
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

class _MiniStatPill extends StatelessWidget {
  const _MiniStatPill({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.emphasize = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: emphasize ? 0.11 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: emphasize
              ? iconColor.withValues(alpha: 0.44)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.64),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF9248D2), Color(0xFF4897D2)],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _GlassShell extends StatelessWidget {
  const _GlassShell({
    required this.child,
    required this.width,
  });

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF9248D2).withValues(alpha: 0.38),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.26),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.16),
                blurRadius: 20,
                offset: const Offset(0, 0),
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
  tippy,
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
    this.isLocked = false,
    this.badgeCount,
  });

  const _QuickActionConfig.publish()
      : kind = _QuickActionKind.publish,
        label = 'Publish',
        icon = Icons.publish_rounded,
        enabled = true,
        isLocked = false,
        badgeCount = null;

  const _QuickActionConfig.discover()
      : kind = _QuickActionKind.discover,
        label = 'Discover',
        icon = Icons.explore_rounded,
        enabled = true,
        isLocked = false,
        badgeCount = null;

  const _QuickActionConfig.analytics()
      : kind = _QuickActionKind.analytics,
        label = 'Analytics',
        icon = Icons.insights_rounded,
        enabled = true,
        isLocked = false,
        badgeCount = null;

  const _QuickActionConfig.schedule()
      : kind = _QuickActionKind.schedule,
        label = 'Schedule',
        icon = Icons.schedule_rounded,
        enabled = true,
        isLocked = false,
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

  factory _QuickActionConfig.tippy(bool enabled) {
    return _QuickActionConfig(
      kind: _QuickActionKind.tippy,
      label: enabled ? 'Tippy AI' : 'Tippy Locked',
      icon: enabled ? Icons.auto_awesome_rounded : Icons.lock_outline_rounded,
      enabled: true,
      isLocked: !enabled,
    );
  }

  final _QuickActionKind kind;
  final String label;
  final IconData icon;
  final bool enabled;
  final bool isLocked;
  final int? badgeCount;
}
