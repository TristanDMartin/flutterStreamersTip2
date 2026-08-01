import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Quiet dark Tippy chat tokens — aligned with web Ask Tippy / TippyWidget.
abstract final class TippyChatTokens {
  static const Color bg = Color(0xFF070A12);
  static const Color accent = Color(0xFF6633CC);
  static const Color accent2 = Color(0xFF3B82F6);
  static const Color focus = Color(0xFF7C4DFF);
  static const Color bubbleEnd = Color(0xFF4F46E5);
  static const Color softLavender = Color(0xFFA78BFA);
  static const Color chipText = Color(0xFFE4D4FF);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textBody = Color(0xFFF1F5F9);
  static const Color textPlaceholder = Color(0xFF64748B);
  static const Color border = Color(0x14FFFFFF);
  static const Color surface = Color(0x0AFFFFFF);
  static const Color composer = Color(0xEB161A2A);
  static const Color amberFill = Color(0x1AF59E0B);
  static const Color amberBorder = Color(0x40F59E0B);

  static const String emptyTitle = 'What are we creating today?';
  static const String emptySubtitle =
      'I can help you plan content, improve a stream, find your next idea, '
      'review performance, or build a growth strategy.';

  static const List<String> defaultStarters = <String>[
    'Plan my content for this week',
    'Give me ideas for my next stream',
    'Improve a caption',
    'Help me grow my channel',
  ];

  static TextStyle nunito({
    required double size,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double height = 1.35,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.nunito(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}
