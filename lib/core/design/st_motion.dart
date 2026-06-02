import 'package:flutter/material.dart';

/// Durations and curves shared app‑wide (feed, sheets, overlays).
abstract final class STMotion {
  STMotion._();

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration smooth = Duration(milliseconds: 320);
  static const Duration sheet = Duration(milliseconds: 420);

  static const Curve out = Curves.easeOutCubic;
  static const Curve inOut = Curves.easeInOutCubic;
}
