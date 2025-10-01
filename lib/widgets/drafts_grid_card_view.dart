import 'package:flutter/material.dart';
import 'draft_thumbnail_view.dart';

/// DraftsGridCardView - Displays a grid card for drafts in ProfileView
/// 
/// Features:
/// - Shows draft count badge
/// - Displays thumbnail of first draft
/// - Handles tap to open drafts sheet
/// - Matches iOS design specifications
class DraftsGridCardView extends StatelessWidget {
  final List<Map<String, dynamic>> drafts;
  final VoidCallback onTap;

  const DraftsGridCardView({
    super.key,
    required this.drafts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (drafts.isEmpty) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        height: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Colors.grey[900],
        ),
        child: Stack(
          children: [
            // Draft thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: DraftThumbnailView(
                videoUrl: _getFirstDraftVideoUrl(),
                width: 110,
                height: 170,
              ),
            ),
            
            // Drafts count badge (bottom trailing)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Drafts: ${drafts.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFirstDraftVideoUrl() {
    if (drafts.isNotEmpty) {
      return drafts.first['videoPath'] ?? drafts.first['videoUrl'] ?? '';
    }
    return '';
  }
}