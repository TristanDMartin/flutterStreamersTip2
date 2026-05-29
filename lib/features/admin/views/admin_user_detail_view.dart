import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../utils/sensitive_data_redactor.dart';
import '../../../utils/user_facing_error.dart';
import '../admin_backend_service.dart';
import '../widgets/admin_action_confirm_sheet.dart';
import 'admin_video_detail_view.dart';

class AdminUserDetailView extends StatelessWidget {
  const AdminUserDetailView({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User ${SensitiveDataRedactor.maskId(userId)}'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('User not found.'));
          }
          final d = snap.data!.data()!;
          final un = (d['username'] ?? '').toString();
          final em = (d['email'] ?? '—').toString();
          final tier =
              (d['subscriptionTier'] ?? '—').toString();
          final role = (d['role'] ?? '—').toString();
          final ac =
              (d['accountStatus'] ?? 'active').toString();
          final created =
              (d['createdAt'] ?? d['joinedAt'])?.toString() ?? '—';
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(un,
                    style:
                        Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            )),
                const SizedBox(height: 8),
                Text('Email: $em'),
                Text('UID: ${SensitiveDataRedactor.maskId(userId)}'),
                Text('Tier: $tier'),
                Text('Role: $role'),
                Text('Account status: $ac'),
                Text('Created: $created'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final r = await showAdminTextConfirmSheet(
                      context,
                      title: 'Ban this user?',
                      body: 'Blocks uploads, comments, messaging, threads, '
                          'discover surfaces until reversed.',
                      confirmLabel: 'Ban user',
                      reasonHint: 'Ban reason',
                    );
                    if (r == null || r.isEmpty || !context.mounted) {
                      return;
                    }
                    try {
                      await AdminBackendService.execute(
                        'banUser',
                        {'targetUid': userId, 'reason': r},
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(UserFacingError.message(e)),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Ban user'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await AdminBackendService.execute(
                        'unbanUser',
                        {'targetUid': userId},
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(UserFacingError.message(e)),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Unban user'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Moderation',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('videos')
                      .where('userId', isEqualTo: userId)
                      .limit(12)
                      .snapshots(),
                  builder: (context, vsnap) {
                    if (!vsnap.hasData) {
                      return const Text('Loading uploads…');
                    }
                    final docs = vsnap.data!.docs;
                    if (docs.isEmpty) {
                      return const Text('No videos found for userId.');
                    }
                    return Column(
                      children: docs.map((doc) {
                        return ListTile(
                          dense: true,
                          title: Text(
                            SensitiveDataRedactor.maskId(doc.id),
                          ),
                          subtitle: Text(
                            (doc.data()['status'] ?? '').toString(),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    AdminVideoDetailView(videoId: doc.id),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
