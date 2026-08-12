import 'package:flutter/material.dart';

/// Visual accents for Creator Pulse activity categories.
///
/// Keep colors in sync with website:
/// `streamerstipReact/lib/activity/activityDesignTokens.ts`
/// Source mock: `streamerstip_activity_redesign.html`
enum ActivityPulseAccent {
  thread,
  like,
  follow,
  momentum,
  /// Content-plan / due-today action items (distinct from social).
  action,
  tippy,
  live,
  mention,
  standard,
}

abstract final class ActivityPulseTokens {
  static const Color background = Color(0xFF070B14);
  static const Color surface = Color(0x0AFFFFFF);
  static const Color border = Color(0x14FFFFFF);

  static const Color threadGlow = Color(0xFF9248D2);
  static const Color likeGlow = Color(0xFFE879A8);
  static const Color followGlow = Color(0xFF4897D2);
  static const Color momentumGlow = Color(0xFFF5A623);
  /// Amber accent for planner due / action reminders.
  static const Color actionAmber = Color(0xFFFACD75);
  static const Color tippyGlow = Color(0xFF4FD1C5);
  static const Color liveGlow = Color(0xFF4ADE80);
  static const Color mentionGlow = Color(0xFFB794F6);

  static const LinearGradient activeChipGradient = LinearGradient(
    colors: <Color>[Color(0xFF9248D2), Color(0xFF4897D2)],
  );

  static Color accentColor(ActivityPulseAccent accent) {
    switch (accent) {
      case ActivityPulseAccent.thread:
        return threadGlow;
      case ActivityPulseAccent.like:
        return likeGlow;
      case ActivityPulseAccent.follow:
        return followGlow;
      case ActivityPulseAccent.momentum:
        return momentumGlow;
      case ActivityPulseAccent.action:
        return actionAmber;
      case ActivityPulseAccent.tippy:
        return tippyGlow;
      case ActivityPulseAccent.live:
        return liveGlow;
      case ActivityPulseAccent.mention:
        return mentionGlow;
      case ActivityPulseAccent.standard:
        return const Color(0xFF64748B);
    }
  }
}
