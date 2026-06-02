import 'package:flutter/material.dart';

/// Visual tokens for ChatView (dark glass, StreamersTip identity).
abstract final class ChatUiTokens {
  static const Color scaffold = Color(0xFF070B12);
  static const Color glassFill = Color(0x12FFFFFF);
  static const Color glassBorder = Color(0x14FFFFFF);

  static const Color outgoingStart = Color(0xFF9248D2);
  static const Color outgoingEnd = Color(0xFF4897D2);
  static const LinearGradient outgoingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[outgoingStart, outgoingEnd],
  );

  static const Color incomingFill = Color(0x0EFFFFFF);
  static const Color incomingBorder = Color(0x14FFFFFF);

  static const double bubbleMaxWidthFactor = 0.72;
  static const double bubbleRadiusLarge = 20;
  static const double bubbleRadiusSmall = 6;
  static const EdgeInsets bubblePadding =
      EdgeInsets.symmetric(horizontal: 15, vertical: 11);

  static const double headerAvatarRadius = 17;
  static const double messageAvatarRadius = 15;

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
}
