import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/support_shell_style.dart';
import '../../models/creator_command_snapshot.dart';
import '../../providers/creator_command_provider.dart';
import '../../routing/app_navigator.dart';
import 'content_plan_detail_view.dart';
import 'content_planning_models.dart';
import 'content_planning_provider.dart';
import '../../components/onboarding/contextual_tip_overlay.dart';

EdgeInsets _plannerScrollPadding(BuildContext context) {
  final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;
  return EdgeInsets.fromLTRB(16, 8, 16, 32 + bottomInset);
}

class ContentPlannerView extends ConsumerWidget {
  const ContentPlannerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CreatorCommandSnapshot?> snapshotAsync =
        ref.watch(creatorCommandSnapshotProvider);
    final AsyncValue<List<ContentPlan>> plansAsync =
        ref.watch(contentPlansProvider);
    return snapshotAsync.when(
      data: (CreatorCommandSnapshot? snapshot) {
        return _PlannerScaffold(
          snapshot: snapshot,
          plansAsync: plansAsync,
          onRefreshPlans: () => ref.invalidate(contentPlansProvider),
        );
      },
      loading: () => const _PlannerLoadingScaffold(),
      error: (Object error, StackTrace stackTrace) {
        return _PlannerErrorScaffold(
          onRetry: () => ref.invalidate(creatorCommandSnapshotProvider),
        );
      },
    );
  }
}

class _PlannerScaffold extends StatefulWidget {
  const _PlannerScaffold({
    required this.snapshot,
    required this.plansAsync,
    required this.onRefreshPlans,
  });

  final CreatorCommandSnapshot? snapshot;
  final AsyncValue<List<ContentPlan>> plansAsync;
  final VoidCallback onRefreshPlans;

  @override
  State<_PlannerScaffold> createState() => _PlannerScaffoldState();
}

class _PlannerScaffoldState extends State<_PlannerScaffold> {
  @override
  void initState() {
    super.initState();
    ContextualTipCatalog.scheduleFeatureTipOnMount(
      context: context,
      tip: ContextualTipCatalog.contentPlannerTip,
    );
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final Color background = shell.scaffold;
    final Color card = shell.surfaceCard;
    final Color text = shell.onChrome;
    final Color muted = shell.muted;

    final int queue = widget.snapshot?.scheduledQueueCount ?? 0;
    final int consistency = widget.snapshot?.consistencyScorePercent ?? 0;
    final List<ContentPlan> plans =
        widget.plansAsync.valueOrNull ?? const <ContentPlan>[];
    final DateTime now = DateTime.now();
    final List<ContentPlan> scheduledPlans = plans
        .where((ContentPlan plan) =>
            plan.status == 'scheduled' &&
            plan.scheduledAt != null &&
            plan.scheduledAt!.isAfter(now))
        .toList()
      ..sort((ContentPlan a, ContentPlan b) =>
          a.scheduledAt!.compareTo(b.scheduledAt!));
    final List<ContentPlan> unscheduledIdeas = plans
        .where((ContentPlan plan) =>
            plan.scheduledAt == null &&
            (plan.status == 'planned' ||
                plan.status == 'draft' ||
                plan.source == 'tippy_ai'))
        .toList();
    final List<ContentPlan> draftPlans = plans
        .where((ContentPlan plan) =>
            plan.status == 'draft' || plan.status == 'planned')
        .toList();
    final List<ContentPlan> needsReviewPlans = plans
        .where((ContentPlan plan) =>
            plan.status == 'needsReview' ||
            (plan.caption ?? '').trim().isEmpty ||
            (plan.platform ?? '').trim().isEmpty ||
            plan.scheduledAt == null)
        .toList();
    final int draftPlanCount = draftPlans.length;
    final int needsReviewPlanCount = needsReviewPlans.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Content Planner'),
        backgroundColor: background.withValues(alpha: 0.92),
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: shell.pageGradient,
              ),
            ),
            child: const SizedBox.expand(),
          ),
          ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: _plannerScrollPadding(context),
            children: <Widget>[
              _PlannerHeroCard(
                card: card,
                text: text,
                muted: muted,
                consistency: consistency,
                queue: queue,
                needsReviewPlanCount: needsReviewPlanCount,
              ),
              const SizedBox(height: 12),
              _SchedulerEntryCard(card: card, text: text, muted: muted),
              const SizedBox(height: 12),
              _PlansSection(
                plansAsync: widget.plansAsync,
                card: card,
                text: text,
                muted: muted,
                onRefresh: widget.onRefreshPlans,
              ),
              if (unscheduledIdeas.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                _IdeasSection(
                  plans: unscheduledIdeas,
                  card: card,
                  text: text,
                  muted: muted,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _PlannerMetricCard(
                      card: card,
                      text: text,
                      muted: muted,
                      icon: Icons.schedule_rounded,
                      label: 'Scheduled',
                      value: '$queue',
                      accent: const Color(0xFF4897D2),
                      onTap: () => _openFilteredPlans(
                        context,
                        'Scheduled',
                        scheduledPlans,
                        emptyMessage: 'No upcoming scheduled posts.',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PlannerMetricCard(
                      card: card,
                      text: text,
                      muted: muted,
                      icon: Icons.edit_note_rounded,
                      label: 'Drafts',
                      value: '$draftPlanCount',
                      accent: const Color(0xFF9248D2),
                      onTap: () => _openFilteredPlans(
                        context,
                        'Drafts',
                        draftPlans,
                        emptyMessage: 'No saved drafts yet.',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _PlannerMetricCard(
                      card: card,
                      text: text,
                      muted: muted,
                      icon: Icons.priority_high_rounded,
                      label: 'Needs Review',
                      value: '$needsReviewPlanCount',
                      accent: needsReviewPlanCount > 0
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF22C55E),
                      onTap: () => _openFilteredPlans(
                        context,
                        'Needs Review',
                        needsReviewPlans,
                        emptyMessage: 'No plans need review.',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PlannerMetricCard(
                      card: card,
                      text: text,
                      muted: muted,
                      icon: Icons.auto_graph_rounded,
                      label: 'Consistency',
                      value: '$consistency%',
                      accent: const Color(0xFF22C55E),
                      onTap: () => _openConsistencyView(
                        context,
                        consistency: consistency,
                        plans: plans,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PlannerNextCard(
                card: card,
                text: text,
                muted: muted,
                plan: scheduledPlans.isEmpty ? null : scheduledPlans.first,
              ),
              const SizedBox(height: 14),
              _PlannerWebSyncCard(card: card, muted: muted),
            ],
          ),
        ],
      ),
    );
  }
}

void _openFilteredPlans(
  BuildContext context,
  String title,
  List<ContentPlan> plans, {
  required String emptyMessage,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext ctx) => _FilteredPlansView(
        title: title,
        plans: plans,
        emptyMessage: emptyMessage,
      ),
    ),
  );
}

void _openConsistencyView(
  BuildContext context, {
  required int consistency,
  required List<ContentPlan> plans,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext ctx) => _ConsistencyPlansView(
        consistency: consistency,
        plans: plans,
      ),
    ),
  );
}

class _PlannerHeroCard extends StatelessWidget {
  const _PlannerHeroCard({
    required this.card,
    required this.text,
    required this.muted,
    required this.consistency,
    required this.queue,
    required this.needsReviewPlanCount,
  });

  final Color card;
  final Color text;
  final Color muted;
  final int consistency;
  final int queue;
  final int needsReviewPlanCount;

  @override
  Widget build(BuildContext context) {
    final double progress = (consistency / 100).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: muted.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF9248D2), Color(0xFF4897D2)],
                  ),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  needsReviewPlanCount > 0
                      ? 'Some plans need review'
                      : queue > 0
                          ? 'Your plan is moving'
                          : 'Build your next posting rhythm',
                  style: TextStyle(
                    color: text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: muted.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF4897D2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Planning consistency $consistency%',
            style: TextStyle(
              color: muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SchedulerEntryCard extends StatelessWidget {
  const _SchedulerEntryCard({
    required this.card,
    required this.text,
    required this.muted,
  });

  final Color card;
  final Color text;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF4897D2).withValues(alpha: 0.22)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.queue_play_next_rounded, color: Color(0xFF4897D2)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Content Scheduler',
                  style: TextStyle(
                    color: text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'View queued jobs and scheduler drafts.',
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => AppNavigator.openContentScheduler(context),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
}

class _PlansSection extends StatelessWidget {
  const _PlansSection({
    required this.plansAsync,
    required this.card,
    required this.text,
    required this.muted,
    required this.onRefresh,
  });

  final AsyncValue<List<ContentPlan>> plansAsync;
  final Color card;
  final Color text;
  final Color muted;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return plansAsync.when(
      data: (List<ContentPlan> plans) {
        if (plans.isEmpty) {
          return _PlansShell(
            card: card,
            text: text,
            muted: muted,
            title: 'Content plans',
            trailing: IconButton(
              tooltip: 'Refresh plans',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
            child: Text(
              'Plans created by Tippy or streamerstip.com will appear here.',
              style: TextStyle(
                color: muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }
        return _PlansShell(
          card: card,
          text: text,
          muted: muted,
          title: 'Content plans',
          trailing: IconButton(
            tooltip: 'Refresh plans',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          child: Column(
            children: plans.take(3).map((ContentPlan plan) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PlanRow(
                  plan: plan,
                  text: text,
                  muted: muted,
                  onOpen: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext ctx) =>
                            ContentPlanDetailView(plan: plan),
                      ),
                    );
                  },
                ),
              );
            }).toList(growable: false),
          ),
        );
      },
      loading: () {
        return _PlansShell(
          card: card,
          text: text,
          muted: muted,
          title: 'Content plans',
          child: Row(
            children: <Widget>[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text(
                'Syncing plans...',
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
      error: (Object error, StackTrace stackTrace) {
        return _PlansShell(
          card: card,
          text: text,
          muted: muted,
          title: 'Content plans',
          trailing: IconButton(
            tooltip: 'Retry plans',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          child: Text(
            'Could not sync plans from streamerstip.com.',
            style: TextStyle(
              color: muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}

class _IdeasSection extends StatelessWidget {
  const _IdeasSection({
    required this.plans,
    required this.card,
    required this.text,
    required this.muted,
  });

  final List<ContentPlan> plans;
  final Color card;
  final Color text;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return _PlansShell(
      card: card,
      text: text,
      muted: muted,
      title: 'Ideas / Unscheduled',
      trailing: Text(
        '${plans.length}',
        style: TextStyle(
          color: muted,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
      child: Column(
        children: plans.take(4).map((ContentPlan plan) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PlanRow(
              plan: plan,
              text: text,
              muted: muted,
              onOpen: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext ctx) =>
                        ContentPlanDetailView(plan: plan),
                  ),
                );
              },
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _PlansShell extends StatelessWidget {
  const _PlansShell({
    required this.card,
    required this.text,
    required this.muted,
    required this.title,
    required this.child,
    this.trailing,
  });

  final Color card;
  final Color text;
  final Color muted;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: muted.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.plan,
    required this.text,
    required this.muted,
    required this.onOpen,
  });

  final ContentPlan plan;
  final Color text;
  final Color muted;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final DateTime? updated = plan.updatedAt?.toLocal();
    final DateTime? scheduled = plan.scheduledAt?.toLocal();
    final String dateLabel = scheduled != null
        ? MaterialLocalizations.of(context).formatMediumDate(scheduled)
        : updated == null
            ? 'Unscheduled'
            : MaterialLocalizations.of(context).formatMediumDate(updated);
    final String subtitle = <String>[
      '${plan.itemCount} items',
      plan.status,
      if (plan.source == 'tippy_ai') 'Tippy AI',
      dateLabel,
    ].where((String value) => value.trim().isNotEmpty).join(' · ');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.view_timeline_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      plan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: text,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: muted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlannerMetricCard extends StatelessWidget {
  const _PlannerMetricCard({
    required this.card,
    required this.text,
    required this.muted,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.onTap,
  });

  final Color card;
  final Color text;
  final Color muted;
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: muted.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(icon, color: accent, size: 20),
                  const SizedBox(height: 12),
                  Text(
                    value,
                    style: TextStyle(
                      color: text,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
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

class _PlannerNextCard extends StatelessWidget {
  const _PlannerNextCard({
    required this.card,
    required this.text,
    required this.muted,
    required this.plan,
  });

  final Color card;
  final Color text;
  final Color muted;
  final ContentPlan? plan;

  @override
  Widget build(BuildContext context) {
    final DateTime? due = plan?.scheduledAt?.toLocal();
    final bool overdue = due != null && due.isBefore(DateTime.now());
    final String value;
    if (due == null) {
      value = 'Schedule your next post';
    } else {
      final MaterialLocalizations l10n = MaterialLocalizations.of(context);
      final Duration remaining = due.difference(DateTime.now());
      final String timeRemaining = remaining.inDays > 0
          ? '${remaining.inDays}d remaining'
          : '${remaining.inHours.clamp(0, 999)}h remaining';
      value =
          '${plan!.title}\n${plan!.platform ?? 'Platform TBD'} · ${l10n.formatMediumDate(due)} at ${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(due))} · $timeRemaining'
          '${(plan!.caption ?? '').trim().isEmpty ? '' : '\n${plan!.caption!.trim()}'}';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: overdue
              ? const Color(0xFFEF4444).withValues(alpha: 0.45)
              : muted.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            overdue
                ? Icons.warning_amber_rounded
                : Icons.event_available_rounded,
            color: overdue ? const Color(0xFFEF4444) : const Color(0xFF4897D2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  overdue
                      ? 'Overdue post'
                      : due == null
                          ? 'Next scheduled post'
                          : 'Next scheduled post',
                  style: TextStyle(
                    color: text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
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

class _PlannerWebSyncCard extends StatelessWidget {
  const _PlannerWebSyncCard({
    required this.card,
    required this.muted,
  });

  final Color card;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final Color text = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: muted.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.sync_rounded, color: Color(0xFF9248D2)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Full planning, templates, calendar sync, and workflows stay on streamerstip.com.',
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    launchUrl(
                      Uri.parse('https://www.streamerstip.com/content-planner'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(
                    'Open Desktop Planner',
                    style: TextStyle(color: text),
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

class _FilteredPlansView extends StatelessWidget {
  const _FilteredPlansView({
    required this.title,
    required this.plans,
    required this.emptyMessage,
  });

  final String title;
  final List<ContentPlan> plans;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: shell.scaffold.withValues(alpha: 0.92),
        foregroundColor: shell.onChrome,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: shell.pageGradient,
              ),
            ),
            child: const SizedBox.expand(),
          ),
          plans.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      emptyMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: shell.muted,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: _plannerScrollPadding(context),
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final ContentPlan plan = plans[index];
                    final DateTime? scheduled = plan.scheduledAt?.toLocal();
                    return Material(
                      color: shell.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ContentPlanDetailView(plan: plan),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: shell.surfaceCardBorder),
                          ),
                          child: ListTile(
                            title: Text(
                              plan.title,
                              style: TextStyle(
                                color: shell.onChrome,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              <String>[
                                if ((plan.platform ?? '').isNotEmpty)
                                  plan.platform!,
                                if ((plan.status).isNotEmpty) plan.status,
                                if (scheduled != null)
                                  scheduled.toString().split('.').first,
                                if ((plan.caption ?? '').trim().isNotEmpty)
                                  plan.caption!.trim(),
                              ].join('\n'),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: shell.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              color: shell.iconDim,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}

class _ConsistencyPlansView extends StatelessWidget {
  const _ConsistencyPlansView({
    required this.consistency,
    required this.plans,
  });

  final int consistency;
  final List<ContentPlan> plans;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final int scheduled = plans.where((p) => p.status == 'scheduled').length;
    final int drafts = plans.where((p) => p.status == 'draft').length;
    final Set<String> platforms = plans
        .map((ContentPlan p) => p.platform ?? '')
        .where((String p) => p.trim().isNotEmpty)
        .toSet();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Consistency'),
        backgroundColor: shell.scaffold.withValues(alpha: 0.92),
        foregroundColor: shell.onChrome,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: shell.pageGradient,
              ),
            ),
            child: const SizedBox.expand(),
          ),
          ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: _plannerScrollPadding(context),
            children: <Widget>[
              _ConsistencyTile(
                title: 'Weekly posting goal',
                value: '$scheduled scheduled',
              ),
              _ConsistencyTile(
                title: 'Posting streak',
                value: '$consistency% planning consistency',
              ),
              _ConsistencyTile(
                title: 'Recommended next post',
                value: drafts > 0
                    ? 'Finish one of your drafts'
                    : 'Schedule your next post',
              ),
              _ConsistencyTile(
                title: 'Content gaps by platform',
                value: platforms.isEmpty
                    ? 'Pick a platform for your next plan'
                    : 'Active platforms: ${platforms.join(', ')}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConsistencyTile extends StatelessWidget {
  const _ConsistencyTile({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: shell.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: shell.surfaceCardBorder),
        ),
        child: ListTile(
          title: Text(
            title,
            style: TextStyle(
              color: shell.onChrome,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            value,
            style: TextStyle(
              color: shell.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlannerLoadingScaffold extends StatelessWidget {
  const _PlannerLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Content Planner'),
        backgroundColor: shell.scaffold.withValues(alpha: 0.92),
        foregroundColor: shell.onChrome,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: shell.pageGradient,
              ),
            ),
            child: const SizedBox.expand(),
          ),
          Center(
            child: CircularProgressIndicator(color: shell.refreshColor),
          ),
        ],
      ),
    );
  }
}

class _PlannerErrorScaffold extends StatelessWidget {
  const _PlannerErrorScaffold({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Content Planner'),
        backgroundColor: shell.scaffold.withValues(alpha: 0.92),
        foregroundColor: shell.onChrome,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: shell.pageGradient,
              ),
            ),
            child: const SizedBox.expand(),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Could not load planner data.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: shell.onChrome,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
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
