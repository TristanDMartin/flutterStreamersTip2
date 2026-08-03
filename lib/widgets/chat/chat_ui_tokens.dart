import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

/// Visual tokens for Inbox + Chat — aligned with Profile / Tippy navy.
abstract final class ChatUiTokens {
  /// Same solid navy as [AppColors.profileViewBackground].
  static const Color scaffold = AppColors.profileViewBackground;
  static const Color scaffoldDeep = AppColors.profileViewBackground;

  static const Color glassFill = Color(0x17FFFFFF);
  static const Color glassBorder = Color(0x14FFFFFF);

  /// Own-message bubbles — StreamersTip purple → blue.
  static const Color outgoingStart = Color(0xFF9248D2);
  static const Color outgoingEnd = Color(0xFF4897D2);
  static const LinearGradient outgoingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[outgoingStart, outgoingEnd],
  );

  /// Website incoming: `rgba(18, 28, 48, 0.82)`.
  static const Color incomingFill = Color(0xD1121C30);
  static const Color incomingBorder = Color(0x14FFFFFF);

  /// Inbox page — solid profile navy (no alternate slate wash).
  static const Color inboxGradientStart = AppColors.profileViewBackground;
  static const Color inboxGradientEnd = AppColors.profileViewBackground;
  static const Color inboxAccent = Color(0xFF6B3AA0);
  static const Color inboxAccentDeep = Color(0xFF4A2570);
  static const Color unreadAccent = Color(0xFF9248D2);

  static const double bubbleMaxWidthFactor = 0.72;
  static const double bubbleRadiusLarge = 20;
  static const double bubbleRadiusSmall = 8;
  static const EdgeInsets bubblePadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 12);

  static const double headerAvatarRadius = 20;
  static const double messageAvatarRadius = 15;
  static const double headerButtonSize = 42;

  static BorderRadius outgoingBubbleRadius = const BorderRadius.only(
    topLeft: Radius.circular(bubbleRadiusLarge),
    topRight: Radius.circular(bubbleRadiusLarge),
    bottomRight: Radius.circular(bubbleRadiusSmall),
    bottomLeft: Radius.circular(bubbleRadiusLarge),
  );

  static BorderRadius incomingBubbleRadius = const BorderRadius.only(
    topLeft: Radius.circular(bubbleRadiusLarge),
    topRight: Radius.circular(bubbleRadiusLarge),
    bottomRight: Radius.circular(bubbleRadiusLarge),
    bottomLeft: Radius.circular(bubbleRadiusSmall),
  );

  static const List<Color> chatShellGradient = <Color>[
    Color(0x38005AFF),
    Color(0x28004DBB),
    scaffold,
  ];
}
