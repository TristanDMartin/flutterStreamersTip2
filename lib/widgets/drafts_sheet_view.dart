import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/local_draft_service.dart';
import '../services/draft_thumbnail_service.dart';
import '../models/home_video.dart';
import '../models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'optimized_thumbnail.dart';
import 'video_publishing_screen.dart';
import 'choose_person_view.dart';

class DraftsSheetView extends StatefulWidget {
  final List<Map<String, dynamic>> drafts;
  final Function(Map<String, dynamic>) onDraftTap;
  final Future<bool> Function(Map<String, dynamic>) onDelete;

  const DraftsSheetView({
    super.key,
    required this.drafts,
    required this.onDraftTap,
    required this.onDelete,
  });

  @override
  State<DraftsSheetView> createState() => _DraftsSheetViewState();
}

class _DraftsSheetViewState extends State<DraftsSheetView> {
  List<Map<String, dynamic>> _drafts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    setState(() => _isLoading = true);
    try {
      final drafts = await LocalDraftService().getAllDrafts();
      setState(() {
        _drafts = drafts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading drafts: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDeleteDraft(Map<String, dynamic> draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Delete Draft',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete this draft?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.onDelete(draft);
      await _loadDrafts();
      if (mounted && _drafts.isEmpty) {
        // If no drafts left, pop back to profile
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _handleEditDraft(Map<String, dynamic> draft) async {
    try {
      final videoFile = File(draft['videoPath']);
      if (!videoFile.existsSync()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video file not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final hashtags = (draft['hashtags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VideoPublishingScreen(
              videoFile: videoFile,
              caption: draft['caption'] ?? '',
              hashtags: hashtags,
              onPublish: () async {
                // Delete draft after successful publish
                await LocalDraftService().deleteDraft(draft['id']);
                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              onCancel: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error editing draft: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening draft: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Drafts',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF9248D2),
              ),
            )
          : _drafts.isEmpty
              ? _buildEmptyState()
              : _buildDraftsGrid(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.drafts_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Drafts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your draft videos will appear here',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 9 / 16,
      ),
      itemCount: _drafts.length,
      itemBuilder: (context, index) {
        final draft = _drafts[index];
        return _buildDraftCard(draft);
      },
    );
  }

  Future<void> _handleShareDraft(Map<String, dynamic> draft) async {
    try {
      HapticFeedback.lightImpact();
      
      // Navigate to connection selection view
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChoosePersonView(selectedDraft: draft),
        ),
      );

      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft shared successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error sharing draft: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing draft: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDraftCard(Map<String, dynamic> draft) {
    final videoPath = draft['videoPath'] as String?;
    final thumbnailPath = draft['thumbnailPath'] as String?;
    final draftId = draft['id'] ?? 'draft';

    debugPrint('🎬 DraftCard: Building draft $draftId');
    debugPrint('  - videoPath: $videoPath');
    debugPrint('  - thumbnailPath: $thumbnailPath');

    // Check if thumbnail exists, if not generate it
    final hasThumbnail = thumbnailPath != null && 
        thumbnailPath.isNotEmpty && 
        File(thumbnailPath).existsSync();

    final draftVideo = HomeVideo(
      id: draftId,
      videoURL: videoPath ?? '',
      thumbnailURL: hasThumbnail ? thumbnailPath : null,
      creator: User(
        id: 'current_user',
        displayName: 'You',
        username: 'you',
        bio: 'Your draft video',
        avatarURL: '',
      ),
      caption: draft['caption'] ?? 'Draft',
      categoryId: 'draft',
      views: 0,
      likes: 0,
      comments: 0,
      isDraft: true,
      createdAt: Timestamp.fromDate(
        DateTime.tryParse(draft['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      ),
    );

    return Stack(
      children: [
        // Generate thumbnail if missing
        if (!hasThumbnail && videoPath != null)
          FutureBuilder<String?>(
            future: _generateThumbnailIfMissing(draftId, videoPath),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingThumbnail();
              }
              if (snapshot.hasData && snapshot.data != null) {
                final updatedVideo = HomeVideo(
                  id: draftVideo.id,
                  videoURL: draftVideo.videoURL,
                  thumbnailURL: snapshot.data,
                  creator: draftVideo.creator,
                  caption: draftVideo.caption,
                  categoryId: draftVideo.categoryId,
                  views: draftVideo.views,
                  likes: draftVideo.likes,
                  comments: draftVideo.comments,
                  isDraft: draftVideo.isDraft,
                  createdAt: draftVideo.createdAt,
                );
                return GestureDetector(
                  onTap: () => _handleEditDraft(draft),
                  child: GridThumbnail(
                    video: updatedVideo,
                    onTap: () => _handleEditDraft(draft),
                    showDraftBadge: true,
                    showDurationBadge: false,
                  ),
                );
              }
              return GestureDetector(
                onTap: () => _handleEditDraft(draft),
                child: GridThumbnail(
                  video: draftVideo,
                  onTap: () => _handleEditDraft(draft),
                  showDraftBadge: true,
                  showDurationBadge: false,
                ),
              );
            },
          )
        else
          GestureDetector(
            onTap: () => _handleEditDraft(draft),
            child: GridThumbnail(
              video: draftVideo,
              onTap: () => _handleEditDraft(draft),
              showDraftBadge: true,
              showDurationBadge: false,
            ),
          ),
        // Share button
        Positioned(
          top: 8,
          left: 8,
          child: GestureDetector(
            onTap: () => _handleShareDraft(draft),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.share_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
        // Delete button
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () => _handleDeleteDraft(draft),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<String?> _generateThumbnailIfMissing(String draftId, String videoPath) async {
    try {
      debugPrint('🖼️ Generating missing thumbnail for draft: $draftId');
      final draftThumbnailService = DraftThumbnailService();
      final thumbnailPath = await draftThumbnailService.generateLocalThumbnail(
        videoPath: videoPath,
        videoId: draftId,
      );
      
      if (thumbnailPath != null) {
        // Update the draft with the new thumbnail path
        final localDraftService = LocalDraftService();
        final allDrafts = await localDraftService.getAllDrafts();
        final draft = allDrafts.firstWhere(
          (d) => d['id'] == draftId,
          orElse: () => <String, dynamic>{},
        );
        
        if (draft.isNotEmpty) {
          draft['thumbnailPath'] = thumbnailPath;
          // Save updated draft using LocalDraftService
          final localDraftService = LocalDraftService();
          // Reload and update all drafts
          final allDrafts = await localDraftService.getAllDrafts();
          final updatedDrafts = allDrafts.map((d) {
            if (d['id'] == draftId) {
              return draft;
            }
            return d;
          }).toList();
          // Save back using the service's internal method
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('draftVideos', json.encode(updatedDrafts));
        }
        
        debugPrint('✅ Generated thumbnail: $thumbnailPath');
        return thumbnailPath;
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error generating thumbnail: $e');
      return null;
    }
  }

  Widget _buildLoadingThumbnail() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.white54,
          strokeWidth: 2,
        ),
      ),
    );
  }
}

