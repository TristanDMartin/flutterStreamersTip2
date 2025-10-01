import 'package:flutter/material.dart';
import 'draft_thumbnail_view.dart';

/// DraftsSheetView - Sheet view for managing drafts
/// 
/// Features:
/// - Lists all user drafts
/// - Shows creation time
/// - Allows editing and deletion
/// - Matches iOS design specifications
class DraftsSheetView extends StatelessWidget {
  final List<Map<String, dynamic>> drafts;
  final Function(Map<String, dynamic>) onDelete;
  final Function(Map<String, dynamic>) onEdit;

  const DraftsSheetView({
    super.key,
    required this.drafts,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Drafts',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: drafts.isEmpty
          ? _buildEmptyState()
          : _buildDraftsList(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_outlined,
            size: 80,
            color: Colors.white54,
          ),
          SizedBox(height: 16),
          Text(
            'No Drafts Yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your saved drafts will appear here',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftsList() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView.builder(
        itemCount: drafts.length,
        itemBuilder: (context, index) {
          return _buildDraftItem(drafts[index]);
        },
      ),
    );
  }

  Widget _buildDraftItem(Map<String, dynamic> draft) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: () => onEdit(draft),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey[700]!,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Draft thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: DraftThumbnailView(
                  videoUrl: draft['videoPath'] ?? draft['videoUrl'] ?? '',
                  width: 100,
                  height: 140,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Draft info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Caption
                    Text(
                      draft['caption']?.isNotEmpty == true 
                          ? draft['caption'] 
                          : 'Untitled Draft',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Creation time
                    Text(
                      _formatTimeAgo(draft['createdAt']),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Hashtags
                    if (draft['hashtags'] != null && 
                        (draft['hashtags'] as List).isNotEmpty)
                      Text(
                        (draft['hashtags'] as List).join(' '),
                        style: const TextStyle(
                          color: Color(0xFF9248D2),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              
              // Delete button
              IconButton(
                onPressed: () => onDelete(draft),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(String? dateString) {
    if (dateString == null) return 'Unknown';
    
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}