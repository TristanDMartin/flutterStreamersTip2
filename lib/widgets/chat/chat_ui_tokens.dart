import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

/// Visual tokens for Inbox + Chat.
/// Chat thread follows IG DM language (near-black / solid blue / gray).
abstract final class ChatUiTokens {
  /// Chat thread scaffold — IG DM near-black.
  static const Color chatScaffold = Color(0xFF0A0A0A);
  static const Color chatScaffoldElevated = Color(0xFF121212);

  /// Inbox still uses profile navy.
  static const Color scaffold = AppColors.profileViewBackground;
  static const Color scaffoldDeep = AppColors.profileViewBackground;

  static const Color glassFill = Color(0x17FFFFFF);
  static const Color glassBorder = Color(0x14FFFFFF);

  /// Outgoing — StreamersTip purple → blue gradient.
  static const Color outgoingSolid = Color(0xFF9248D2);
  static const Color outgoingStart = Color(0xFF9248D2);
  static const Color outgoingEnd = Color(0xFF4897D2);
  static const LinearGradient outgoingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[outgoingStart, outgoingEnd],
  );

  /// Incoming — flat dark gray.
  static const Color incomingFill = Color(0xFF262626);
  static const Color incomingBorder = Color(0x1AFFFFFF);

  static const Color composerFill = Color(0xFF1A1A1A);
  static const Color composerBorder = Color(0x1AFFFFFF);
  static const Color reactionChipFill = Color(0xFF1A1A1A);
  static const Color seenLabel = Color(0xFFA0A0A0);
  static const Color actionIcon = Color(0x8CFFFFFF);

  /// Inbox page — solid profile navy (no alternate slate wash).
  static const Color inboxGradientStart = AppColors.profileViewBackground;
  static const Color inboxGradientEnd = AppColors.profileViewBackground;
  static const Color inboxAccent = Color(0xFF6B3AA0);
  static const Color inboxAccentDeep = Color(0xFF4A2570);
  static const Color unreadAccent = Color(0xFF9248D2);

  static const double bubbleMaxWidthFactor = 0.72;
  static const double bubbleRadiusLarge = 22;
  static const double bubbleRadiusSmall = 6;
  static const EdgeInsets bubblePadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 10);

  static const double headerAvatarRadius = 18;
  static const double messageAvatarRadius = 14;
  static const double headerButtonSize = 36;

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
    chatScaffold,
    chatScaffold,
    chatScaffold,
  ];
}
