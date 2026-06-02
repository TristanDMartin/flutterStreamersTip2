import 'package:flutter/material.dart';

enum OnlineStatus { online, idle, doNotDisturb, invisible }

extension OnlineStatusDisplay on OnlineStatus {
  String get displayName => switch (this) {
        OnlineStatus.online => 'Online',
        OnlineStatus.idle => 'Idle',
        OnlineStatus.doNotDisturb => 'Do Not Disturb',
        OnlineStatus.invisible => 'Invisible',
      };

  IconData get iconData => switch (this) {
        OnlineStatus.online => Icons.circle,
        OnlineStatus.idle => Icons.nightlight_round,
        OnlineStatus.doNotDisturb => Icons.remove_circle,
        OnlineStatus.invisible => Icons.circle_outlined,
      };

  Color get iconColor => switch (this) {
        OnlineStatus.online => Colors.green,
        OnlineStatus.idle => Colors.yellow,
        OnlineStatus.doNotDisturb => Colors.red,
        OnlineStatus.invisible => Colors.grey,
      };
}

OnlineStatus parseOnlineStatus(dynamic value) {
  final String v = (value ?? '').toString().toLowerCase();
  return switch (v) {
    'online' => OnlineStatus.online,
    'idle' => OnlineStatus.idle,
    'donotdisturb' => OnlineStatus.doNotDisturb,
    'do_not_disturb' => OnlineStatus.doNotDisturb,
    'dnd' => OnlineStatus.doNotDisturb,
    'invisible' => OnlineStatus.invisible,
    _ => OnlineStatus.invisible,
  };
}
