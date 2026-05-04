import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_video_detail_view.dart';

enum _UploadFilter {
  newest,
  processing,
  ready,
  flagged,
  removed,
  failed,
}

class AdminUploadsView extends StatefulWidget {
  const AdminUploadsView({super.key});

  @override
  State<AdminUploadsView> createState() => _AdminUploadsViewState();
}

class _AdminUploadsViewState extends State<AdminUploadsView> {
  _UploadFilter _filter = _UploadFilter.newest;

  Query<Map<String, dynamic>> _query() {
    final CollectionReference<Map<String, dynamic>> col =
        FirebaseFirestore.instance.collection('videos');
    switch (_filter) {
      case _UploadFilter.newest:
        return col.orderBy('updatedAt', descending: true).limit(40);
      case _UploadFilter.processing:
        return col
            .where('status', isEqualTo: 'processing')
            .limit(40);
      case _UploadFilter.ready:
        return col.where('status', isEqualTo: 'ready').limit(40);
      case _UploadFilter.flagged:
        return col
            .where('moderationStatus', isEqualTo: 'flagged')
            .limit(40);
      case _UploadFilter.removed:
        return col.where('status', isEqualTo: 'removed').limit(40);
      case _UploadFilter.failed:
        return col.where('status', isEqualTo: 'failed').limit(40);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Filter',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_UploadFilter>(
                value: _filter,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: _UploadFilter.newest,
                    child: Text('Newest (by updatedAt)'),
                  ),
                  DropdownMenuItem(
                    value: _UploadFilter.processing,
                    child: Text('Processing'),
                  ),
                  DropdownMenuItem(
                    value: _UploadFilter.ready,
                    child: Text('Ready'),
                  ),
                  DropdownMenuItem(
                    value: _UploadFilter.flagged,
                    child: Text('Flagged'),
                  ),
                  DropdownMenuItem(
                    value: _UploadFilter.removed,
                    child: Text('Removed'),
                  ),
                  DropdownMenuItem(
                    value: _UploadFilter.failed,
                    child: Text('Failed'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _filter = v);
                  }
                },
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _query().snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: SelectableText.rich(
                    TextSpan(
                      text: 'Videos: ${snap.error}',
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
                return const Center(child: Text('No videos match.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final d = doc.data();
                  final thumb =
                      (d['thumbnailUrl'] ?? d['thumbnail_url'] ?? '')
                          .toString();
                  final rawCap = (d['caption'] ?? '').toString();
                  final cap = rawCap.length > 80
                      ? '${rawCap.substring(0, 80)}…'
                      : rawCap;
                  final st = (d['status'] ?? '').toString();
                  return Card(
                    child: ListTile(
                      leading: thumb.isEmpty
                          ? const Icon(Icons.movie)
                          : SizedBox(
                              width: 48,
                              height: 64,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: CachedNetworkImage(
                                  imageUrl: thumb,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.movie),
                                ),
                              ),
                            ),
                      title: Text('$st · ${doc.id}'),
                      subtitle: Text(cap),
                      onTap: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                AdminVideoDetailView(videoId: doc.id),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
