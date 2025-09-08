import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// MARK: - Quick Response Button Style
class QuickResponseButtonStyle extends ButtonStyle {
  const QuickResponseButtonStyle();

  @override
  WidgetStateProperty<Color?>? get backgroundColor => 
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.grey.withValues(alpha: 0.1);
        }
        return null;
      });

  @override
  WidgetStateProperty<Color?>? get foregroundColor => 
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.grey;
        }
        return null;
      });

  @override
  WidgetStateProperty<double>? get elevation => 
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return 1.0;
        }
        return 2.0;
      });

  @override
  WidgetStateProperty<EdgeInsetsGeometry>? get padding => 
      const WidgetStatePropertyAll(EdgeInsets.all(16.0));

  @override
  WidgetStateProperty<OutlinedBorder>? get shape => 
      const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        ),
      );
}

// MARK: - Quick Response Button Widget
class QuickResponseButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final bool enabled;

  const QuickResponseButton({
    super.key,
    required this.child,
    this.onPressed,
    this.style,
    this.enabled = true,
  });

  @override
  State<QuickResponseButton> createState() => _QuickResponseButtonState();
}

class _QuickResponseButtonState extends State<QuickResponseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
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
    if (widget.enabled) {
      _animationController.forward();
      _triggerHapticFeedback();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.enabled) {
      _animationController.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.enabled) {
      _animationController.reverse();
    }
  }

  void _triggerHapticFeedback() {
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: ElevatedButton(
              onPressed: widget.enabled ? widget.onPressed : null,
              style: widget.style ?? const QuickResponseButtonStyle(),
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

// MARK: - Quick Response Button Modifier
class QuickResponseButtonModifier extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final bool enabled;

  const QuickResponseButtonModifier({
    super.key,
    required this.child,
    this.onPressed,
    this.style,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return QuickResponseButton(
      onPressed: onPressed,
      style: style,
      enabled: enabled,
      child: child,
    );
  }
}

// MARK: - Custom Corner Radius Widget
class RoundedCornerWidget extends StatelessWidget {
  final Widget child;
  final double radius;
  final List<Corner> corners;

  const RoundedCornerWidget({
    super.key,
    required this.child,
    this.radius = 8.0,
    this.corners = const [Corner.topLeft, Corner.topRight, Corner.bottomLeft, Corner.bottomRight],
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: corners.contains(Corner.topLeft) 
            ? Radius.circular(radius) 
            : Radius.zero,
        topRight: corners.contains(Corner.topRight) 
            ? Radius.circular(radius) 
            : Radius.zero,
        bottomLeft: corners.contains(Corner.bottomLeft) 
            ? Radius.circular(radius) 
            : Radius.zero,
        bottomRight: corners.contains(Corner.bottomRight) 
            ? Radius.circular(radius) 
            : Radius.zero,
      ),
      child: child,
    );
  }
}

// MARK: - Corner Enum
enum Corner {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

// MARK: - Haptic Feedback Utility
class HapticFeedbackUtil {
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void heavy() => HapticFeedback.heavyImpact();
  static void selection() => HapticFeedback.selectionClick();
  // Map iOS notification types to closest Flutter impacts
  static void success() => HapticFeedback.mediumImpact();
  static void warning() => HapticFeedback.selectionClick();
  static void error() => HapticFeedback.heavyImpact();
}

// MARK: - Always Responsive Widget
class AlwaysResponsiveWidget extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const AlwaysResponsiveWidget({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}

// MARK: - View Extensions (Flutter equivalent)
extension ViewExtensions on Widget {
  /// Applies quick response button styling with haptic feedback
  Widget quickResponseButton({
    VoidCallback? onPressed,
    ButtonStyle? style,
    bool enabled = true,
  }) {
    return QuickResponseButtonModifier(
      onPressed: onPressed,
      style: style,
      enabled: enabled,
      child: this,
    );
  }

  /// Adds immediate haptic feedback
  Widget hapticFeedback({
    VoidCallback? onTap,
    HapticFeedbackType type = HapticFeedbackType.lightImpact,
  }) {
    return GestureDetector(
      onTap: () {
        switch (type) {
          case HapticFeedbackType.lightImpact:
            HapticFeedback.lightImpact();
            break;
          case HapticFeedbackType.mediumImpact:
            HapticFeedback.mediumImpact();
            break;
          case HapticFeedbackType.heavyImpact:
            HapticFeedback.heavyImpact();
            break;
          case HapticFeedbackType.selectionClick:
            HapticFeedback.selectionClick();
            break;
        }
        onTap?.call();
      },
      child: this,
    );
  }

  /// Ensures button is always responsive
  Widget alwaysResponsive({VoidCallback? onTap}) {
    return AlwaysResponsiveWidget(
      onTap: onTap,
      child: this,
    );
  }

  /// Applies custom corner radius to specific corners
  Widget cornerRadius(double radius, List<Corner> corners) {
    return RoundedCornerWidget(
      radius: radius,
      corners: corners,
      child: this,
    );
  }
}

// MARK: - Haptic Feedback Type Enum
enum HapticFeedbackType {
  lightImpact,
  mediumImpact,
  heavyImpact,
  selectionClick,
}
