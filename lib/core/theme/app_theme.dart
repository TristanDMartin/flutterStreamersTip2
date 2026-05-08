import 'package:flutter/material.dart';

import 'st_theme_tokens.dart';

/// Shared line metrics so SF Pro (iOS) and Roboto (Android) occupy similar vertical space.
class StAppTheme {
  StAppTheme._();

  static const double _bodyLargeHeight = 1.45;
  static const double _bodyMediumHeight = 1.43;
  static const double _bodySmallHeight = 1.4;
  static const double _titleLargeHeight = 1.25;
  static const double _titleMediumHeight = 1.35;
  static const double _titleSmallHeight = 1.33;
  static const double _labelLargeHeight = 1.25;

  static TextTheme _textThemeLight() {
    return TextTheme(
      bodyLarge: TextStyle(
        color: StThemeColors.lightTextPrimary,
        fontSize: 16,
        height: _bodyLargeHeight,
        letterSpacing: 0.15,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      bodyMedium: TextStyle(
        color: StThemeColors.lightTextSecondary,
        fontSize: 14,
        height: _bodyMediumHeight,
        letterSpacing: 0.12,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      bodySmall: TextStyle(
        color: StThemeColors.lightTextSecondary,
        fontSize: 12,
        height: _bodySmallHeight,
        letterSpacing: 0.1,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      titleLarge: TextStyle(
        color: StThemeColors.lightTextPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: _titleLargeHeight,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        color: StThemeColors.lightTextPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: _titleMediumHeight,
        letterSpacing: 0.05,
      ),
      titleSmall: TextStyle(
        color: StThemeColors.lightTextPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: _titleSmallHeight,
        letterSpacing: 0.05,
      ),
      labelLarge: TextStyle(
        color: StThemeColors.lightTextPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: _labelLargeHeight,
        letterSpacing: 0.1,
      ),
    );
  }

  static TextTheme _textThemeDark() {
    return TextTheme(
      bodyLarge: TextStyle(
        color: StThemeColors.darkTextPrimary,
        fontSize: 16,
        height: _bodyLargeHeight,
        letterSpacing: 0.15,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      bodyMedium: TextStyle(
        color: StThemeColors.darkTextSecondary,
        fontSize: 14,
        height: _bodyMediumHeight,
        letterSpacing: 0.12,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      bodySmall: TextStyle(
        color: StThemeColors.darkTextSecondary,
        fontSize: 12,
        height: _bodySmallHeight,
        letterSpacing: 0.1,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      titleLarge: TextStyle(
        color: StThemeColors.darkTextPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: _titleLargeHeight,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        color: StThemeColors.darkTextPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: _titleMediumHeight,
        letterSpacing: 0.05,
      ),
      titleSmall: TextStyle(
        color: StThemeColors.darkTextPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: _titleSmallHeight,
        letterSpacing: 0.05,
      ),
      labelLarge: TextStyle(
        color: StThemeColors.darkTextPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: _labelLargeHeight,
        letterSpacing: 0.1,
      ),
    );
  }

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: StThemeColors.brandPurple,
        onPrimary: Colors.white,
        secondary: StThemeColors.brandBlue,
        onSecondary: Colors.white,
        error: StThemeColors.errorRed,
        onError: Colors.white,
        surface: StThemeColors.lightSurface,
        onSurface: StThemeColors.lightTextPrimary,
        surfaceContainerLow: Color(0xFFF1F5F9),
        surfaceContainerHighest: Color(0xFFE2E8F0),
        outline: Color(0xFFCBD5E1),
      ),
      scaffoldBackgroundColor: StThemeColors.lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: StThemeColors.lightBackground,
        foregroundColor: StThemeColors.lightTextPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: _textThemeLight(),
      typography: Typography.material2018(
        platform: TargetPlatform.android,
      ),
      cardTheme: const CardThemeData(
        color: StThemeColors.lightSurface,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: StThemeColors.lightSurface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: StThemeColors.lightSurface,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: StThemeColors.lightSurface,
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: StThemeColors.brandPurple,
        onPrimary: Colors.white,
        secondary: StThemeColors.brandBlue,
        onSecondary: Colors.white,
        error: StThemeColors.errorRed,
        onError: Colors.white,
        surface: StThemeColors.darkSurface,
        onSurface: StThemeColors.darkTextPrimary,
        onSurfaceVariant: StThemeColors.darkTextSecondary,
        surfaceContainerLow: const Color(0xFF1E293B),
        surfaceContainerHigh: const Color(0xFF334155),
        surfaceContainerHighest: const Color(0xFF334155),
        outline: const Color(0xFF64748B),
      ),
      scaffoldBackgroundColor: StThemeColors.darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: StThemeColors.darkBackground,
        foregroundColor: StThemeColors.darkTextPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: _textThemeDark(),
      typography: Typography.material2018(
        platform: TargetPlatform.android,
      ),
      cardTheme: const CardThemeData(
        color: StThemeColors.darkSurface,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: StThemeColors.darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: StThemeColors.darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: StThemeColors.darkSurface,
      ),
    );
  }
}
