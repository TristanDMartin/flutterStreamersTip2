import 'package:flutter/material.dart';
import 'instant_response_button.dart';

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isLoading;
  final Color? color;
  final bool useGradient;
  final Key? iconKey;
  
  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isLoading = false,
    this.color,
    this.useGradient = false,
    this.iconKey,
  });

  @override
  Widget build(BuildContext context) {
    return InstantActionButton(
      icon: icon,
      label: label,
      isActive: isActive,
      onTap: onTap,
      isLoading: isLoading,
      color: color,
      useGradient: useGradient,
      iconKey: iconKey,
      hapticType: HapticFeedbackType.lightImpact,
    );
  }
}

// Legacy ActionButton implementation for backward compatibility
class LegacyActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isLoading;
  final Color? color;
  final bool useGradient;
  final Key? iconKey;
  
  const LegacyActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isLoading = false,
    this.color,
    this.useGradient = false,
    this.iconKey,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
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
            else ...[
              if (useGradient && isActive)
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
                    color: color ?? (isActive ? const Color(0xFF9248d2) : Colors.white.withValues(alpha:0.85)),
                  ),
                ),
            ],
            
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
