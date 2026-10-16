import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';

/// Cross-platform design system for iOS (Cupertino) and Android (Material Design 3)
/// Provides adaptive spacing, typography, and styling constants
class AppleMaterialDesign {
  AppleMaterialDesign._();

  /// Platform detection
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  // ============================================================================
  // SPACING SYSTEM (8pt grid - same on both platforms)
  // ============================================================================
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space48 = 48.0;

  // Standard padding
  static const double paddingSmall = space8;
  static const double paddingMedium = space16;
  static const double paddingLarge = space24;

  // Screen margins
  static const double screenMargin = space16;

  // List item spacing
  static const double listItemSpacing = space12;
  static const double listItemPadding = space16;

  // ============================================================================
  // TOUCH TARGETS
  // ============================================================================
  static const double touchTargetIOS = 44.0;
  static const double touchTargetAndroid = 48.0;
  static double get touchTarget => isIOS ? touchTargetIOS : touchTargetAndroid;

  // Button heights
  static const double buttonHeightSmall = 36.0;
  static const double buttonHeightMedium = 44.0;
  static const double buttonHeightLarge = 48.0;

  // ============================================================================
  // CORNER RADIUS
  // ============================================================================
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;

  // Platform-specific corner radius for buttons
  static const double buttonRadiusIOS = 12.0;
  static const double buttonRadiusAndroid = 8.0;
  static double get buttonRadius => isIOS ? buttonRadiusIOS : buttonRadiusAndroid;

  // Card radius
  static const double cardRadiusIOS = 16.0;
  static const double cardRadiusAndroid = 12.0;
  static double get cardRadius => isIOS ? cardRadiusIOS : cardRadiusAndroid;

  // ============================================================================
  // ELEVATION & SHADOWS
  // ============================================================================
  
  // iOS uses very subtle shadows
  static List<BoxShadow> get iosShadowSmall => [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get iosShadowMedium => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  // Material elevation values
  static const double materialElevationLow = 1.0;
  static const double materialElevationMedium = 2.0;
  static const double materialElevationHigh = 4.0;

  // ============================================================================
  // TYPOGRAPHY SCALE
  // ============================================================================

  // iOS (SF Pro) - points
  static const double iosLargeTitle = 34.0;
  static const double iosTitle1 = 28.0;
  static const double iosTitle2 = 22.0;
  static const double iosTitle3 = 20.0;
  static const double iosHeadline = 17.0;
  static const double iosBody = 17.0;
  static const double iosCallout = 16.0;
  static const double iosSubheadline = 15.0;
  static const double iosFootnote = 13.0;
  static const double iosCaption1 = 12.0;
  static const double iosCaption2 = 11.0;

  // Android (Roboto) - sp
  static const double androidDisplayLarge = 57.0;
  static const double androidDisplayMedium = 45.0;
  static const double androidDisplaySmall = 36.0;
  static const double androidHeadlineLarge = 32.0;
  static const double androidHeadlineMedium = 28.0;
  static const double androidHeadlineSmall = 24.0;
  static const double androidTitleLarge = 22.0;
  static const double androidTitleMedium = 16.0;
  static const double androidTitleSmall = 14.0;
  static const double androidBodyLarge = 16.0;
  static const double androidBodyMedium = 14.0;
  static const double androidBodySmall = 12.0;
  static const double androidLabelLarge = 14.0;
  static const double androidLabelMedium = 12.0;
  static const double androidLabelSmall = 11.0;

  // Font weights
  static const FontWeight weightRegular = FontWeight.w400;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightSemibold = FontWeight.w600;
  static const FontWeight weightBold = FontWeight.w700;

  // ============================================================================
  // ADAPTIVE TEXT STYLES
  // ============================================================================

  static TextStyle largeTitleStyle(BuildContext context) {
    return TextStyle(
      fontSize: isIOS ? iosLargeTitle : androidDisplaySmall,
      fontWeight: isIOS ? weightBold : weightRegular,
      letterSpacing: isIOS ? 0 : -0.5,
    );
  }

  static TextStyle title1Style(BuildContext context) {
    return TextStyle(
      fontSize: isIOS ? iosTitle1 : androidHeadlineMedium,
      fontWeight: isIOS ? weightBold : weightRegular,
    );
  }

  static TextStyle title2Style(BuildContext context) {
    return TextStyle(
      fontSize: isIOS ? iosTitle2 : androidTitleLarge,
      fontWeight: isIOS ? weightSemibold : weightMedium,
    );
  }

  static TextStyle headlineStyle(BuildContext context) {
    return TextStyle(
      fontSize: isIOS ? iosHeadline : androidTitleMedium,
      fontWeight: isIOS ? weightSemibold : weightMedium,
    );
  }

  static TextStyle bodyStyle(BuildContext context) {
    return TextStyle(
      fontSize: isIOS ? iosBody : androidBodyMedium,
      fontWeight: weightRegular,
    );
  }

  static TextStyle subheadlineStyle(BuildContext context) {
    return TextStyle(
      fontSize: isIOS ? iosSubheadline : androidBodySmall,
      fontWeight: weightRegular,
    );
  }

  static TextStyle footnoteStyle(BuildContext context) {
    return TextStyle(
      fontSize: isIOS ? iosFootnote : androidLabelMedium,
      fontWeight: weightRegular,
    );
  }

  static TextStyle captionStyle(BuildContext context) {
    return TextStyle(
      fontSize: isIOS ? iosCaption2 : androidLabelSmall,
      fontWeight: weightRegular,
    );
  }

  // ============================================================================
  // ANIMATION DURATIONS
  // ============================================================================
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 250);
  static const Duration animationSlow = Duration(milliseconds: 350);

  // Platform-specific curves
  static Curve get animationCurve => isIOS ? Curves.easeInOut : Curves.easeOut;

  // ============================================================================
  // OPACITY VALUES
  // ============================================================================
  static const double opacityDisabled = 0.38;
  static const double opacitySecondary = 0.60;
  static const double opacityTertiary = 0.40;

  // ============================================================================
  // DIVIDER / SEPARATOR
  // ============================================================================
  static const double dividerThicknessIOS = 0.5; // Hairline
  static const double dividerThicknessAndroid = 1.0;
  static double get dividerThickness =>
      isIOS ? dividerThicknessIOS : dividerThicknessAndroid;

  // ============================================================================
  // SAFE AREA HELPERS
  // ============================================================================
  static EdgeInsets safeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  static double safeAreaTop(BuildContext context) {
    return MediaQuery.of(context).padding.top;
  }

  static double safeAreaBottom(BuildContext context) {
    return MediaQuery.of(context).padding.bottom;
  }
}
