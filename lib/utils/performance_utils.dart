import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

/// Performance utilities for instant UI responses
class PerformanceUtils {
  static final Map<String, Timer> _debounceTimers = {};
  static final Map<String, bool> _buttonStates = {};

  /// Instant button tap with haptic feedback
  static Future<void> instantTap({
    required VoidCallback onTap,
    String? buttonId,
    bool enableHaptic = true,
    bool preventDoubleTap = true,
  }) async {
    if (buttonId != null && _buttonStates[buttonId] == true) {
      return; // Prevent double tap
    }

    if (buttonId != null) {
      _buttonStates[buttonId] = true;
    }

    // Immediate haptic feedback
    if (enableHaptic) {
      HapticFeedback.lightImpact();
    }

    // Execute callback immediately
    onTap();

    // Reset button state after short delay
    if (buttonId != null) {
      Timer(const Duration(milliseconds: 50), () {
        _buttonStates[buttonId] = false;
      });
    }
  }

  /// Debounced function call for search/input
  static void debounce(
    String key,
    VoidCallback callback, {
    Duration delay = const Duration(milliseconds: 100),
  }) {
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(delay, callback);
  }

  /// Preload images for better performance
  static Future<void> preloadImages(List<String> imageUrls) async {
    for (final url in imageUrls) {
      try {
        await precacheImage(
            NetworkImage(url), NavigationService.navigatorKey.currentContext!);
      } catch (e) {
        // Ignore preload errors
      }
    }
  }

  /// Optimize list performance
  static Widget optimizedListView({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    ScrollController? controller,
    bool shrinkWrap = false,
    double? cacheExtent,
  }) {
    return ListView.builder(
      controller: controller,
      shrinkWrap: shrinkWrap,
      cacheExtent: cacheExtent ?? 250.0, // Cache 250px ahead
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: itemBuilder(context, index),
        );
      },
    );
  }

  /// Optimize grid performance
  static Widget optimizedGridView({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    required SliverGridDelegate gridDelegate,
    ScrollController? controller,
    bool shrinkWrap = false,
  }) {
    return GridView.builder(
      controller: controller,
      shrinkWrap: shrinkWrap,
      cacheExtent: 250.0,
      itemCount: itemCount,
      gridDelegate: gridDelegate,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: itemBuilder(context, index),
        );
      },
    );
  }

  /// Memory cleanup
  static void cleanup() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _buttonStates.clear();
  }
}

/// Navigation service for global context access
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}

/// Optimized button widget with instant response
class OptimizedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String? buttonId;
  final bool enableHaptic;
  final Duration animationDuration;
  final Color? pressedColor;
  final double scaleOnPress;

  const OptimizedButton({
    super.key,
    required this.child,
    this.onPressed,
    this.buttonId,
    this.enableHaptic = true,
    this.animationDuration = const Duration(milliseconds: 100),
    this.pressedColor,
    this.scaleOnPress = 0.95,
  });

  @override
  State<OptimizedButton> createState() => _OptimizedButtonState();
}

class _OptimizedButtonState extends State<OptimizedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleOnPress,
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

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null) {
      setState(() => _isPressed = true);
      _animationController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.onPressed != null) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  void _handleTap() {
    if (widget.onPressed != null) {
      PerformanceUtils.instantTap(
        onTap: widget.onPressed!,
        buttonId: widget.buttonId,
        enableHaptic: widget.enableHaptic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              color: _isPressed && widget.pressedColor != null
                  ? widget.pressedColor
                  : Colors.transparent,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

// REMOVED: Duplicate OptimizedImage class - use the one in lib/widgets/optimized_image.dart instead
// This was causing ImageReader_JNI buffer overflow issues
