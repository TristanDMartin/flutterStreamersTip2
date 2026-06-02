import 'package:flutter/foundation.dart';

/// Debug-only Studio entitlement override for internal test accounts.
/// Never active in release builds.
class DebugStudioBypass {
  static const Set<String> _studioUids = <String>{
    'bU0RxyZ2L4ULAv1Co5L4f825yV73',
    'jsmbQMLQjoUyC5cUFvkrRbi9mkp1',
  };

  static bool grantsStudio(String? uid) {
    return kDebugMode && uid != null && _studioUids.contains(uid);
  }
}
