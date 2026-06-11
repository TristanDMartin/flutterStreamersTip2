import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Reads `admin_logs` (Firestore `isUserAdmin()` rules).
class AdminAuditLogView extends StatelessWidget {
  const AdminAuditLogView({super.key});

  static String _errorMessage(Object err) {
    final String haystack = err.toString().toLowerCase();
    if (haystack.contains('permission-denied')) {
      return 'Audit log access denied by Firestore rules. '
          'Tap the key icon in the app bar to refresh your admin session, '
          'then reopen this tab.\n\n$err';
    }
    return 'Audit log error: $err';
  }

  @override
  Widget build(BuildContext context) {
    final Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('admin_logs')
        .orderBy('timestamp', descending: true)
        .limit(80);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: SelectableText.rich(
              TextSpan(
                text: _errorMessage(snap.error!),
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
          return const Center(child: Text('No audit entries yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final d = docs[i].data();
            final ts =
                d['timestamp'] as Timestamp? ?? d['createdAt'] as Timestamp?;
            final String time =
                ts != null ? ts.toDate().toIso8601String() : '—';
            return ListTile(
              dense: true,
              title: Text(
                '${d['action'] ?? 'action'} → ${d['targetType'] ?? '?'} '
                '${d['targetId'] ?? ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '$time\n${d['adminUsername'] ?? d['adminUid'] ?? ''}',
                maxLines: 3,
              ),
            );
          },
        );
      },
    );
  }
}
