import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/streamers_tip_like_service.dart';
import 'heart_animation_widget.dart';

class OptimizedLikeButton extends StatefulWidget {
  final String videoId;
  final int initialLikeCount;
  final bool initialIsLiked;
  final VoidCallback? onLikeChanged;
  final GlobalKey? iconKey;

  const OptimizedLikeButton({
    super.key,
    required this.videoId,
    required this.initialLikeCount,
    required this.initialIsLiked,
    this.onLikeChanged,
    this.iconKey,
  });

  @override
  State<OptimizedLikeButton> createState() => _OptimizedLikeButtonState();
}

class _OptimizedLikeButtonState extends State<OptimizedLikeButton>
    with SingleTickerProviderStateMixin {
  late bool _isLiked;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  // Flight control - prevents multiple network requests
  bool _isInFlight = false;
  DateTime _cooldownUntil = DateTime(0); // Start in the past

  @override
  void initState() {
    super.initState();
    _isLiked = widget.initialIsLiked;

    // Initialize animation controller with faster, more responsive animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100), // Faster animation
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.7, // Less dramatic scale for faster feel
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut, // Faster, snappier animation
    ));

    // Load persistent state after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPersistentState();
      _syncWithTikTokService();
      _addServiceListener();
    });
  }

  /// Add listener to TikTokLikeService for real-time updates
  void _addServiceListener() {
    final service = StreamersTipLikeService();
    service.addListener(_onServiceStateChanged);
  }

  /// Called when TikTokLikeService state changes
  void _onServiceStateChanged() {
    if (mounted) {
      debugPrint('🔄 OptimizedLikeButton: Service state changed, syncing...');
      _syncWithTikTokService();
    }
  }

  /// Sync with TikTokLikeService state
  void _syncWithTikTokService() {
    final service = StreamersTipLikeService();
    final state = service.getLikeState(widget.videoId);

    debugPrint(
        '🔄 OptimizedLikeButton: Syncing state - videoId: ${widget.videoId}, service isLiked: ${state.isLiked}, local _isLiked: $_isLiked, likeCount: ${state.likeCount}');

    if (mounted) {
      setState(() {
        _isLiked = state.isLiked;
      });
      debugPrint(
          '🔄 OptimizedLikeButton: Updated local _isLiked to: $_isLiked');
    }
  }

  @override
  void didUpdateWidget(OptimizedLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIsLiked != widget.initialIsLiked) {
      setState(() {
        _isLiked = widget.initialIsLiked;
      });
    }

    // Only reload persistent state when video ID changes (not on every update)
    if (oldWidget.videoId != widget.videoId) {
      _loadPersistentState();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    // Remove listener
    final service = StreamersTipLikeService();
    service.removeListener(_onServiceStateChanged);
    super.dispose();
  }

  /// Load persistent state from local storage
  Future<void> _loadPersistentState() async {
    try {
      final likeService = StreamersTipLikeService();
      final currentUser = FirebaseAuth.instance.currentUser;
      final cachedState = likeService.getLikeState(widget.videoId);
      final isLiked = currentUser != null
          ? await likeService.isVideoLikedByUser(
              widget.videoId, currentUser.uid)
          : cachedState.isLiked;

      debugPrint(
          '📱 OptimizedLikeButton: Loading persistent state - videoId: ${widget.videoId}, isLiked: $isLiked');

      if (mounted) {
        setState(() {
          _isLiked = isLiked;
        });
        debugPrint('📱 OptimizedLikeButton: Set local _isLiked to: $_isLiked');
      }
    } catch (e) {
      debugPrint('❌ OptimizedLikeButton: Error loading persistent state: $e');
      // Fallback to initial values if loading fails
    }
  }

  void _handleTapDown(TapDownDetails details) {
    if (!_isPressed) {
      setState(() {
        _isPressed = true;
      });
      _animationController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      _animationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isPressed = false;
          });
        }
      });
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      _animationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isPressed = false;
          });
        }
      });
    }
  }

  Future<void> _handleLike() async {
    final now = DateTime.now();

    // Flight control: ignore if in cooldown or in flight
    if (now.isBefore(_cooldownUntil)) {
      debugPrint('💖 OptimizedLikeButton: In cooldown, ignoring tap');
      return;
    }

    if (_isInFlight) {
      debugPrint('💖 OptimizedLikeButton: Request in flight, ignoring tap');
      return;
    }

    // Set flight control
    _isInFlight = true;
    _cooldownUntil = now.add(const Duration(milliseconds: 300));

    try {
      // Immediate UI feedback
      HapticFeedback.lightImpact();

      // Get current state from service
      final service = StreamersTipLikeService();
      final currentState = service.getLikeState(widget.videoId);
      final willBeLiked = !currentState.isLiked;

      // Optimistic UI update
      setState(() {
        _isLiked = willBeLiked;
      });

      // Visual feedback animation
      _animationController.forward().then((_) {
        _animationController.reverse();
      });

      // Create floating hearts animation on like
      if (willBeLiked) {
        _createFloatingHearts();
      }

      // Notify parent immediately
      widget.onLikeChanged?.call();

      // Perform network operation
      await _performBackgroundLikeOperation();
    } finally {
      // Clear flight control
      _isInFlight = false;
    }
  }

  Future<void> _performBackgroundLikeOperation() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        debugPrint('❌ OptimizedLikeButton: No user logged in');
        return;
      }

      // Use the same service as startup preload and double-tap likes.
      final service = StreamersTipLikeService();

      // Use the intended state (what we want to achieve)
      if (_isLiked) {
        // LIKE: Show animation + persist to Firebase + update ML score
        await service.likeVideo(widget.videoId, userId, source: 'button');
        _createFloatingHearts(); // Show animation
      } else {
        // UNLIKE: No animation, just persist to Firebase
        await service.unlikeVideo(widget.videoId, userId);
      }
    } catch (e) {
      debugPrint('❌ OptimizedLikeButton: Background operation failed: $e');
    }
  }

  void _createFloatingHearts() {
    try {
      final RenderBox? box =
          widget.iconKey?.currentContext?.findRenderObject() as RenderBox?;
      final Offset origin = box != null
          ? box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2))
          : Offset(MediaQuery.of(context).size.width / 2,
              MediaQuery.of(context).size.height / 2);

      // Create multiple hearts for better effect
      for (int i = 0; i < 3; i++) {
        Future.delayed(Duration(milliseconds: i * 100), () {
          if (mounted) {
            // Create heart animation at the origin position
            _createHeartAnimation(origin);
          }
        });
      }
    } catch (e) {
      // If floating hearts fail, just continue - not critical
      // appLog('Floating hearts animation error: $e');
    }
  }

  void _createHeartAnimation(Offset position) {
    // Create heart animation widget
    final heartAnimation = HeartAnimationWidget(
      position: position,
      enableParticles: true,
      onComplete: () {
        // Animation completed, no cleanup needed here
      },
    );

    // Show the heart animation by adding it to the overlay
    // Note: This is a simplified approach. In a real app, you'd want to
    // manage the overlay more systematically
    Overlay.of(context).insert(
      OverlayEntry(
        builder: (context) => Stack(
          children: [
            Positioned.fill(
              child: heartAnimation,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use local state that gets synced with TikTokLikeService
    // This ensures consistent state between widget and service
    final service = StreamersTipLikeService();
    final currentState = service.getLikeState(widget.videoId);
    final isLiked = _isLiked; // Use local state, not service state directly
    final likeCount = currentState.likeCount;

    debugPrint(
        '🎨 OptimizedLikeButton: Building - videoId: ${widget.videoId}, local _isLiked: $_isLiked, service isLiked: ${currentState.isLiked}, likeCount: $likeCount');

    return GestureDetector(
      onTap: _handleLike,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked
                        ? const Color(0xFF9248D2)
                        : Colors.white.withValues(alpha: 0.85),
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    likeCount.toString(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
