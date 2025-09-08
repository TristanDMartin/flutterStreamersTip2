import 'package:flutter/material.dart';

/// App color constants for StreamersTip
class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // MARK: - Primary Colors
  static const Color primary = Color(0xFF9248D2); // Purple
  static const Color secondary = Color(0xFF7768DF); // Purple variant
  static const Color tertiary = Color(0xFF1670DE); // Blue
  static const Color accent = Color(0xFF66FCF1); // Cyan

  // MARK: - Background Colors
  static const Color background = Color(0xFF0A0A0A); // Dark background
  static const Color surface = Color(0xFF1A1A1A); // Surface color
  static const Color card = Color(0xFF2A2A2A); // Card background
  
  // MARK: - Xcode Color Asset (Dark Gray)
  static const Color xcodeDarkGray = Color(0xFF1A1C21); // RGB(0.10, 0.11, 0.13)
  
  // MARK: - Social Platform Brand Colors
  static const Color twitch = Color(0xFF9146FF);
  static const Color youtube = Color(0xFFFF0000);
  static const Color kick = Color(0xFF53FC18);
  static const Color tiktok = Color(0xFF000000);
  static const Color facebook = Color(0xFF1877F2);
  static const Color bluesky = Color(0xFF0085FF);
  static const Color twitter = Color(0xFF1DA1F2);
  static const Color instagram = Color(0xFFE4405F);
  static const Color rednote = Color(0xFFFF4500);
  static const Color website = Color(0xFF6C757D);

  // MARK: - Semantic Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // MARK: - Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textTertiary = Color(0xFF808080);
  static const Color textDisabled = Color(0xFF4D4D4D);

  // MARK: - Border Colors
  static const Color borderPrimary = Color(0xFF404040);
  static const Color borderSecondary = Color(0xFF2A2A2A);
  static const Color borderAccent = Color(0xFF66FCF1);

  // MARK: - Overlay Colors
  static const Color overlayLight = Color(0x1AFFFFFF);
  static const Color overlayMedium = Color(0x33FFFFFF);
  static const Color overlayDark = Color(0x66FFFFFF);

  // MARK: - Gradient Colors
  static const List<Color> primaryGradient = [
    Color(0xFF9248D2), // Purple
    Color(0xFF7768DF), // Purple variant
    Color(0xFF1670DE), // Blue
    Color(0xFF3C8BD6), // Lighter Blue
    Color(0xFF4897D2), // Lightest Blue
  ];

  static const List<Color> secondaryGradient = [
    Color(0xFF66FCF1), // Cyan
    Color(0xFF45B7D1), // Blue-Cyan
    Color(0xFF1670DE), // Blue
  ];

  static const List<Color> darkGradient = [
    Color(0xFF0A0A0A), // Dark background
    Color(0xFF1A1A1A), // Surface
    Color(0xFF2A2A2A), // Card
  ];

  // MARK: - Color Schemes
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: Colors.white,
    secondary: secondary,
    onSecondary: Colors.white,
    tertiary: tertiary,
    onTertiary: Colors.white,
    error: error,
    onError: Colors.white,
    surface: Colors.white,
    onSurface: Colors.black,
    surfaceContainerHighest: Color(0xFFF5F5F5),
    onSurfaceVariant: Colors.black87,
    outline: borderPrimary,
    outlineVariant: borderSecondary,
    shadow: Colors.black12,
    scrim: Colors.black26,
    inverseSurface: Colors.black,
    onInverseSurface: Colors.white,
    inversePrimary: primary,
    surfaceTint: primary,
  );

  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: primary,
    onPrimary: Colors.white,
    secondary: secondary,
    onSecondary: Colors.white,
    tertiary: tertiary,
    onTertiary: Colors.white,
    error: error,
    onError: Colors.white,
    surface: surface,
    onSurface: textPrimary,
    surfaceContainerHighest: card,
    onSurfaceVariant: textSecondary,
    outline: borderPrimary,
    outlineVariant: borderSecondary,
    shadow: Colors.black26,
    scrim: Colors.black54,
    inverseSurface: Colors.white,
    onInverseSurface: Colors.black,
    inversePrimary: primary,
    surfaceTint: primary,
  );

  // MARK: - Utility Methods
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }

  static Color blend(Color color1, Color color2, double factor) {
    return Color.lerp(color1, color2, factor)!;
  }

  static Color darken(Color color, double amount) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  static Color lighten(Color color, double amount) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  // MARK: - Platform-Specific Colors
  static Color getPlatformColor(ThemeData theme) {
    if (theme.brightness == Brightness.dark) {
      return xcodeDarkGray;
    } else {
      return Colors.grey.shade100;
    }
  }

  // MARK: - Accessibility Colors
  static Color getAccessibleTextColor(Color backgroundColor) {
    // Calculate luminance to determine if we need light or dark text
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  static Color getAccessibleIconColor(Color backgroundColor) {
    return getAccessibleTextColor(backgroundColor);
  }
}

/// Extension methods for Color
extension ColorExtensions on Color {
  /// Get a darker version of this color
  Color darken(double amount) => AppColors.darken(this, amount);
  
  /// Get a lighter version of this color
  Color lighten(double amount) => AppColors.lighten(this, amount);
  
  /// Get a version with opacity
  Color withAlpha(double alpha) => withOpacity(alpha);
  
  /// Get the hex string representation
  String get hexString => '#${value.toRadixString(16).padLeft(8, '0')}';
  
  /// Check if this is a dark color
  bool get isDark => computeLuminance() < 0.5;
  
  /// Check if this is a light color
  bool get isLight => computeLuminance() > 0.5;
}
