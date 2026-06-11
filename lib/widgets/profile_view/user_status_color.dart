import 'package:flutter/material.dart';

import '../../models/user_status.dart';

Color profileUserStatusColor(UserStatus status) {
  switch (status) {
    case UserStatus.online:
      return const Color(0xFF4CAF50);
    case UserStatus.offline:
      return const Color(0xFF9E9E9E);
    case UserStatus.busy:
      return const Color(0xFFFF9800);
    case UserStatus.away:
      return const Color(0xFFF44336);
    case UserStatus.streaming:
      return const Color(0xFF9C27B0);
  }
}
