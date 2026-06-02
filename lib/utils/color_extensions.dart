import 'package:flutter/material.dart';

extension ColorExtension on Color {
  static Color fromHex(String hex) {
    final hexCode = hex.replaceAll('#', '');
    if (hexCode.length == 6) {
      return Color(int.parse('FF$hexCode', radix: 16));
    } else if (hexCode.length == 8) {
      return Color(int.parse(hexCode, radix: 16));
    }
    return Colors.black;
  }

  static Color get followGradientStart => fromHex('#9248d2'); // Purple
  static Color get followGradientEnd => fromHex('#4897d2'); // Lightest blue

  static List<Color> get followGradientColors => [
        fromHex('#9248d2'), // Purple
        fromHex('#7768df'), // Another purple
        fromHex('#1670de'), // Blue
        fromHex('#3c8bd6'), // Lighter blue
        fromHex('#4897d2'), // Lightest
      ];

  static LinearGradient get followGradient => LinearGradient(
        colors: followGradientColors,
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );

  static LinearGradient get streamerCardBackground => LinearGradient(
        colors: followGradientColors,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
}
