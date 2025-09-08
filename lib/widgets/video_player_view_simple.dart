import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../models/home_video.dart';
import '../providers/favorites_provider.dart';
import 'action_button.dart';
import 'share_sheet.dart';

class VideoPlayerViewSimple extends ConsumerStatefulWidget {
  final HomeVideo video;
  final bool isMuted;
  final bool isPlaying;
  final VoidCallback? onMuteChanged;
  final VoidCallback? onVideoUnfavorited;
  final bool showForYouToggle;
  final bool showDiscoverButton;
  
  const VideoPlayerViewSimple({
    super.key,
    required this.video,
    this.isMuted = false,
    this.isPlaying = true,
    this.onMuteChanged,
    this.onVideoUnfavorited,
    this.showForYouToggle = true,
    this.showDiscoverButton = true,
  });

  @override
  ConsumerState<VideoPlayerViewSimple> createState() => _VideoPlayerViewSimpleState();
}

class _VideoPlayerViewSimpleState extends ConsumerState<VideoPlayerViewSimple>
    with TickerProviderStateMixin {
  VideoPlayerController? _videoPlayerController;
  bool _isInitialized = false;
  bool _isLoading = true;
  
  // Local state for UI
  bool _localIsLiked = false;
  int _localLikeCount = 0;
  bool _isLikeLoading = false;
  
  // Floating hearts animation
  final List<FloatingHeart> _floatingHearts = [];
  Offset? _lastDoubleTapPosition;
  final GlobalKey _likeIconKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _localIsLiked = widget.video.isLiked;
    _localLikeCount = widget.video.likes;
    _initializeVideo();
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoPlayerViewSimple oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _playVideo();
      } else {
        _pauseVideo();
      }
    }
    
    if (widget.isMuted != oldWidget.isMuted) {
      _setMuteState(widget.isMuted);
    }
  }

  Future<void> _initializeVideo() async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.video.videoURL),
      );
      
      await _videoPlayerController!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
        
        // Set up video looping
        _videoPlayerController!.addListener(() {
          if (_videoPlayerController!.value.position >= _videoPlayerController!.value.duration) {
            _videoPlayerController!.seekTo(Duration.zero);
            _videoPlayerController!.play();
          }
        });
        
        // Set initial mute state
        _setMuteState(widget.isMuted);
        
        // Start playing if requested
        if (widget.isPlaying) {
          _playVideo();
        }
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _playVideo() {
    if (_videoPlayerController != null && _isInitialized) {
      _videoPlayerController!.play();
    }
  }

  void _pauseVideo() {
    if (_videoPlayerController != null && _isInitialized) {
      _videoPlayerController!.pause();
    }
  }

  void _setMuteState(bool muted) {
    if (_videoPlayerController != null && _isInitialized) {
      _videoPlayerController!.setVolume(muted ? 0.0 : 1.0);
    }
  }

  void _togglePlayPause() {
    if (widget.isPlaying) {
      _pauseVideo();
    } else {
      _playVideo();
    }
  }

  void _handleHeartIconTap() {
    if (_isLikeLoading) return;
    
    // Immediate haptic feedback
    HapticFeedback.lightImpact();
    
    setState(() {
      _isLikeLoading = true;
      final bool wasLiked = _localIsLiked;
      _localIsLiked = !wasLiked;
      _localLikeCount += _localIsLiked ? 1 : -1;
    });
    
    // Create floating hearts when liking
    if (_localIsLiked) {
      final RenderBox? box = _likeIconKey.currentContext?.findRenderObject() as RenderBox?;
      final Offset from = box != null
          ? box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2))
          : (Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2));
      _createFloatingHearts(from);
    }
    
    // Reset loading state
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isLikeLoading = false;
        });
      }
    });
  }

  void _handleFavorite() {
    // Immediate haptic feedback
    HapticFeedback.lightImpact();
    
    final favoritesNotifier = ref.read(favoritesProvider.notifier);
    final isCurrentlyFavorited = ref.read(favoritesProvider).favorites.contains(widget.video.id);
    
    favoritesNotifier.toggleFavorite(widget.video.id);
    
    // If unfavoriting, call the callback
    if (isCurrentlyFavorited && widget.onVideoUnfavorited != null) {
      widget.onVideoUnfavorited!();
    }
  }

  void _createFloatingHearts(Offset origin) {
    setState(() {
      _floatingHearts.clear();
    });
    
    const int count = 2; // Reduced from 3 to 2 to save memory
    const List<Color> palette = <Color>[
      Color(0xFF9248d2),
      Color(0xFF7768df),
      Color(0xFF1670de),
    ];
    
    for (int i = 0; i < count; i++) {
      final double angle = (i * 120.0) * math.pi / 180.0;
      final double distance = 60.0 + (i * 20.0);
      final double heartX = origin.dx + math.cos(angle) * distance;
      final double heartY = origin.dy + math.sin(angle) * distance;
      
      final double rotation = (math.Random().nextDouble() * 20) - 10;
      final double scale = 0.9 + (i * 0.1);
      const int lifeMs = 800; // Reduced from 1200 to 800
      final int delayMs = i * 100; // Reduced from 150 to 100
      
      final heart = FloatingHeart(
        id: DateTime.now().millisecondsSinceEpoch + i,
        position: Offset(heartX, heartY),
        scale: scale,
        opacity: 1.0,
        rotation: rotation * math.pi / 180.0,
        offset: 0.0,
        color: palette[i % palette.length],
      );
      
      setState(() {
        _floatingHearts.add(heart);
      });
      
      _animateHeart(heart, scale, delayMs, lifeMs);
    }
  }

  void _animateHeart(FloatingHeart heart, double initialScale, int delayMs, int lifeMs) {
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) {
        setState(() {
          final index = _floatingHearts.indexWhere((h) => h.id == heart.id);
          if (index != -1) {
            _floatingHearts[index] = _floatingHearts[index].copyWith(
              scale: initialScale + 0.4,
              offset: -80.0,
            );
          }
        });
      }
    });
    
    Future.delayed(Duration(milliseconds: delayMs + 200), () {
      if (mounted) {
        setState(() {
          final index = _floatingHearts.indexWhere((h) => h.id == heart.id);
          if (index != -1) {
            _floatingHearts[index] = _floatingHearts[index].copyWith(
              offset: 120.0,
              opacity: 0.8,
            );
          }
        });
      }
    });
    
    Future.delayed(Duration(milliseconds: delayMs + 600), () {
      if (mounted) {
        setState(() {
          final index = _floatingHearts.indexWhere((h) => h.id == heart.id);
          if (index != -1) {
            _floatingHearts[index] = _floatingHearts[index].copyWith(
              opacity: 0.0,
            );
          }
        });
      }
    });

    Future.delayed(Duration(milliseconds: delayMs + lifeMs), () {
      if (mounted) {
        setState(() {
          _floatingHearts.removeWhere((h) => h.id == heart.id);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTap: _handleDoubleTap,
      onDoubleTapDown: (details) {
        _lastDoubleTapPosition = details.localPosition;
      },
      child: Stack(
        children: [
          // Video Player Background
          if (_isInitialized && _videoPlayerController != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoPlayerController!.value.size.width,
                  height: _videoPlayerController!.value.size.height,
                  child: VideoPlayer(_videoPlayerController!),
                ),
              ),
            )
          else
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isLoading ? "Loading video..." : "Error loading video",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Pause indicator overlay
          if (!widget.isPlaying)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 60,
                ),
              ),
            ),
          
          // Main UI Overlay
          _buildUIOverlay(),
          
          // Action buttons overlay
          _buildActionButtons(),
          
          // Floating hearts overlay
          _buildFloatingHearts(),
        ],
      ),
    );
  }

  Widget _buildUIOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.3),
                Colors.black.withValues(alpha: 0.7),
              ],
            ),
          ),
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Creator info
              Row(
                children: [
                  Text(
                    "@${widget.video.creator.username}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Caption
              Text(
                widget.video.caption,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Consumer(
      builder: (context, ref, child) {
        final favoritesState = ref.watch(favoritesProvider);
        final isFavorited = favoritesState.favorites.contains(widget.video.id);
        final isFavoriteLoading = favoritesState.isLoading;
        
        return Positioned(
          right: 16,
          bottom: 0,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height - 
                         MediaQuery.of(context).padding.top - 
                         MediaQuery.of(context).padding.bottom - 100,
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ActionButton(
                      icon: _isLikeLoading 
                          ? Icons.favorite 
                          : (_localIsLiked ? Icons.favorite : Icons.favorite_border),
                      label: _localLikeCount.toString(),
                      isActive: _localIsLiked,
                      onTap: _handleHeartIconTap,
                      isLoading: _isLikeLoading,
                      useGradient: _localIsLiked,
                      iconKey: _likeIconKey,
                    ),
                    const SizedBox(height: 16),
                    ActionButton(
                      icon: Icons.chat_bubble_outline,
                      label: widget.video.comments.toString(),
                      isActive: false,
                      onTap: () {
                        // TODO: Implement comments
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Comments coming soon'),
                            backgroundColor: Color(0xFF9248d2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    ActionButton(
                      icon: isFavoriteLoading 
                          ? Icons.bookmark 
                          : (isFavorited ? Icons.bookmark : Icons.bookmark_border),
                      label: "Save",
                      isActive: isFavorited,
                      onTap: isFavoriteLoading ? () {} : _handleFavorite,
                      isLoading: isFavoriteLoading,
                      color: isFavorited ? const Color(0xFF9248D2) : Colors.white.withValues(alpha: 0.85),
                      useGradient: isFavorited,
                    ),
                    const SizedBox(height: 16),
                    ActionButton(
                      icon: Icons.share,
                      label: "Share",
                      isActive: false,
                      onTap: () => _showShareSheet(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingHearts() {
    return IgnorePointer(
      ignoring: true,
      child: Stack(
        children: _floatingHearts.map((heart) {
          return Positioned(
            left: heart.position.dx - 25,
            top: heart.position.dy - 25 + heart.offset,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              opacity: heart.opacity,
              child: Transform.rotate(
                angle: heart.rotation,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.elasticOut,
                  scale: heart.scale,
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: (heart.color ?? const Color(0xFF9248d2)).withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.favorite,
                      color: heart.color ?? const Color(0xFF9248d2),
                      size: 45,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _handleDoubleTap() {
    if (_isLikeLoading) return;
    if (!_localIsLiked) {
      setState(() {
        _isLikeLoading = true;
        _localIsLiked = true;
        _localLikeCount += 1;
      });
      HapticFeedback.lightImpact();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _isLikeLoading = false);
      });
    }
    final Size size = MediaQuery.of(context).size;
    final Offset center = Offset(size.width / 2, size.height / 2);
    _createFloatingHearts(_lastDoubleTapPosition ?? center);
  }

  void _showShareSheet(BuildContext context) {
    // Immediate haptic feedback
    HapticFeedback.lightImpact();
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200), // Faster animation
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: ShareSheet(
            videoId: widget.video.id,
            videoUrl: widget.video.videoURL,
            videoCaption: widget.video.caption,
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          )),
          child: child,
        );
      },
    );
  }
}

// Floating heart model
class FloatingHeart {
  final int id;
  final Offset position;
  final double scale;
  final double opacity;
  final double rotation;
  final double offset;
  final Color? color;

  FloatingHeart({
    required this.id,
    required this.position,
    this.scale = 0.8,
    this.opacity = 1.0,
    this.rotation = 0.0,
    this.offset = 0.0,
    this.color,
  });

  FloatingHeart copyWith({
    int? id,
    Offset? position,
    double? scale,
    double? opacity,
    double? rotation,
    double? offset,
    Color? color,
  }) {
    return FloatingHeart(
      id: id ?? this.id,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      opacity: opacity ?? this.opacity,
      rotation: rotation ?? this.rotation,
      offset: offset ?? this.offset,
      color: color ?? this.color,
    );
  }
}
