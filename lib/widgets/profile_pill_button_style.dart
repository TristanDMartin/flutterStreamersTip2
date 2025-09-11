import 'package:flutter/material.dart';

class ProfilePillButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final double? width;
  final double? height;

  const ProfilePillButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isPrimary = false,
    this.width,
    this.height,
  });

  @override
  State<ProfilePillButton> createState() => _ProfilePillButtonState();
}

class _ProfilePillButtonState extends State<ProfilePillButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  // bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
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
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.of(context).textScaler;
    final adaptivePadding = _getAdaptivePadding(textScaler.scale(1.0));
    final adaptiveCornerRadius = _getAdaptiveCornerRadius(textScaler.scale(1.0));
    
    return GestureDetector(
      onTapDown: (_) {
        // setState(() {
        //   _isPressed = true;
        // }); // Commented out as not needed for functionality
        _animationController.forward();
      },
      onTapUp: (_) {
        // setState(() {
        //   _isPressed = false;
        // }); // Commented out as not needed for functionality
        _animationController.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () {
        // setState(() {
        //   _isPressed = false;
        // }); // Commented out as not needed for functionality
        _animationController.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              height: widget.height,
              padding: EdgeInsets.symmetric(
                horizontal: adaptivePadding.horizontal,
                vertical: adaptivePadding.vertical,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(adaptiveCornerRadius),
                gradient: widget.isPrimary
                    ? const LinearGradient(
                        colors: [Colors.blue, Colors.purple],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: widget.isPrimary ? null : Colors.white.withValues(alpha:0.1),
              ),
              child: Center(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: 16 * textScaler.scale(1.0),
                    fontWeight: FontWeight.w600,
                    color: widget.isPrimary ? Colors.black : Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  EdgeInsets _getAdaptivePadding(double textScaleFactor) {
    if (textScaleFactor >= 2.0) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    } else if (textScaleFactor >= 1.75) {
      return const EdgeInsets.symmetric(horizontal: 28, vertical: 14);
    } else if (textScaleFactor >= 1.5) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
    } else if (textScaleFactor >= 1.25) {
      return const EdgeInsets.symmetric(horizontal: 20, vertical: 10);
    } else {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    }
  }

  double _getAdaptiveCornerRadius(double textScaleFactor) {
    if (textScaleFactor >= 2.0) {
      return 28;
    } else if (textScaleFactor >= 1.75) {
      return 26;
    } else if (textScaleFactor >= 1.5) {
      return 24;
    } else if (textScaleFactor >= 1.25) {
      return 22;
    } else {
      return 20;
    }
  }
}

// Alternative: Custom Button Style for use with existing buttons
class ProfilePillButtonStyle extends ButtonStyle {
  final bool isPrimary;

  const ProfilePillButtonStyle({this.isPrimary = false});

  @override
  WidgetStateProperty<EdgeInsetsGeometry>? get padding {
    return WidgetStateProperty.resolveWith((states) {
      const textScaleFactor = 1.0; // You can make this dynamic if needed
      if (textScaleFactor >= 2.0) {
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
      } else if (textScaleFactor >= 1.75) {
        return const EdgeInsets.symmetric(horizontal: 28, vertical: 14);
      } else if (textScaleFactor >= 1.5) {
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
      } else if (textScaleFactor >= 1.25) {
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 10);
      } else {
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      }
    });
  }

  @override
  WidgetStateProperty<OutlinedBorder>? get shape {
    return WidgetStateProperty.resolveWith((states) {
      const textScaleFactor = 1.0; // You can make this dynamic if needed
      double cornerRadius;
      if (textScaleFactor >= 2.0) {
        cornerRadius = 28;
      } else if (textScaleFactor >= 1.75) {
        cornerRadius = 26;
      } else if (textScaleFactor >= 1.5) {
        cornerRadius = 24;
      } else if (textScaleFactor >= 1.25) {
        cornerRadius = 22;
      } else {
        cornerRadius = 20;
      }
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cornerRadius),
      );
    });
  }

  @override
  WidgetStateProperty<Color>? get backgroundColor {
    return WidgetStateProperty.resolveWith((states) {
      if (isPrimary) {
        return Colors.transparent; // Use gradient instead
      } else {
        return Colors.white.withValues(alpha:0.1);
      }
    });
  }

  @override
  WidgetStateProperty<Color>? get foregroundColor {
    return WidgetStateProperty.resolveWith((states) {
      return isPrimary ? Colors.black : Colors.white;
    });
  }

  @override
  WidgetStateProperty<double>? get elevation {
    return WidgetStateProperty.all(0);
  }

  @override
  WidgetStateProperty<Color>? get shadowColor {
    return WidgetStateProperty.all(Colors.transparent);
  }
}

// Usage example widget
class ProfilePillButtonExample extends StatelessWidget {
  const ProfilePillButtonExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E2A36),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Using the custom ProfilePillButton
              ProfilePillButton(
                text: "Follow",
                isPrimary: true,
                onPressed: () {
                  // print("Follow button tapped"); // Commented out for production
                },
              ),
              
              const SizedBox(height: 20),
              
              ProfilePillButton(
                text: "Message",
                isPrimary: false,
                onPressed: () {
                  // print("Message button tapped"); // Commented out for production
                },
              ),
              
              const SizedBox(height: 20),
              
              // Alternative: Using ElevatedButton with ProfilePillButtonStyle
              ElevatedButton(
                style: const ProfilePillButtonStyle(isPrimary: true),
                onPressed: () {
                  // print("Follow button (style) tapped"); // Commented out for production
                },
                child: const Text("Follow (Style)"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
