import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Robust instant response button with debouncing, single-flight, and request-scoped behavior
class RobustInstantResponseButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final double? width;
  final Duration debounceDelay;
  final Duration minimumSpinnerTime;
  final bool enabled;
  final String? loadingText;
  final IconData? icon;
  final double borderRadius;
  final Gradient? gradient;

  const RobustInstantResponseButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.padding,
    this.height,
    this.width,
    this.debounceDelay = const Duration(milliseconds: 50),
    this.minimumSpinnerTime = const Duration(milliseconds: 100),
    this.enabled = true,
    this.loadingText,
    this.icon,
    this.borderRadius = 8.0,
    this.gradient,
  });

  @override
  State<RobustInstantResponseButton> createState() =>
      _RobustInstantResponseButtonState();
}

class _RobustInstantResponseButtonState
    extends State<RobustInstantResponseButton> {
  Timer? _debounceTimer;
  Timer? _minimumSpinnerTimer;
  bool _isMinimumSpinnerActive = false;
  bool _isRequestInFlight = false;
  String? _currentRequestId;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _minimumSpinnerTimer?.cancel();
    super.dispose();
  }

  /// Generate a unique request ID
  String _generateRequestId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (1000 + (DateTime.now().microsecond % 9000)).toString();
  }

  /// Start minimum spinner timer
  void _startMinimumSpinner() {
    _isMinimumSpinnerActive = true;
    _minimumSpinnerTimer?.cancel();
    _minimumSpinnerTimer = Timer(widget.minimumSpinnerTime, () {
      if (mounted) {
        setState(() {
          _isMinimumSpinnerActive = false;
        });
      }
    });
  }

  /// Check if we should show loading state
  bool get shouldShowLoading =>
      widget.isLoading || _isMinimumSpinnerActive || _isRequestInFlight;

  /// Debounced button press with single-flight protection
  void _debouncedOnPressed() {
    if (!widget.enabled || shouldShowLoading || widget.onPressed == null) {
      return;
    }

    // Cancel any existing debounce timer
    _debounceTimer?.cancel();

    // Generate new request ID
    final requestId = _generateRequestId();

    // Start debounce timer
    _debounceTimer = Timer(widget.debounceDelay, () {
      // Check if this is still the latest request
      if (_currentRequestId != null && _currentRequestId != requestId) {
        // appLog("🚫 Ignoring stale button press: $requestId (current: $_currentRequestId)");
        return;
      }

      _currentRequestId = requestId;
      _isRequestInFlight = true;
      _startMinimumSpinner();

      if (mounted) {
        setState(() {});
      }

      // Provide haptic feedback
      HapticFeedback.lightImpact();

      try {
        // Execute the callback
        widget.onPressed!();

        // Clear request state after a short delay
        Timer(const Duration(milliseconds: 50), () {
          if (mounted && _currentRequestId == requestId) {
            _currentRequestId = null;
            _isRequestInFlight = false;
            setState(() {});
          }
        });
      } catch (e) {
        // Clear request state on error
        if (mounted && _currentRequestId == requestId) {
          _currentRequestId = null;
          _isRequestInFlight = false;
          setState(() {});
        }
        rethrow;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = !widget.enabled || shouldShowLoading;
    final backgroundColor = isDisabled
        ? Colors.grey.withValues(alpha: 0.3)
        : (widget.backgroundColor ?? Theme.of(context).primaryColor);
    final textColor =
        isDisabled ? Colors.grey[600] : (widget.textColor ?? Colors.white);

    return SizedBox(
      height: widget.height ?? 50,
      width: widget.width,
      child: widget.gradient != null && !isDisabled
          ? GestureDetector(
              onTap: isDisabled ? null : _debouncedOnPressed,
              child: Container(
                decoration: BoxDecoration(
                  gradient: widget.gradient,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                ),
                child: ElevatedButton(
                  onPressed:
                      null, // Disable built-in onPressed since we're using GestureDetector
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: textColor,
                    padding: widget.padding ??
                        const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: _buildButtonContent(textColor),
                ),
              ),
            )
          : ElevatedButton(
              onPressed: isDisabled ? null : _debouncedOnPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: textColor,
                padding: widget.padding ??
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                ),
                elevation: 0,
              ),
              child: _buildButtonContent(textColor),
            ),
    );
  }

  Widget _buildButtonContent(Color? textColor) {
    return shouldShowLoading
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              if (widget.loadingText != null) ...[
                const SizedBox(width: 8),
                Text(
                  widget.loadingText!,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                widget.text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
  }
}

/// Specialized robust button for authentication actions
class RobustAuthButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool enabled;
  final String? loadingText;
  final IconData? icon;

  const RobustAuthButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.enabled = true,
    this.loadingText,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return RobustInstantResponseButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      enabled: enabled,
      loadingText: loadingText,
      icon: icon,
      backgroundColor: const Color(0xFF955CFF), // Fallback color
      textColor: Colors.white,
      debounceDelay: const Duration(milliseconds: 50),
      minimumSpinnerTime: const Duration(milliseconds: 100),
      borderRadius: 24, // Match ProfileView pill shape
      gradient: const LinearGradient(
        colors: [
          Color(0xFF955CFF),
          Color(0xFF3D99F7)
        ], // Match ProfileView gradient
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
    );
  }
}

/// Specialized robust button for destructive actions
class RobustDestructiveButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool enabled;
  final String? loadingText;
  final IconData? icon;

  const RobustDestructiveButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.enabled = true,
    this.loadingText,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return RobustInstantResponseButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      enabled: enabled,
      loadingText: loadingText,
      icon: icon,
      backgroundColor: Colors.red[600],
      textColor: Colors.white,
      debounceDelay: const Duration(milliseconds: 50),
      minimumSpinnerTime: const Duration(milliseconds: 100),
    );
  }
}
