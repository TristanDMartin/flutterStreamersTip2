import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A button widget that provides instant visual and haptic feedback
/// for the best user experience with single tap responsiveness
class InstantResponseButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final bool enabled;
  final HapticFeedbackType hapticType;
  final double scaleOnPress;
  final Duration animationDuration;
  final bool showRippleEffect;

  const InstantResponseButton({
    super.key,
    required this.child,
    this.onPressed,
    this.style,
    this.enabled = true,
    this.hapticType = HapticFeedbackType.lightImpact,
    this.scaleOnPress = 0.95,
    this.animationDuration = const Duration(milliseconds: 25),
    this.showRippleEffect = true,
  });

  @override
  State<InstantResponseButton> createState() => _InstantResponseButtonState();
}

class _InstantResponseButtonState extends State<InstantResponseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
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

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
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
    if (widget.enabled && !_isPressed) {
      setState(() {
        _isPressed = true;
      });
      _animationController.forward();
      _triggerHapticFeedback();
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

  void _triggerHapticFeedback() {
    switch (widget.hapticType) {
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
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.enabled ? widget.onPressed : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: widget.showRippleEffect
                  ? Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.enabled ? widget.onPressed : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: widget.child,
                        ),
                      ),
                    )
                  : widget.child,
            ),
          );
        },
      ),
    );
  }
}

/// Enhanced ElevatedButton with instant response
class InstantElevatedButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final bool enabled;
  final HapticFeedbackType hapticType;

  const InstantElevatedButton({
    super.key,
    required this.child,
    this.onPressed,
    this.style,
    this.enabled = true,
    this.hapticType = HapticFeedbackType.lightImpact,
  });

  @override
  Widget build(BuildContext context) {
    return InstantResponseButton(
      onPressed: onPressed,
      enabled: enabled,
      hapticType: hapticType,
      child: ElevatedButton(
        onPressed: null, // Handled by InstantResponseButton
        style: style,
        child: child,
      ),
    );
  }
}

/// Enhanced OutlinedButton with instant response
class InstantOutlinedButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final bool enabled;
  final HapticFeedbackType hapticType;

  const InstantOutlinedButton({
    super.key,
    required this.child,
    this.onPressed,
    this.style,
    this.enabled = true,
    this.hapticType = HapticFeedbackType.lightImpact,
  });

  @override
  Widget build(BuildContext context) {
    return InstantResponseButton(
      onPressed: onPressed,
      enabled: enabled,
      hapticType: hapticType,
      child: OutlinedButton(
        onPressed: null, // Handled by InstantResponseButton
        style: style,
        child: child,
      ),
    );
  }
}

/// Enhanced TextButton with instant response
class InstantTextButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final bool enabled;
  final HapticFeedbackType hapticType;

  const InstantTextButton({
    super.key,
    required this.child,
    this.onPressed,
    this.style,
    this.enabled = true,
    this.hapticType = HapticFeedbackType.lightImpact,
  });

  @override
  Widget build(BuildContext context) {
    return InstantResponseButton(
      onPressed: onPressed,
      enabled: enabled,
      hapticType: hapticType,
      child: TextButton(
        onPressed: null, // Handled by InstantResponseButton
        style: style,
        child: child,
      ),
    );
  }
}

/// Enhanced IconButton with instant response
class InstantIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final bool enabled;
  final HapticFeedbackType hapticType;
  final double? iconSize;
  final Color? color;

  const InstantIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.style,
    this.enabled = true,
    this.hapticType = HapticFeedbackType.selectionClick,
    this.iconSize,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InstantResponseButton(
      onPressed: onPressed,
      enabled: enabled,
      hapticType: hapticType,
      scaleOnPress: 0.9,
      child: IconButton(
        onPressed: null, // Handled by InstantResponseButton
        style: style,
        icon: icon,
        iconSize: iconSize,
        color: color,
      ),
    );
  }
}

/// Enhanced FloatingActionButton with instant response
class InstantFloatingActionButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final bool enabled;
  final HapticFeedbackType hapticType;

  const InstantFloatingActionButton({
    super.key,
    required this.child,
    this.onPressed,
    this.style,
    this.enabled = true,
    this.hapticType = HapticFeedbackType.mediumImpact,
  });

  @override
  Widget build(BuildContext context) {
    return InstantResponseButton(
      onPressed: onPressed,
      enabled: enabled,
      hapticType: hapticType,
      scaleOnPress: 0.9,
      child: FloatingActionButton(
        onPressed: null, // Handled by InstantResponseButton
        child: child,
      ),
    );
  }
}

/// Custom button for video player actions with instant response
class InstantVideoActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final Color? color;
  final double size;
  final HapticFeedbackType hapticType;

  const InstantVideoActionButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.enabled = true,
    this.color,
    this.size = 50.0,
    this.hapticType = HapticFeedbackType.lightImpact,
  });

  @override
  Widget build(BuildContext context) {
    return InstantResponseButton(
      onPressed: onPressed,
      enabled: enabled,
      hapticType: hapticType,
      scaleOnPress: 0.85,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: color ?? Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }
}

/// Custom button for navigation actions with instant response
class InstantNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final Color? color;
  final double size;
  final HapticFeedbackType hapticType;

  const InstantNavButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.enabled = true,
    this.color,
    this.size = 48.0,
    this.hapticType = HapticFeedbackType.selectionClick,
  });

  @override
  Widget build(BuildContext context) {
    return InstantResponseButton(
      onPressed: onPressed,
      enabled: enabled,
      hapticType: hapticType,
      scaleOnPress: 0.9,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color ?? Colors.white,
          size: size * 0.6,
        ),
      ),
    );
  }
}

/// Enhanced ActionButton with instant response
class InstantActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isLoading;
  final Color? color;
  final bool useGradient;
  final Key? iconKey;
  final HapticFeedbackType hapticType;

  const InstantActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isLoading = false,
    this.color,
    this.useGradient = false,
    this.iconKey,
    this.hapticType = HapticFeedbackType.lightImpact,
  });

  @override
  Widget build(BuildContext context) {
    return InstantResponseButton(
      onPressed: isLoading ? null : onTap,
      enabled: !isLoading,
      hapticType: hapticType,
      scaleOnPress: 0.9,
      child: SizedBox(
        width: 50,
        height: 50,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else if (useGradient)
              ShaderMask(
                shaderCallback: (Rect rect) {
                  return const LinearGradient(
                    colors: <Color>[
                      Color(0xFF9248d2),
                      Color(0xFF7768df),
                      Color(0xFF1670de),
                      Color(0xFF3c8bd6),
                      Color(0xFF4897d2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(rect);
                },
                blendMode: BlendMode.srcIn,
                child: SizedBox(
                  key: iconKey,
                  child: Icon(
                    icon,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
              )
            else
              SizedBox(
                key: iconKey,
                child: Icon(
                  icon,
                  size: 32,
                  color: color ??
                      (isActive
                          ? const Color(0xFF9248d2)
                          : Colors.white.withValues(alpha: 0.85)),
                ),
              ),

            const SizedBox(height: 4),

            // Label
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Haptic feedback types for different button interactions
enum HapticFeedbackType {
  lightImpact,
  mediumImpact,
  heavyImpact,
  selectionClick,
}

/// Extension methods for easy instant response button usage
extension InstantResponseButtonExtensions on Widget {
  /// Wraps any widget with instant response behavior
  Widget instantResponse({
    VoidCallback? onTap,
    HapticFeedbackType hapticType = HapticFeedbackType.lightImpact,
    double scaleOnPress = 0.95,
    bool enabled = true,
  }) {
    return InstantResponseButton(
      onPressed: onTap,
      enabled: enabled,
      hapticType: hapticType,
      scaleOnPress: scaleOnPress,
      child: this,
    );
  }

  /// Adds haptic feedback to any tappable widget
  Widget withHapticFeedback({
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
      behavior: HitTestBehavior.opaque,
      child: this,
    );
  }
}
