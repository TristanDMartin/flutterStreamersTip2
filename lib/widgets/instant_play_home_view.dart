import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../providers/feed_queue_provider.dart';
import '../services/video_controller_pool_service.dart';
import '../utils/performance_utils.dart';

/// Home view with TikTok-style instant play
class InstantPlayHomeView extends ConsumerStatefulWidget {
  const InstantPlayHomeView({super.key});

  @override
  ConsumerState<InstantPlayHomeView> createState() => _InstantPlayHomeViewState();
}

class _InstantPlayHomeViewState extends ConsumerState<InstantPlayHomeView> {
  final PageController _pageController = PageController();
  final VideoControllerPoolService _controllerPool = VideoControllerPoolService();
  
  VideoPlayerController? _currentController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeFeed();
  }

  @override
  void dispose() {
    _currentController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Initialize the feed for instant play
  Future<void> _initializeFeed() async {
    // Bootstrap the feed
    await ref.read(feedQueueProvider.notifier).bootstrap();
  }

  /// Handle page change (scrolling)
  void _onPageChanged(int index) {
    // Update feed queue
    ref.read(feedQueueProvider.notifier).onIndexChanged(index);
    
    // Update video controller
    _updateVideoController(index);
  }

  /// Update video controller for current index
  Future<void> _updateVideoController(int index) async {
    final feedState = ref.read(feedQueueProvider);
    
    if (index >= 0 && index < feedState.items.length) {
      final video = feedState.items[index];
      
      // Dispose current controller
      _currentController?.dispose();
      
      // Get new controller from pool
      _currentController = await _controllerPool.getController(
        video.id,
        video.videoURL,
      );
      
      if (_currentController != null) {
        setState(() {
          _isVideoInitialized = _currentController!.value.isInitialized;
        });
        
        // Listen to initialization
        _currentController!.addListener(_onVideoControllerUpdate);
        
        // Start playing
        await _currentController!.play();
      }
    }
  }

  /// Handle video controller updates
  void _onVideoControllerUpdate() {
    if (_currentController != null) {
      final isInitialized = _currentController!.value.isInitialized;
      if (isInitialized != _isVideoInitialized) {
        setState(() {
          _isVideoInitialized = isInitialized;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedQueueProvider);
    
    if (feedState.isBootstrapping) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (feedState.hasError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: ${feedState.errorMessage}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(feedQueueProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (feedState.items.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('No videos available'),
        ),
      );
    }
    
    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: feedState.items.length,
        itemBuilder: (context, index) {
          final video = feedState.items[index];
          return _buildVideoItem(video, index);
        },
      ),
    );
  }

  /// Build individual video item
  Widget _buildVideoItem(dynamic video, int index) {
    final isCurrentIndex = index == ref.read(feedQueueProvider).currentIndex;
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video player or poster
          if (isCurrentIndex && _currentController != null && _isVideoInitialized)
            _buildVideoPlayer()
          else
            _buildPoster(video.thumbnailURL),
          
          // Video overlay
          _buildVideoOverlay(video),
        ],
      ),
    );
  }

  /// Build video player
  Widget _buildVideoPlayer() {
    return Center(
      child: AspectRatio(
        aspectRatio: _currentController!.value.aspectRatio,
        child: VideoPlayer(_currentController!),
      ),
    );
  }

  /// Build poster image
  Widget _buildPoster(String? posterUrl) {
    if (posterUrl == null || posterUrl.isEmpty) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: Icon(Icons.video_library, size: 64, color: Colors.white),
        ),
      );
    }
    
    return Image.network(
      posterUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[900],
          child: const Center(
            child: Icon(Icons.broken_image, size: 64, color: Colors.white),
          ),
        );
      },
    );
  }

  /// Build video overlay
  Widget _buildVideoOverlay(dynamic video) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Video info
            Text(
              video.caption,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            
            // Creator info
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: video.creator.avatarURL != null
                      ? NetworkImage(video.creator.avatarURL!)
                      : null,
                  child: video.creator.avatarURL == null
                      ? const Icon(Icons.person, size: 16)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  '@${video.creator.username}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(Icons.favorite, video.likes.toString()),
                _buildActionButton(Icons.comment, video.comments.toString()),
                _buildActionButton(Icons.share, 'Share'),
                _buildActionButton(Icons.bookmark, 'Save'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build action button
  Widget _buildActionButton(IconData icon, String label) {
    return OptimizedButton(
      buttonId: 'action_${icon.codePoint}',
      onPressed: () {
        // Handle action button tap
        PerformanceUtils.instantTap(
          onTap: () {
            // Add specific action logic here
            debugPrint('Tapped $label button');
          },
          enableHaptic: true,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
