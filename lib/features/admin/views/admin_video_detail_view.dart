import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../utils/user_facing_error.dart';
import '../admin_backend_service.dart';
import '../widgets/admin_action_confirm_sheet.dart';

class AdminVideoDetailView extends StatelessWidget {
  const AdminVideoDetailView({super.key, required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Video $videoId')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('videos')
            .doc(videoId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Video not found.'));
          }
          final d = snap.data!.data()!;
          final thumb =
              (d['thumbnailUrl'] ?? d['thumbnail_url'] ?? '').toString();
          final cap = (d['caption'] ?? '').toString();
          final st = (d['status'] ?? '').toString();
          final vis = (d['visibility'] ?? '').toString();
          final mod = (d['moderationStatus'] ?? '').toString();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (thumb.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: CachedNetworkImage(
                        imageUrl: thumb,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Status: $st · visibility: $vis · moderation: $mod',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(cap),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () async {
                    final reason = await showAdminRemoveVideoSheet(context);
                    if (reason == null || !context.mounted) {
                      return;
                    }
                    try {
                      await AdminBackendService.execute(
                        'removeVideo',
                        {'videoId': videoId, 'reason': reason},
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
                  child: const Text('Remove video (soft)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await AdminBackendService.execute(
                        'restoreVideo',
                        {'videoId': videoId},
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
                  child: const Text('Restore video'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
