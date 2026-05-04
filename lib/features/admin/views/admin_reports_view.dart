import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../admin_backend_service.dart';
import '../widgets/admin_action_confirm_sheet.dart';
import 'admin_video_detail_view.dart';

class AdminReportsView extends StatelessWidget {
  const AdminReportsView({super.key});

  static String _reporterId(Map<String, dynamic> d) =>
      (d['reporterUserId'] ?? d['reporterId'] ?? '').toString();

  static String _reportedUserId(Map<String, dynamic> d) =>
      (d['reportedUserId'] ?? d['creatorId'] ?? '').toString();

  static String _targetType(Map<String, dynamic> d) =>
      (d['targetType'] ?? d['reportType'] ?? 'unknown').toString();

  static String _targetId(Map<String, dynamic> d) =>
      (d['targetId'] ?? d['videoId'] ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('reports')
        .orderBy('timestamp', descending: true)
        .limit(60);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: SelectableText.rich(
              TextSpan(
                text: 'Reports error: ${snap.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No reports.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final d = doc.data();
            final status = (d['status'] ?? 'open').toString();
            final ts = d['timestamp'] as Timestamp? ??
                d['createdAt'] as Timestamp?;
            final String time =
                ts != null ? ts.toDate().toIso8601String() : '—';
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_targetType(d)} · $status',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text('Reason: ${d['reason'] ?? '—'}'),
                    Text('Reporter: ${_reporterId(d)}'),
                    Text('Reported user: ${_reportedUserId(d)}'),
                    Text('Target id: ${_targetId(d)}'),
                    Text('When: $time'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: () async {
                            final reason = await showAdminTextConfirmSheet(
                              context,
                              title: 'Dismiss report?',
                              body: 'Marks this report dismissed.',
                              confirmLabel: 'Dismiss',
                              reasonHint: 'Reason',
                            );
                            if (reason == null || !context.mounted) {
                              return;
                            }
                            try {
                              await AdminBackendService.execute(
                                'dismissReport',
                                {'reportId': doc.id, 'reason': reason},
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            }
                          },
                          child: const Text('Dismiss'),
                        ),
                        TextButton(
                          onPressed: () async {
                            final reason = await showAdminTextConfirmSheet(
                              context,
                              title: 'Resolve report?',
                              body: 'Marks reviewed and resolved.',
                              confirmLabel: 'Resolve',
                              reasonHint: 'Notes',
                            );
                            if (reason == null || !context.mounted) {
                              return;
                            }
                            try {
                              await AdminBackendService.execute(
                                'resolveReport',
                                {
                                  'reportId': doc.id,
                                  'reason': reason,
                                  'actionTaken': 'resolved',
                                },
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            }
                          },
                          child: const Text('Resolve'),
                        ),
                        if (_targetId(d).isNotEmpty &&
                            _targetType(d).contains('video'))
                          TextButton(
                            onPressed: () {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => AdminVideoDetailView(
                                    videoId: _targetId(d),
                                  ),
                                ),
                              );
                            },
                            child: const Text('Video'),
                          ),
                        TextButton(
                          onPressed: () async {
                            final uid = _reportedUserId(d);
                            if (uid.isEmpty) {
                              return;
                            }
                            final r = await showAdminTextConfirmSheet(
                              context,
                              title: 'Ban this user?',
                              body: 'Blocks uploads, comments, messages, '
                                  'threads, and feeds for this account.',
                              confirmLabel: 'Ban user',
                              reasonHint: 'Ban reason',
                            );
                            if (r == null || r.isEmpty || !context.mounted) {
                              return;
                            }
                            try {
                              await AdminBackendService.execute(
                                'banUser',
                                {'targetUid': uid, 'reason': r},
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            }
                          },
                          child: const Text('Ban user'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
