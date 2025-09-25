import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'online_status_indicator.dart';

class TrendingCreatorRing extends ConsumerStatefulWidget {
  final String? imageUrl;
  final String username;
  final String? userId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TrendingCreatorRing({
    super.key,
    this.imageUrl,
    required this.username,
    this.userId,
    this.onTap,
    this.onLongPress,
  });

  @override
  ConsumerState<TrendingCreatorRing> createState() => _TrendingCreatorRingState();
}

class _TrendingCreatorRingState extends ConsumerState<TrendingCreatorRing> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void activate() {
    super.activate();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
    _animationController.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    setState(() {
      _isPressed = false;
    });
    _animationController.reverse();
  }

  void _handleLongPress() {
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    const size = 84.0;
    
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onLongPress: _handleLongPress,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: _isPressed
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Gradient ring (matches ProfileView styling)
                  Container(
                    width: size,
                    height: size,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Color(0xFFFF6CAB), // Pink
                          Color(0xFF8E54E9), // Purple
                          Color(0xFF3D99F7), // Blue
                          Color(0xFFFF6CAB), // Pink (back to start for smooth transition)
                        ],
                      ),
                    ),
                  ),
                  
                  // White gap
                  Container(
                    width: size - 6,
                    height: size - 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                  
                  // Avatar
                  Container(
                    width: size - 12,
                    height: size - 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: widget.imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(widget.imageUrl!),
                              fit: BoxFit.cover,
                              onError: (exception, stackTrace) {
                                // Handle image loading error
                              },
                            )
                          : null,
                      color: Colors.black.withValues(alpha: 0.2), // Matches ProfileView styling
                    ),
                    child: widget.imageUrl == null
                        ? const Icon(
                            Icons.person,
                            color: Colors.white70,
                            size: 32,
                          )
                        : null,
                  ),
                  
                  // Dynamic online status indicator
                  if (widget.userId != null)
                    OnlineStatusIndicator(
                      userId: widget.userId!,
                      size: 12,
                      showBorder: true,
                      borderColor: Colors.white,
                      borderWidth: 2,
                      showShadow: true,
                      position: const EdgeInsets.only(
                        right: 6,
                        top: 6,
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
