import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'logging_service.dart';

class AccessibilityService {
  static final AccessibilityService _instance =
      AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  bool _isScreenReaderEnabled = false;
  bool _isHighContrastEnabled = false;
  bool _isBoldTextEnabled = false;
  double _textScaleFactor = 1.0;
  double _animationScale = 1.0;

  // Getters
  bool get isScreenReaderEnabled => _isScreenReaderEnabled;
  bool get isHighContrastEnabled => _isHighContrastEnabled;
  bool get isBoldTextEnabled => _isBoldTextEnabled;
  double get textScaleFactor => _textScaleFactor;
  double get animationScale => _animationScale;

  // Initialize accessibility settings
  Future<void> initialize(BuildContext context) async {
    try {
      await _updateAccessibilitySettings(context);
      LoggingService.instance.info('Accessibility service initialized',
          tag: 'AccessibilityService');
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to initialize accessibility service',
        tag: 'AccessibilityService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _updateAccessibilitySettings(BuildContext context) async {
    try {
      final mediaQuery = MediaQuery.of(context);

      _isScreenReaderEnabled = mediaQuery.accessibleNavigation;
      _isHighContrastEnabled = mediaQuery.highContrast;
      _isBoldTextEnabled = mediaQuery.boldText;
      _textScaleFactor = mediaQuery.textScaler.scale(1.0);
      _animationScale = mediaQuery.disableAnimations ? 0.0 : 1.0;

      LoggingService.instance.debug(
        'Accessibility settings updated: screenReader=$_isScreenReaderEnabled, '
        'highContrast=$_isHighContrastEnabled, boldText=$_isBoldTextEnabled, '
        'textScale=$_textScaleFactor, animationScale=$_animationScale',
        tag: 'AccessibilityService',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to update accessibility settings',
        tag: 'AccessibilityService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Announce messages to screen readers
  void announce(String message, {bool assertiveness = false}) {
    try {
      if (_isScreenReaderEnabled) {
        SemanticsService.announce(
          message,
          TextDirection.ltr,
          assertiveness:
              assertiveness ? Assertiveness.assertive : Assertiveness.polite,
        );
        LoggingService.instance
            .debug('Announced: $message', tag: 'AccessibilityService');
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to announce message',
        tag: 'AccessibilityService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Provide haptic feedback
  void provideHapticFeedback(AccessibilityHapticFeedbackType type) {
    try {
      switch (type) {
        case AccessibilityHapticFeedbackType.light:
          HapticFeedback.lightImpact();
          break;
        case AccessibilityHapticFeedbackType.medium:
          HapticFeedback.mediumImpact();
          break;
        case AccessibilityHapticFeedbackType.heavy:
          HapticFeedback.heavyImpact();
          break;
        case AccessibilityHapticFeedbackType.selection:
          HapticFeedback.selectionClick();
          break;
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to provide haptic feedback',
        tag: 'AccessibilityService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Get appropriate text style based on accessibility settings
  TextStyle getAccessibleTextStyle({
    required TextStyle baseStyle,
    double? fontSize,
    FontWeight? fontWeight,
  }) {
    try {
      double finalFontSize = fontSize ?? baseStyle.fontSize ?? 14.0;
      FontWeight finalFontWeight =
          fontWeight ?? baseStyle.fontWeight ?? FontWeight.normal;

      // Adjust font size for text scale factor
      finalFontSize = finalFontSize * _textScaleFactor;

      // Adjust font weight for bold text setting
      if (_isBoldTextEnabled && finalFontWeight == FontWeight.normal) {
        finalFontWeight = FontWeight.bold;
      }

      return baseStyle.copyWith(
        fontSize: finalFontSize,
        fontWeight: finalFontWeight,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to get accessible text style',
        tag: 'AccessibilityService',
        error: e,
        stackTrace: stackTrace,
      );
      return baseStyle;
    }
  }

  // Get appropriate colors based on accessibility settings
  Color getAccessibleColor({
    required Color baseColor,
    Color? highContrastColor,
  }) {
    try {
      if (_isHighContrastEnabled && highContrastColor != null) {
        return highContrastColor;
      }
      return baseColor;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to get accessible color',
        tag: 'AccessibilityService',
        error: e,
        stackTrace: stackTrace,
      );
      return baseColor;
    }
  }

  // Get appropriate icon size based on text scale factor
  double getAccessibleIconSize(double baseSize) {
    try {
      return baseSize * _textScaleFactor;
    } catch (e) {
      return baseSize;
    }
  }

  // Get appropriate padding based on text scale factor
  EdgeInsets getAccessiblePadding(EdgeInsets basePadding) {
    try {
      return EdgeInsets.only(
        left: basePadding.left * _textScaleFactor,
        top: basePadding.top * _textScaleFactor,
        right: basePadding.right * _textScaleFactor,
        bottom: basePadding.bottom * _textScaleFactor,
      );
    } catch (e) {
      return basePadding;
    }
  }

  // Get appropriate minimum touch target size
  Size getMinimumTouchTargetSize() {
    try {
      // WCAG guidelines recommend minimum 44x44 logical pixels
      final baseSize = 44.0;
      final scaledSize = baseSize * _textScaleFactor;
      return Size(scaledSize, scaledSize);
    } catch (e) {
      return const Size(44.0, 44.0);
    }
  }

  // Check if animations should be disabled
  bool shouldDisableAnimations() {
    return _animationScale == 0.0;
  }

  // Get appropriate animation duration
  Duration getAccessibleAnimationDuration(Duration baseDuration) {
    try {
      if (shouldDisableAnimations()) {
        return Duration.zero;
      }
      return Duration(
        milliseconds: (baseDuration.inMilliseconds * _animationScale).round(),
      );
    } catch (e) {
      return baseDuration;
    }
  }

  // Create accessible button
  Widget createAccessibleButton({
    required Widget child,
    required VoidCallback? onPressed,
    String? semanticLabel,
    String? semanticHint,
    bool excludeSemantics = false,
    AccessibilityHapticFeedbackType? hapticFeedbackType,
  }) {
    try {
      return Semantics(
        label: semanticLabel,
        hint: semanticHint,
        excludeSemantics: excludeSemantics,
        button: true,
        enabled: onPressed != null,
        child: GestureDetector(
          onTap: onPressed != null
              ? () {
                  if (hapticFeedbackType != null) {
                    provideHapticFeedback(hapticFeedbackType);
                  }
                  onPressed();
                }
              : null,
          child: child,
        ),
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to create accessible button',
        tag: 'AccessibilityService',
        error: e,
        stackTrace: stackTrace,
      );
      return child;
    }
  }

  // Create accessible image
  Widget createAccessibleImage({
    required Widget image,
    required String semanticLabel,
    String? semanticHint,
    bool excludeSemantics = false,
  }) {
    try {
      return Semantics(
        label: semanticLabel,
        hint: semanticHint,
        excludeSemantics: excludeSemantics,
        image: true,
        child: image,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to create accessible image',
        tag: 'AccessibilityService',
        error: e,
        stackTrace: stackTrace,
      );
      return image;
    }
  }

  // Create accessible text field
  Widget createAccessibleTextField({
    required TextEditingController controller,
    required String semanticLabel,
    String? semanticHint,
    String? placeholder,
    TextInputType? keyboardType,
    bool obscureText = false,
    int? maxLines,
    int? minLines,
  }) {
    try {
      return Semantics(
        label: semanticLabel,
        hint: semanticHint,
        textField: true,
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          minLines: minLines,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: getAccessibleTextStyle(
              baseStyle: const TextStyle(),
            ),
          ),
          style: getAccessibleTextStyle(
            baseStyle: const TextStyle(),
          ),
        ),
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to create accessible text field',
        tag: 'AccessibilityService',
        error: e,
        stackTrace: stackTrace,
      );
      return TextField(controller: controller);
    }
  }

  // Create accessible list item
  Widget createAccessibleListItem({
    required Widget child,
    required String semanticLabel,
    String? semanticHint,
    VoidCallback? onTap,
    bool selected = false,
    AccessibilityHapticFeedbackType? hapticFeedbackType,
  }) {
    try {
      return Semantics(
        label: semanticLabel,
        hint: semanticHint,
        selected: selected,
        button: onTap != null,
        child: GestureDetector(
          onTap: onTap != null
              ? () {
                  if (hapticFeedbackType != null) {
                    provideHapticFeedback(hapticFeedbackType);
                  }
                  onTap();
                }
              : null,
          child: child,
        ),
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to create accessible list item',
        tag: 'AccessibilityService',
        error: e,
        stackTrace: stackTrace,
      );
      return child;
    }
  }

  // Create accessible progress indicator
  Widget createAccessibleProgressIndicator({
    required double value,
    required String semanticLabel,
    String? semanticHint,
    Color? color,
  }) {
    try {
      return Semantics(
        label: semanticLabel,
        hint: semanticHint,
        value: '${(value * 100).round()}%',
        child: LinearProgressIndicator(
          value: value,
          color: color,
        ),
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to create accessible progress indicator',
        tag: 'AccessibilityService',
        error: e,
        stackTrace: stackTrace,
      );
      return LinearProgressIndicator(value: value, color: color);
    }
  }

  // Create accessible switch
  Widget createAccessibleSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String semanticLabel,
    String? semanticHint,
  }) {
    try {
      return Semantics(
        label: semanticLabel,
        hint: semanticHint,
        toggled: value,
        child: Switch(
          value: value,
          onChanged: onChanged,
        ),
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to create accessible switch',
        tag: 'AccessibilityService',
        error: e,
        stackTrace: stackTrace,
      );
      return Switch(value: value, onChanged: onChanged);
    }
  }

  // Create accessible slider
  Widget createAccessibleSlider({
    required double value,
    required ValueChanged<double> onChanged,
    required String semanticLabel,
    String? semanticHint,
    double min = 0.0,
    double max = 1.0,
    int? divisions,
  }) {
    try {
      return Semantics(
        label: semanticLabel,
        hint: semanticHint,
        value: '${(value * 100).round()}%',
        child: Slider(
          value: value,
          onChanged: onChanged,
          min: min,
          max: max,
          divisions: divisions,
        ),
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to create accessible slider',
        tag: 'AccessibilityService',
        error: e,
        stackTrace: stackTrace,
      );
      return Slider(
        value: value,
        onChanged: onChanged,
        min: min,
        max: max,
        divisions: divisions,
      );
    }
  }
}

enum AccessibilityHapticFeedbackType {
  light,
  medium,
  heavy,
  selection,
}
