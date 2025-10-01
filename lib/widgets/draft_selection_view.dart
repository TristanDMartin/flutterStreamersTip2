import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/local_draft_service.dart';
import 'draft_thumbnail_view.dart';
import 'choose_person_view.dart';

/// DraftSelectionView - Allows users to select a draft video to share with connections
/// 
/// Features:
/// - Lists all user's draft videos
/// - Shows draft thumbnails and captions
/// - Allows selection of draft to share
/// - Navigates to ChoosePersonView for recipient selection
class DraftSelectionView extends StatefulWidget {
  const DraftSelectionView({super.key});

  @override
  State<DraftSelectionView> createState() => _DraftSelectionViewState();
}

class _DraftSelectionViewState extends State<DraftSelectionView> {
  final LocalDraftService _draftService = LocalDraftService();
  List<Map<String, dynamic>> _drafts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final drafts = await _draftService.getAllDrafts();
      
      setState(() {
        _drafts = drafts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Select Draft',
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
        ),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_drafts.isEmpty) {
      return _buildEmptyState();
    }

    return _buildDraftsList();
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Error Loading Drafts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadDrafts,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9248D2),
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.drafts_outlined,
            size: 80,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Drafts Available',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create some draft videos first to share them with your connections',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDraftsList() {
    return RefreshIndicator(
      onRefresh: _loadDrafts,
      color: const Color(0xFF9248D2),
      backgroundColor: Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _drafts.length,
        itemBuilder: (context, index) {
          final draft = _drafts[index];
          return _buildDraftCard(draft, index);
        },
      ),
    );
  }

  Widget _buildDraftCard(Map<String, dynamic> draft, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _selectDraft(draft),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Draft thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: DraftThumbnailView(
                    videoUrl: draft['videoPath'] ?? draft['videoUrl'] ?? '',
                    width: 80,
                    height: 120,
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
                          color: Colors.white70,
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
                      
                      const SizedBox(height: 8),
                      
                      // Tap to select hint
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9248D2).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Tap to share',
                          style: TextStyle(
                            color: Color(0xFF9248D2),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Arrow icon
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white54,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectDraft(Map<String, dynamic> draft) {
    HapticFeedback.lightImpact();
    
    // Navigate to ChoosePersonView with the selected draft
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChoosePersonView(
          selectedDraft: draft,
        ),
        fullscreenDialog: true,
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
