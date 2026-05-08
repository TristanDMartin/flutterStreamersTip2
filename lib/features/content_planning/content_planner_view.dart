import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/creator_command_snapshot.dart';
import '../../providers/creator_command_provider.dart';
import '../../routing/app_navigator.dart';
import 'content_plan_detail_view.dart';
import 'content_planning_models.dart';
import 'content_planning_provider.dart';

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

class _PlannerScaffold extends StatelessWidget {
  const _PlannerScaffold({
    required this.snapshot,
    required this.plansAsync,
    required this.onRefreshPlans,
  });

  final CreatorCommandSnapshot? snapshot;
  final AsyncValue<List<ContentPlan>> plansAsync;
  final VoidCallback onRefreshPlans;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color background =
        dark ? const Color(0xFF050816) : const Color(0xFFF8FAFC);
    final Color card = dark ? const Color(0xFF0B1220) : Colors.white;
    final Color text = theme.colorScheme.onSurface;
    final Color muted =
        dark ? Colors.white.withValues(alpha: 0.64) : const Color(0xFF475569);

    final int queue = snapshot?.scheduledQueueCount ?? 0;
    final int drafts = snapshot?.draftCount ?? 0;
    final int alerts = snapshot?.alertCount ?? 0;
    final int consistency = snapshot?.consistencyScorePercent ?? 0;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Content Planner'),
        backgroundColor: background,
        foregroundColor: text,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          _PlannerHeroCard(
            card: card,
            text: text,
            muted: muted,
            consistency: consistency,
            queue: queue,
            alerts: alerts,
          ),
          const SizedBox(height: 12),
          _SchedulerEntryCard(card: card, text: text, muted: muted),
          const SizedBox(height: 12),
          _PlansSection(
            plansAsync: plansAsync,
            card: card,
            text: text,
            muted: muted,
            onRefresh: onRefreshPlans,
          ),
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
                  value: '$drafts',
                  accent: const Color(0xFF9248D2),
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
                  value: '$alerts',
                  accent: alerts > 0
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF22C55E),
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PlannerNextCard(
            card: card,
            text: text,
            muted: muted,
            snapshot: snapshot,
          ),
          const SizedBox(height: 14),
          _PlannerWebSyncCard(card: card, muted: muted),
        ],
      ),
    );
  }
}

class _PlannerHeroCard extends StatelessWidget {
  const _PlannerHeroCard({
    required this.card,
    required this.text,
    required this.muted,
    required this.consistency,
    required this.queue,
    required this.alerts,
  });

  final Color card;
  final Color text;
  final Color muted;
  final int consistency;
  final int queue;
  final int alerts;

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
                  alerts > 0
                      ? 'Review blocked posts first'
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
    final String subtitle = updated == null
        ? '${plan.itemCount} items'
        : '${plan.itemCount} items · ${MaterialLocalizations.of(context).formatMediumDate(updated)}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: <Widget>[
              const Icon(Icons.view_timeline_rounded, color: Color(0xFF9248D2)),
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
  });

  final Color card;
  final Color text;
  final Color muted;
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _PlannerNextCard extends StatelessWidget {
  const _PlannerNextCard({
    required this.card,
    required this.text,
    required this.muted,
    required this.snapshot,
  });

  final Color card;
  final Color text;
  final Color muted;
  final CreatorCommandSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final DateTime? due = snapshot?.nextPostDueAt?.toLocal();
    final bool overdue = snapshot?.nextPostOverdue ?? false;
    final String value;
    if (due == null) {
      value = 'No scheduled post is queued yet.';
    } else {
      final MaterialLocalizations l10n = MaterialLocalizations.of(context);
      value =
          '${l10n.formatFullDate(due)} at ${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(due))}';
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
                  overdue ? 'Overdue post' : 'Next scheduled post',
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
            child: Text(
              'Full planning, templates, calendar sync, and workflows stay on streamerstip.com.',
              style: TextStyle(
                color: muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannerLoadingScaffold extends StatelessWidget {
  const _PlannerLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Content Planner')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _PlannerErrorScaffold extends StatelessWidget {
  const _PlannerErrorScaffold({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Content Planner')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Could not load planner data.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
