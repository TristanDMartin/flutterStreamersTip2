import 'package:flutter/material.dart';
import '../models/home_video.dart';
import '../models/video_clip.dart';
import 'thumbnail_tile.dart';

class VideoGrid extends StatelessWidget {
  final List<HomeVideo> videos;
  final ValueChanged<VideoClip> onVideoSelected;
  final String categoryId;

  const VideoGrid({
    super.key,
    required this.videos,
    required this.onVideoSelected,
    required this.categoryId,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return VideoThumbnail(
          video: video,
          onTap: () => _onVideoSelected(video),
        );
      },
    );
  }

  void _onVideoSelected(HomeVideo video) {
    // Convert HomeVideo to VideoClip for compatibility
    final clip = VideoClip(
      id: video.id,
      title: video.caption,
      creator: video.creator.displayName,
      thumbnailURL:
          (video.thumbnailURL ?? '').isNotEmpty ? video.thumbnailURL : null,
      videoURL: video.videoURL,
      views: video.views,
      likes: video.likes,
      duration: 0.0,
      categoryId: video.categoryId,
      tags: const [],
    );
    onVideoSelected(clip);
  }
}

class VideoThumbnail extends StatelessWidget {
  final HomeVideo video;
  final VoidCallback onTap;

  const VideoThumbnail({
    super.key,
    required this.video,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.transparent,
        ),
        child: Stack(
          children: [
            // Thumbnail image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ThumbnailTile(
                video: video,
                borderRadius: BorderRadius.circular(12),
                showDurationBadge: false,
                showDraftBadge: false,
                showViewsBadge: false,
              ),
            ),

            // View count overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.5),
                    ],
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '0', // Views placeholder - HomeVideo model views field to be implemented
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
