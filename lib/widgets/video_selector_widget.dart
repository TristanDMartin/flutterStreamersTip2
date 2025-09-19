import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile_video.dart';
import '../services/insights_firebase_service.dart';

/// Widget for selecting which video to analyze in Insights
class VideoSelectorWidget extends ConsumerStatefulWidget {
  final String? selectedVideoId;
  final Function(ProfileVideo) onVideoSelected;

  const VideoSelectorWidget({
    super.key,
    this.selectedVideoId,
    required this.onVideoSelected,
  });

  @override
  ConsumerState<VideoSelectorWidget> createState() => _VideoSelectorWidgetState();
}

class _VideoSelectorWidgetState extends ConsumerState<VideoSelectorWidget> {
  int _currentIndex = 0;
  late PageController _pageController;
  List<ProfileVideo> _videos = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadVideos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadVideos() {
    // Load user's recent videos from Firebase
    final insightsService = ref.read(insightsFirebaseServiceProvider);
    
    insightsService.getUserProfileVideos().then((videos) {
      if (mounted) {
        setState(() {
          _videos = videos;
          if (_videos.isNotEmpty && widget.selectedVideoId != null) {
            _currentIndex = _videos.indexWhere(
              (video) => video.id == widget.selectedVideoId,
            );
            if (_currentIndex == -1) _currentIndex = 0;
          }
          
          // Select the first video if none is selected
          if (_videos.isNotEmpty && _currentIndex == 0 && widget.selectedVideoId == null) {
            widget.onVideoSelected(_videos[0]);
          }
        });
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _videos = <ProfileVideo>[];
        });
      }
      if (kDebugMode) {
        print('Error loading videos: $error');
      }
    });
    
    // Uncomment the line below to test with mock data instead:
    // setState(() {
    //   _videos = _getMockVideos();
    //   if (_videos.isNotEmpty && widget.selectedVideoId != null) {
    //     _currentIndex = _videos.indexWhere(
    //       (video) => video.id == widget.selectedVideoId,
    //     );
    //     if (_currentIndex == -1) _currentIndex = 0;
    //   }
    // });
  }


  String _formatDuration(double seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = (seconds % 60).round();
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_videos.isEmpty) {
      return Container(
        height: 280,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.video_library_outlined,
                  color: Colors.white70,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Videos Yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Upload your first video to start tracking insights and analytics.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Insights available 24 hours after upload',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentVideo = _videos[_currentIndex];

    return Container(
      height: 280,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Video selector with thumbnail
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  // Video thumbnail
                  Center(
                    child: Container(
                      width: 200,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            // Thumbnail image
                            Image.network(
                              currentVideo.thumbnailURL ?? 'https://picsum.photos/300/400?random=1',
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    Icons.video_library,
                                    color: Colors.white54,
                                    size: 48,
                                  ),
                                );
                              },
                            ),
                            
                            // Duration overlay
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _formatDuration(currentVideo.duration),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            
                            // Play icon overlay
                            const Center(
                              child: Icon(
                                Icons.play_circle_fill,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Navigation arrows
                  if (_videos.length > 1) ...[
                    // Left arrow
                    Positioned(
                      left: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            final newIndex = _currentIndex > 0 
                                ? _currentIndex - 1 
                                : _videos.length - 1;
                            _pageController.animateToPage(
                              newIndex,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Right arrow
                    Positioned(
                      right: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            final newIndex = _currentIndex < _videos.length - 1 
                                ? _currentIndex + 1 
                                : 0;
                            _pageController.animateToPage(
                              newIndex,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Video info and posting date
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Video caption
                Text(
                  currentVideo.caption,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 8),
                
                // Posting date and basic stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDate(currentVideo.createdAt),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.visibility,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatViews(currentVideo.views),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Insights availability status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isVideoTooNewForInsights(currentVideo)
                        ? Colors.orange.withValues(alpha: 0.2)
                        : Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _isVideoTooNewForInsights(currentVideo)
                          ? Colors.orange.withValues(alpha: 0.5)
                          : Colors.green.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isVideoTooNewForInsights(currentVideo)
                            ? Icons.schedule
                            : Icons.analytics,
                        color: _isVideoTooNewForInsights(currentVideo)
                            ? Colors.orange
                            : Colors.green,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getInsightsAvailabilityMessage(currentVideo),
                        style: TextStyle(
                          color: _isVideoTooNewForInsights(currentVideo)
                              ? Colors.orange
                              : Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Page indicator dots
          if (_videos.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _videos.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _currentIndex
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatViews(int views) {
    if (views < 1000) {
      return views.toString();
    } else if (views < 1000000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    } else {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    }
  }

  bool _isVideoTooNewForInsights(ProfileVideo video) {
    final now = DateTime.now();
    final hoursSinceUpload = now.difference(video.createdAt).inHours;
    return hoursSinceUpload < 24;
  }

  String _getInsightsAvailabilityMessage(ProfileVideo video) {
    final now = DateTime.now();
    final hoursSinceUpload = now.difference(video.createdAt).inHours;
    
    if (hoursSinceUpload < 24) {
      final remainingHours = 24 - hoursSinceUpload;
      if (remainingHours > 1) {
        return 'Insights available in ${remainingHours.toInt()} hours';
      } else {
        final remainingMinutes = (remainingHours * 60).toInt();
        return 'Insights available in $remainingMinutes minutes';
      }
    }
    return 'Insights available';
  }
}
