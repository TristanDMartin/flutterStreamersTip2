import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/support_shell_style.dart';
import '../../../utils/sensitive_data_redactor.dart';
import '../models/admin_overview_metric.dart';
import 'admin_user_detail_view.dart';
import 'admin_video_detail_view.dart';

class AdminOverviewDetailView extends StatelessWidget {
  const AdminOverviewDetailView({
    super.key,
    required this.metric,
    this.summaryCount,
  });

  final AdminOverviewMetric metric;
  final int? summaryCount;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Scaffold(
      backgroundColor: shell.scaffold,
      appBar: AppBar(
        title: Text(metric.title),
        backgroundColor: shell.scaffold,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryHeader(
            shell: shell,
            metric: metric,
            summaryCount: summaryCount,
          ),
          Expanded(child: _OverviewDetailBody(metric: metric, shell: shell)),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.shell,
    required this.metric,
    this.summaryCount,
  });

  final StSupportShellStyle shell;
  final AdminOverviewMetric metric;
  final int? summaryCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: shell.heroGradient),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: shell.heroBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summaryCount != null)
            Text(
              '$summaryCount',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: shell.onChrome,
                  ),
            ),
          const SizedBox(height: 4),
          Text(
            metric.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: shell.muted,
                ),
          ),
        ],
      ),
    );
  }
}

class _OverviewDetailBody extends StatelessWidget {
  const _OverviewDetailBody({
    required this.metric,
    required this.shell,
  });

  final AdminOverviewMetric metric;
  final StSupportShellStyle shell;

  @override
  Widget build(BuildContext context) {
    switch (metric) {
      case AdminOverviewMetric.openReports:
        return _OpenReportsList(shell: shell);
      case AdminOverviewMetric.flaggedVideos:
        return _AdminVideoQueryList(
          shell: shell,
          query: FirebaseFirestore.instance
              .collection('videos')
              .where('moderationStatus', isEqualTo: 'flagged')
              .limit(60),
          emptyLabel: 'No flagged videos.',
        );
      case AdminOverviewMetric.failedUploads:
        return _AdminVideoQueryList(
          shell: shell,
          query: FirebaseFirestore.instance
              .collection('videos')
              .where('status', isEqualTo: 'failed')
              .limit(60),
          emptyLabel: 'No failed uploads.',
        );
      case AdminOverviewMetric.processingVideos:
        return _AdminVideoQueryList(
          shell: shell,
          query: FirebaseFirestore.instance
              .collection('videos')
              .where('status', isEqualTo: 'processing')
              .limit(60),
          emptyLabel: 'No processing videos.',
        );
      case AdminOverviewMetric.totalUploads:
        return _AdminVideoQueryList(
          shell: shell,
          query: FirebaseFirestore.instance
              .collection('videos')
              .orderBy('updatedAt', descending: true)
              .limit(60),
          emptyLabel: 'No videos in catalog.',
          showStatusBreakdown: true,
        );
      case AdminOverviewMetric.bannedUsers:
        return _BannedUsersList(shell: shell);
      case AdminOverviewMetric.newUsersToday:
        return _NewUsersTodayList(shell: shell);
    }
  }
}

class _OpenReportsList extends StatelessWidget {
  const _OpenReportsList({required this.shell});

  final StSupportShellStyle shell;

  static String _targetType(Map<String, dynamic> d) =>
      (d['targetType'] ?? d['reportType'] ?? 'unknown').toString();

  static String _targetId(Map<String, dynamic> d) =>
      (d['targetId'] ?? d['videoId'] ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('reports')
        .where('status', isEqualTo: 'open')
        .limit(60);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorState(message: 'Reports: ${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snap.data!.docs;
        if (docs.isEmpty) {
          return _EmptyState(label: 'No open reports.');
        }
        final Map<String, int> byType = <String, int>{};
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
          final String type = _targetType(doc.data());
          byType[type] = (byType[type] ?? 0) + 1;
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            _BreakdownChips(
              shell: shell,
              entries: byType.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)),
            ),
            const SizedBox(height: 8),
            ...docs.map((doc) {
              final Map<String, dynamic> d = doc.data();
              final Timestamp? ts =
                  d['timestamp'] as Timestamp? ?? d['createdAt'] as Timestamp?;
              final String time =
                  ts != null ? ts.toDate().toIso8601String() : '—';
              final String targetId = _targetId(d);
              return Card(
                color: shell.surfaceCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: shell.surfaceCardBorder),
                ),
                child: ListTile(
                  title: Text(
                    '${_targetType(d)} · open',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: shell.onChrome,
                    ),
                  ),
                  subtitle: Text(
                    'Reason: ${d['reason'] ?? '—'}\nWhen: $time',
                    style: TextStyle(color: shell.muted),
                  ),
                  isThreeLine: true,
                  trailing: targetId.isNotEmpty &&
                          _targetType(d).toLowerCase().contains('video')
                      ? const Icon(Icons.chevron_right)
                      : null,
                  onTap: targetId.isNotEmpty &&
                          _targetType(d).toLowerCase().contains('video')
                      ? () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  AdminVideoDetailView(videoId: targetId),
                            ),
                          );
                        }
                      : null,
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _BannedUsersList extends StatelessWidget {
  const _BannedUsersList({required this.shell});

  final StSupportShellStyle shell;

  @override
  Widget build(BuildContext context) {
    final Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('users')
        .where('accountStatus', isEqualTo: 'banned')
        .limit(60);
    return _AdminUserQueryList(
      shell: shell,
      query: q,
      emptyLabel: 'No banned users.',
    );
  }
}

class _NewUsersTodayList extends StatelessWidget {
  const _NewUsersTodayList({required this.shell});

  final StSupportShellStyle shell;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month, now.day);
    final Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('users')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .orderBy('createdAt', descending: true)
        .limit(60);
    return _AdminUserQueryList(
      shell: shell,
      query: q,
      emptyLabel: 'No new users today.',
    );
  }
}

class _AdminUserQueryList extends StatelessWidget {
  const _AdminUserQueryList({
    required this.shell,
    required this.query,
    required this.emptyLabel,
  });

  final StSupportShellStyle shell;
  final Query<Map<String, dynamic>> query;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorState(message: 'Users: ${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snap.data!.docs;
        if (docs.isEmpty) {
          return _EmptyState(label: emptyLabel);
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final QueryDocumentSnapshot<Map<String, dynamic>> doc = docs[i];
            final Map<String, dynamic> d = doc.data();
            final String username = (d['username'] ?? doc.id).toString();
            final String email = (d['email'] ?? '—').toString();
            final String tier = (d['subscriptionTier'] ?? '—').toString();
            final String status = (d['accountStatus'] ?? 'active').toString();
            final Timestamp? created =
                d['createdAt'] as Timestamp? ?? d['joinedAt'] as Timestamp?;
            final String joined = created != null
                ? created.toDate().toIso8601String()
                : '—';
            return Card(
              color: shell.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: shell.surfaceCardBorder),
              ),
              child: ListTile(
                title: Text(
                  username,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: shell.onChrome,
                  ),
                ),
                subtitle: Text(
                  '$email · $tier · $status\nJoined: $joined',
                  style: TextStyle(color: shell.muted),
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AdminUserDetailView(userId: doc.id),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _AdminVideoQueryList extends StatelessWidget {
  const _AdminVideoQueryList({
    required this.shell,
    required this.query,
    required this.emptyLabel,
    this.showStatusBreakdown = false,
  });

  final StSupportShellStyle shell;
  final Query<Map<String, dynamic>> query;
  final String emptyLabel;
  final bool showStatusBreakdown;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorState(message: 'Videos: ${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snap.data!.docs;
        if (docs.isEmpty) {
          return _EmptyState(label: emptyLabel);
        }
        final List<Widget> header = <Widget>[];
        if (showStatusBreakdown) {
          final Map<String, int> byStatus = <String, int>{};
          for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
            final String st = (doc.data()['status'] ?? 'unknown').toString();
            byStatus[st] = (byStatus[st] ?? 0) + 1;
          }
          header.addAll(<Widget>[
            _BreakdownChips(
              shell: shell,
              entries: byStatus.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)),
            ),
            const SizedBox(height: 8),
          ]);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            ...header,
            ...docs.map((doc) {
              final Map<String, dynamic> d = doc.data();
              final String thumb =
                  (d['thumbnailUrl'] ?? d['thumbnail_url'] ?? '').toString();
              final String rawCap = (d['caption'] ?? '').toString();
              final String cap = rawCap.length > 80
                  ? '${rawCap.substring(0, 80)}…'
                  : rawCap;
              final String st = (d['status'] ?? '').toString();
              final String mod = (d['moderationStatus'] ?? '').toString();
              final String creator =
                  SensitiveDataRedactor.maskId((d['creatorId'] ?? '').toString());
              return Card(
                color: shell.surfaceCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: shell.surfaceCardBorder),
                ),
                child: ListTile(
                  leading: thumb.isEmpty
                      ? Icon(Icons.movie, color: shell.muted)
                      : SizedBox(
                          width: 48,
                          height: 64,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(
                              imageUrl: thumb,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  Icon(Icons.movie, color: shell.muted),
                            ),
                          ),
                        ),
                  title: Text(
                    '$st · ${doc.id}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: shell.onChrome,
                    ),
                  ),
                  subtitle: Text(
                    '$cap\nModeration: $mod · Creator: $creator',
                    style: TextStyle(color: shell.muted),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => AdminVideoDetailView(videoId: doc.id),
                      ),
                    );
                  },
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _BreakdownChips extends StatelessWidget {
  const _BreakdownChips({
    required this.shell,
    required this.entries,
  });

  final StSupportShellStyle shell;
  final List<MapEntry<String, int>> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries
          .map(
            (MapEntry<String, int> e) => Chip(
              label: Text('${e.key} (${e.value})'),
              backgroundColor: shell.chipUnselectedBg,
              side: BorderSide(color: shell.chipUnselectedBorder),
              labelStyle: TextStyle(color: shell.chipUnselectedFg),
            ),
          )
          .toList(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          label,
          style: TextStyle(color: shell.muted),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SelectableText.rich(
          TextSpan(
            text: message,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }
}
