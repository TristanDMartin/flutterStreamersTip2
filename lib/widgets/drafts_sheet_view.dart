import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
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
  String? _busyDraftId;

  @override
  void initState() {
    super.initState();
    _drafts = List<Map<String, dynamic>>.from(widget.drafts);
    _loadDrafts();
  }

  @override
  void didUpdateWidget(covariant DraftsSheetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.drafts != oldWidget.drafts && !_isLoading) {
      _drafts = List<Map<String, dynamic>>.from(widget.drafts);
    }
  }

  Future<void> _loadDrafts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final drafts = await LocalDraftService().getAllDrafts();
      if (!mounted) return;
      setState(() {
        _drafts = drafts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading drafts: $e');
      if (!mounted) return;
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
      final draftId = draft['id']?.toString();
      setState(() => _busyDraftId = draftId);
      try {
        await widget.onDelete(draft);
        await _loadDrafts();
        if (mounted && _drafts.isEmpty) {
          Navigator.of(context).pop();
        }
      } finally {
        if (mounted) {
          setState(() => _busyDraftId = null);
        }
      }
    }
  }

  Future<void> _handleEditDraft(Map<String, dynamic> draft) async {
    try {
      final navigator = Navigator.of(context);
      final localDraftService = LocalDraftService();
      final draftId = draft['id'] as String?;
      if (draftId == null || draftId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Draft is missing its ID'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() => _busyDraftId = draftId);
      }
      final videoFile = await localDraftService.ensureLocalVideoFile(draftId);
      if (mounted) {
        setState(() => _busyDraftId = null);
      }
      if (videoFile == null || !videoFile.existsSync()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Draft video is not available on this device yet'),
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
        navigator.push(
          MaterialPageRoute(
            builder: (context) => VideoPublishingScreen(
              videoFile: videoFile,
              caption: draft['caption'] ?? '',
              hashtags: hashtags,
              draftId: draftId,
              draftData: draft,
              onPublish: () async {
                // Delete draft after successful publish
                await LocalDraftService().deleteDraft(draft['id']);
                if (mounted) {
                  navigator.popUntil((route) => route.isFirst);
                }
              },
              onCancel: () {
                navigator.pop();
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error editing draft: $e');
      if (mounted) {
        setState(() => _busyDraftId = null);
      }
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
      backgroundColor: const Color(0xFF090312),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090312),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF170726),
              Color(0xFF090312),
              Color(0xFF040106),
            ],
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF9248D2),
                ),
              )
            : _drafts.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    color: const Color(0xFF9248D2),
                    backgroundColor: const Color(0xFF16101F),
                    onRefresh: _loadDrafts,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _buildOverviewHeader()),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: _buildDraftsGrid(),
                        ),
                      ],
                    ),
                  ),
      ),
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
            'Your saved edits, captions, and upload prep will appear here',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewHeader() {
    final count = _drafts.length;
    final latestCreatedAt = _drafts
        .map((draft) => DateTime.tryParse(draft['createdAt']?.toString() ?? ''))
        .whereType<DateTime>()
        .fold<DateTime?>(null, (latest, value) {
      if (latest == null || value.isAfter(latest)) return value;
      return latest;
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xCC8F48FF),
              Color(0xCC2E8DFF),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8F48FF).withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count draft${count == 1 ? '' : 's'} ready',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              latestCreatedAt == null
                  ? 'Pick up where you left off, or share a draft for feedback before publishing.'
                  : 'Last updated ${_formatRelativeTime(latestCreatedAt)}. Tap any draft to keep editing or post it.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftsGrid() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 9 / 16,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final draft = _drafts[index];
        return _buildDraftCard(draft);
      }, childCount: _drafts.length),
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
    final videoSource = (draft['videoPath'] as String?)?.isNotEmpty == true
        ? draft['videoPath'] as String
        : (draft['videoUrl'] as String?) ?? '';
    final thumbnailSource =
        (draft['thumbnailPath'] as String?)?.isNotEmpty == true
            ? draft['thumbnailPath'] as String
            : (draft['thumbnailUrl'] as String?) ?? '';
    final draftId = draft['id'] ?? 'draft';
    final isBusy = _busyDraftId == draftId;
    final createdAt = DateTime.tryParse(draft['createdAt']?.toString() ?? '');
    final caption = (draft['caption'] as String?)?.trim() ?? '';
    final statusChips = _buildDraftStatusChips(draft);

    debugPrint('🎬 DraftCard: Building draft $draftId');
    debugPrint('  - videoSource: $videoSource');
    debugPrint('  - thumbnailSource: $thumbnailSource');

    // Check if thumbnail exists, if not generate it
    final hasLocalThumbnail =
        (draft['thumbnailPath'] as String?)?.isNotEmpty == true &&
            File(draft['thumbnailPath'] as String).existsSync();
    final hasThumbnail = hasLocalThumbnail || thumbnailSource.isNotEmpty;

    final draftVideo = HomeVideo(
      id: draftId,
      videoURL: videoSource,
      thumbnailURL: hasThumbnail ? thumbnailSource : null,
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
        if (!hasThumbnail &&
            (draft['videoPath'] as String?)?.isNotEmpty == true)
          FutureBuilder<String?>(
            future: _generateThumbnailIfMissing(
              draftId,
              draft['videoPath'] as String,
            ),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: GridThumbnail(
                video: draftVideo,
                onTap: () => _handleEditDraft(draft),
                showDraftBadge: true,
                showDurationBadge: false,
              ),
            ),
          ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  caption.isEmpty ? 'Untitled draft' : caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Saved ${_formatRelativeTime(createdAt)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 11,
                    ),
                  ),
                ],
                if (statusChips.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: statusChips,
                  ),
                ],
              ],
            ),
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
                color: Colors.black.withValues(alpha: 0.72),
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
                color: Colors.black.withValues(alpha: 0.72),
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
        if (isBusy)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }

  List<Widget> _buildDraftStatusChips(Map<String, dynamic> draft) {
    final metadata = draft['metadata'] is Map
        ? Map<String, dynamic>.from(draft['metadata'] as Map)
        : const <String, dynamic>{};
    final chips = <Widget>[];

    final scheduledAtRaw = metadata['scheduled_at_utc']?.toString();
    final scheduledAt =
        scheduledAtRaw == null ? null : DateTime.tryParse(scheduledAtRaw);
    if (scheduledAt != null) {
      chips.add(
        _buildStatusChip(
          label: 'Scheduled',
          icon: Icons.schedule_rounded,
          color: const Color(0xFFFFB454),
        ),
      );
    } else {
      chips.add(
        _buildStatusChip(
          label: 'Ready',
          icon: Icons.check_circle_outline_rounded,
          color: const Color(0xFF59D890),
        ),
      );
    }

    final crossPlatforms =
        (metadata['cross_platform_sharing'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList() ??
            const <String>[];
    if (crossPlatforms.isNotEmpty) {
      chips.add(
        _buildStatusChip(
          label: crossPlatforms.length == 1
              ? 'Cross-posting'
              : '${crossPlatforms.length} destinations',
          icon: Icons.share_rounded,
          color: const Color(0xFF62B7FF),
        ),
      );
    }

    final category = (draft['category'] as String?)?.trim();
    if (category != null && category.isNotEmpty && category != 'general') {
      chips.add(
        _buildStatusChip(
          label: _formatCategoryLabel(category),
          icon: Icons.sell_outlined,
          color: const Color(0xFFC895FF),
        ),
      );
    }

    return chips;
  }

  Widget _buildStatusChip({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 104),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: color.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCategoryLabel(String raw) {
    return raw
        .split(RegExp(r'[-_]'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Future<String?> _generateThumbnailIfMissing(
      String draftId, String videoPath) async {
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
          await localDraftService.updateDraftFields(
            draftId,
            {'thumbnailPath': thumbnailPath},
          );
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
