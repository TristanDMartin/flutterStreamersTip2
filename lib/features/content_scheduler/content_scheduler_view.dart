import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/support_shell_style.dart';
import 'content_scheduler_models.dart';
import 'content_scheduler_provider.dart';

class ContentSchedulerView extends ConsumerWidget {
  const ContentSchedulerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SchedulerQueueItem>> queue =
        ref.watch(contentSchedulerQueueProvider);
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final Color card = shell.surfaceCard;
    final Color text = shell.onChrome;
    final Color muted = shell.muted;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: shell.pageGradient,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Content Scheduler'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: shell.onChrome,
          actions: <Widget>[
            IconButton(
              tooltip: 'Refresh queue',
              onPressed: () => ref.invalidate(contentSchedulerQueueProvider),
              icon: Icon(Icons.refresh_rounded, color: shell.onChrome),
            ),
          ],
        ),
        body: queue.when(
          data: (List<SchedulerQueueItem> rows) {
            return _SchedulerQueueBody(
              rows: rows,
              card: card,
              text: text,
              muted: muted,
              onRefresh: () async {
                ref.invalidate(contentSchedulerQueueProvider);
                await ref.read(contentSchedulerQueueProvider.future);
              },
            );
          },
          loading: () => _SchedulerLoadingBody(card: card, muted: muted),
          error: (Object error, StackTrace stackTrace) {
            return _SchedulerQueueBody(
              rows: const <SchedulerQueueItem>[],
              card: card,
              text: text,
              muted: muted,
              error: 'Could not load the scheduler queue.',
              onRefresh: () async {
                ref.invalidate(contentSchedulerQueueProvider);
                await ref.read(contentSchedulerQueueProvider.future);
              },
            );
          },
        ),
      ),
    );
  }
}

class _SchedulerQueueBody extends StatelessWidget {
  const _SchedulerQueueBody({
    required this.rows,
    required this.card,
    required this.text,
    required this.muted,
    required this.onRefresh,
    this.error,
  });

  final List<SchedulerQueueItem> rows;
  final Color card;
  final Color text;
  final Color muted;
  final Future<void> Function() onRefresh;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final int scheduled = rows
        .where(
          (SchedulerQueueItem row) =>
              row.status == SchedulerQueueStatus.scheduled,
        )
        .length;
    final int drafts =
        rows.where((SchedulerQueueItem row) => row.isDraft).length;
    final int failed = rows
        .where((SchedulerQueueItem row) =>
            row.status == SchedulerQueueStatus.failed)
        .length;

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: StSupportShellStyle.of(context).refreshBackground,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          _SchedulerSummaryCard(
            card: card,
            text: text,
            muted: muted,
            total: rows.length,
            scheduled: scheduled,
            drafts: drafts,
            failed: failed,
            error: error,
          ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            _SchedulerEmptyCard(card: card, text: text, muted: muted)
          else
            ...rows.map(
              (SchedulerQueueItem row) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SchedulerQueueRow(
                  row: row,
                  card: card,
                  text: text,
                  muted: muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SchedulerSummaryCard extends StatelessWidget {
  const _SchedulerSummaryCard({
    required this.card,
    required this.text,
    required this.muted,
    required this.total,
    required this.scheduled,
    required this.drafts,
    required this.failed,
    this.error,
  });

  final Color card;
  final Color text;
  final Color muted;
  final int total;
  final int scheduled;
  final int drafts;
  final int failed;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: shell.surfaceCardBorder),
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
                  color: cs.primaryContainer,
                ),
                child: Icon(
                  Icons.queue_play_next_rounded,
                  color: cs.onPrimaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  error == null ? 'Queue view' : 'Queue unavailable',
                  style: TextStyle(
                    color: text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            error ??
                'Merged from cross-post jobs and scheduler drafts, sorted newest first.',
            style: TextStyle(
              color: muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _SummaryPill(
                label: 'Total',
                value: '$total',
                muted: muted,
                onStrong: text,
              ),
              const SizedBox(width: 8),
              _SummaryPill(
                label: 'Scheduled',
                value: '$scheduled',
                muted: muted,
                onStrong: text,
              ),
              const SizedBox(width: 8),
              _SummaryPill(
                label: 'Drafts',
                value: '$drafts',
                muted: muted,
                onStrong: text,
              ),
              if (failed > 0) ...<Widget>[
                const SizedBox(width: 8),
                _SummaryPill(
                  label: 'Failed',
                  value: '$failed',
                  muted: muted,
                  onStrong: text,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
    required this.muted,
    required this.onStrong,
  });

  final String label;
  final String value;
  final Color muted;
  final Color onStrong;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: shell.chipUnselectedBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: shell.chipUnselectedBorder),
        ),
        child: Column(
          children: <Widget>[
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: onStrong,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchedulerQueueRow extends StatelessWidget {
  const _SchedulerQueueRow({
    required this.row,
    required this.card,
    required this.text,
    required this.muted,
  });

  final SchedulerQueueItem row;
  final Color card;
  final Color text;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final MaterialLocalizations l10n = MaterialLocalizations.of(context);
    final DateTime localTime = row.sortTime.toLocal();
    final ColorScheme cs = Theme.of(context).colorScheme;
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _schedulerStatusColor(cs, row.status).withValues(alpha: 0.35),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: shell.shadowSoft,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusBadge(status: row.status),
            ],
          ),
          if (row.caption.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              row.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Icon(Icons.schedule_rounded, size: 15, color: muted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${l10n.formatMediumDate(localTime)} ${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(localTime))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                row.platforms.isEmpty
                    ? 'No platforms'
                    : row.platforms.join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: muted,
                  fontSize: 11.5,
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final SchedulerQueueStatus status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color color = _schedulerStatusColor(cs, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        schedulerStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SchedulerEmptyCard extends StatelessWidget {
  const _SchedulerEmptyCard({
    required this.card,
    required this.text,
    required this.muted,
  });

  final Color card;
  final Color text;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: shell.surfaceCardBorder),
      ),
      child: Column(
        children: <Widget>[
          Icon(Icons.inbox_rounded, color: muted, size: 32),
          const SizedBox(height: 10),
          Text(
            'No queue items yet',
            style: TextStyle(
              color: text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Scheduled jobs and saved scheduler drafts will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SchedulerLoadingBody extends StatelessWidget {
  const _SchedulerLoadingBody({required this.card, required this.muted});

  final Color card;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: shell.surfaceCardBorder),
        ),
        child: CircularProgressIndicator(color: cs.primary),
      ),
    );
  }
}

Color _schedulerStatusColor(ColorScheme cs, SchedulerQueueStatus status) {
  return switch (status) {
    SchedulerQueueStatus.scheduled => cs.primary,
    SchedulerQueueStatus.publishing => cs.tertiary,
    SchedulerQueueStatus.published => cs.secondary,
    SchedulerQueueStatus.failed => cs.error,
    SchedulerQueueStatus.draft => cs.outline,
  };
}
