import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'dart:developer';
import '../../models/home_video.dart';
import '../../widgets/player_screen.dart';
import '../../constants/app_colors.dart';

/// RedNote-style grid feed for Following tab
/// 2-column masonry layout with video cards
class FollowingFeedGridWidget extends ConsumerStatefulWidget {
  final List<HomeVideo> videos;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final String? emptyMessage;
  final VoidCallback? onRefresh;
  final Function(HomeVideo, int)? onVideoTap;

  const FollowingFeedGridWidget({
    super.key,
    required this.videos,
    required this.isLoading,
    required this.hasError,
    this.errorMessage,
    this.emptyMessage,
    this.onRefresh,
    this.onVideoTap,
  });

  @override
  ConsumerState<FollowingFeedGridWidget> createState() =>
      _FollowingFeedGridWidgetState();
}

class _FollowingFeedGridWidgetState
    extends ConsumerState<FollowingFeedGridWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openVideoPlayer(HomeVideo video, int index) {
    log('🎬 FollowingFeedGrid: Opening video ${video.id} at index $index');
    
    // 🔥 DEDUPLICATE: Get unique videos list for player
    final uniqueVideos = <String, HomeVideo>{};
    final deduplicatedVideos = <HomeVideo>[];
    for (final v in widget.videos) {
      if (v.id.isNotEmpty && !uniqueVideos.containsKey(v.id)) {
        uniqueVideos[v.id] = v;
        deduplicatedVideos.add(v);
      }
    }
    
    // Find the correct index in deduplicated list
    final correctIndex = deduplicatedVideos.indexWhere((v) => v.id == video.id);
    final finalIndex = correctIndex >= 0 ? correctIndex : index;
    
    // Use callback if provided, otherwise use default navigation
    if (widget.onVideoTap != null) {
      widget.onVideoTap!(video, finalIndex);
      return;
    }

    // Default: Navigate to PlayerScreen with deduplicated list
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/player'),
        fullscreenDialog: true,
        builder: (context) => PlayerScreen(
          mode: PlayerMode.homeFeed,
          initialIndex: finalIndex,
          videoIds: deduplicatedVideos.map((v) => v.id).toList(),
          videos: deduplicatedVideos,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hasError) {
      return _buildFollowingStatusCard(
        icon: Icons.cloud_off_outlined,
        title: 'Following Needs A Refresh',
        message:
            widget.errorMessage ?? 'We could not load videos from your circle right now.',
        showProgress: false,
        actionLabel: 'Try Again',
        onAction: widget.onRefresh,
      );
    }

    if (widget.isLoading && widget.videos.isEmpty) {
      return _buildFollowingStatusCard(
        icon: Icons.people_outline,
        title: 'Gathering Your Following Feed',
        message: 'Looking for fresh videos from creators you follow.',
        showProgress: true,
      );
    }

    if (widget.videos.isEmpty) {
      return _buildFollowingStatusCard(
        icon: Icons.groups_2_outlined,
        title: 'Your Circle Is Quiet Right Now',
        message: widget.emptyMessage ??
            'When creators you follow post public videos, they will show up here.',
        showProgress: false,
        actionLabel: widget.onRefresh != null ? 'Refresh Feed' : null,
        onAction: widget.onRefresh,
      );
    }

    // 🔥 DEDUPLICATE: Remove duplicate videos by videoId before rendering
    final uniqueVideos = <String, HomeVideo>{};
    final deduplicatedVideos = <HomeVideo>[];
    for (final video in widget.videos) {
      if (video.id.isNotEmpty && !uniqueVideos.containsKey(video.id)) {
        uniqueVideos[video.id] = video;
        deduplicatedVideos.add(video);
      }
    }
    
    if (deduplicatedVideos.length != widget.videos.length) {
      log('⚠️ FollowingFeedGrid: Deduplicated ${widget.videos.length} videos to ${deduplicatedVideos.length} unique videos');
    }

    // Calculate header height: SafeArea top + FeedSelector height (50) + margins (8*2) = ~66 + SafeArea
    final mediaQuery = MediaQuery.of(context);
    final safeAreaTop = mediaQuery.padding.top;
    final headerHeight = safeAreaTop + 50 + 16; // SafeArea + FeedSelector height + margins

    return RefreshIndicator(
      onRefresh: () async {
        if (widget.onRefresh != null) {
          widget.onRefresh!();
        }
      },
      color: const Color(0xFF9248d2),
      child: GridView.builder(
        controller: _scrollController,
        padding: EdgeInsets.only(
          top: headerHeight + 8, // 🔥 RESPECT HEADER: Add header height + spacing
          left: 8,
          right: 8,
          bottom: 8,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 🔥 RedNote-style: 2 columns
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.65, // Adjusted for thumbnail + info section below
        ),
        itemCount: deduplicatedVideos.length,
        itemBuilder: (context, index) {
          final video = deduplicatedVideos[index];
          return _buildVideoCard(video, index);
        },
      ),
    );
  }

  Widget _buildVideoCard(HomeVideo video, int index) {
    return GestureDetector(
      onTap: () => _openVideoPlayer(video, index),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[900],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with play icon
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: _buildThumbnail(video),
                  ),
                  // Play icon overlay
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info section below thumbnail
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Caption
                  if (video.caption.isNotEmpty)
                    Text(
                      video.caption,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (video.caption.isNotEmpty) const SizedBox(height: 6),
                  // Creator info and engagement row
                  Row(
                    children: [
                      // Avatar
                      if (video.creator.avatarURL != null &&
                          video.creator.avatarURL!.isNotEmpty)
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey[700]!,
                              width: 1,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.network(
                              video.creator.avatarURL!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                Icons.person,
                                size: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      else
                        const Icon(
                          Icons.person,
                          size: 14,
                          color: Colors.grey,
                        ),
                      const SizedBox(width: 6),
                      // Username
                      Expanded(
                        child: Text(
                          video.creator.displayName.isNotEmpty
                              ? video.creator.displayName
                              : video.creator.username,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Date (if available)
                      if (video.createdAt != null) ...[
                        Text(
                          _formatDate(video.createdAt!),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Likes
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatCount(video.likes),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowingStatusCard({
    required IconData icon,
    required String title,
    required String message,
    required bool showProgress,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF111111),
            Color(0xFF0A0A0A),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.9),
                        AppColors.secondary.withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                  child: showProgress
                      ? const Padding(
                          padding: EdgeInsets.all(18),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(icon, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 14,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(actionLabel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(HomeVideo video) {
    final thumbnailUrl = video.thumbnailURL ?? '';
    
    if (thumbnailUrl.isNotEmpty) {
      return Image.network(
        thumbnailUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[800],
          child: const Center(
            child: Icon(
              Icons.videocam_off,
              color: Colors.white54,
              size: 32,
            ),
          ),
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[900],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9248d2)),
              ),
            ),
          );
        },
      );
    }
    
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: Icon(
          Icons.videocam_off,
          color: Colors.white54,
          size: 32,
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _formatDate(dynamic timestamp) {
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else {
        return '';
      }
      
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        // Format as YYYY-MM-DD
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
  }
}
