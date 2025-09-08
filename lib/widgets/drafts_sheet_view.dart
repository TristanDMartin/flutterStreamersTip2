import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/video.dart';
import 'share_draft_sheet_view.dart';

enum DraftSheetAction { delete, edit }

class DraftsSheetView extends HookConsumerWidget {
  final List<Video> drafts;
  final Function(Video) onDelete;
  final Function(Video) onEdit;

  const DraftsSheetView({
    super.key,
    required this.drafts,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDrafts = useState<Set<String>>({});

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          'Drafts (${drafts.length})',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (selectedDrafts.value.isNotEmpty)
            TextButton(
              onPressed: () {
                _showDeleteConfirmation(context, selectedDrafts.value);
              },
              child: Text(
                'Delete (${selectedDrafts.value.length})',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: drafts.isEmpty
          ? _buildEmptyState()
          : _buildDraftsList(selectedDrafts),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No drafts yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start recording to create your first draft',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftsList(ValueNotifier<Set<String>> selectedDrafts) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: drafts.length,
      itemBuilder: (context, index) {
        final draft = drafts[index];
        final isSelected = selectedDrafts.value.contains(draft.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: const Color(0xFF9248d2), width: 2)
                : null,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: _buildDraftThumbnail(draft),
            title: Text(
              _formatDraftTitle(draft),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              _formatDraftSubtitle(draft),
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.share, color: Color(0xFF9248d2)),
                  onPressed: () => _showShareSheet(context, draft),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () => onEdit(draft),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteConfirmation(context, {draft.id}),
                ),
              ],
            ),
            onTap: () {
              final newSelection = Set<String>.from(selectedDrafts.value);
              if (isSelected) {
                newSelection.remove(draft.id);
              } else {
                newSelection.add(draft.id);
              }
              selectedDrafts.value = newSelection;
            },
          ),
        );
      },
    );
  }

  Widget _buildDraftThumbnail(Video draft) {
    return Container(
      width: 60,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[800],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: draft.videoURL.isNotEmpty
            ? Image.network(
                draft.videoURL,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.video_library,
                    color: Colors.grey,
                    size: 24,
                  );
                },
              )
            : const Icon(
                Icons.video_library,
                color: Colors.grey,
                size: 24,
              ),
      ),
    );
  }

  String _formatDraftTitle(Video draft) {
    if (draft.creator.displayName.isNotEmpty) {
      return draft.creator.displayName;
    }
    return 'Untitled Draft';
  }

  String _formatDraftSubtitle(Video draft) {
    final duration = _formatDuration(30); // Default duration
    final size = _formatFileSize(1024000); // Default size
    return '$duration • $size';
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  void _showShareSheet(BuildContext context, Video draft) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ShareDraftSheetView(
          draft: draft,
          onDismiss: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Set<String> draftIds) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Drafts',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete ${draftIds.length} draft${draftIds.length > 1 ? 's' : ''}? This action cannot be undone.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              for (final draftId in draftIds) {
                final draft = drafts.firstWhere((d) => d.id == draftId);
                onDelete(draft);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
