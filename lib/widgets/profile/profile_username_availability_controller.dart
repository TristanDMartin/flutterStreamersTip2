import 'dart:async';

import '../../services/username_lock_service.dart';
import 'profile_username_rules.dart';

enum UsernameAvailabilityStatus {
  idle,
  checking,
  available,
  taken,
  invalid,
  tooShort,
  error,
}

class ProfileUsernameAvailabilityController {
  ProfileUsernameAvailabilityController({
    UsernameLockService? usernameLockService,
  }) : _usernameLockService = usernameLockService ?? UsernameLockService();

  final UsernameLockService _usernameLockService;
  Timer? _debounceTimer;
  int _requestId = 0;

  UsernameAvailabilityStatus status = UsernameAvailabilityStatus.idle;
  String? statusMessage;

  void dispose() {
    _debounceTimer?.cancel();
  }

  void reset() {
    _debounceTimer?.cancel();
    status = UsernameAvailabilityStatus.idle;
    statusMessage = null;
  }

  Future<void> checkNow({
    required String username,
    required String userId,
    required void Function(UsernameAvailabilityStatus status, String? message)
        onStatusChanged,
  }) async {
    _debounceTimer?.cancel();
    await _runCheck(
      username: username,
      userId: userId,
      onStatusChanged: onStatusChanged,
    );
  }

  void scheduleCheck({
    required String username,
    required String userId,
    required void Function(UsernameAvailabilityStatus status, String? message)
        onStatusChanged,
    Duration debounce = const Duration(milliseconds: 400),
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      unawaited(
        _runCheck(
          username: username,
          userId: userId,
          onStatusChanged: onStatusChanged,
        ),
      );
    });
  }

  Future<void> _runCheck({
    required String username,
    required String userId,
    required void Function(UsernameAvailabilityStatus status, String? message)
        onStatusChanged,
  }) async {
    final int requestId = ++_requestId;
    final String normalized = ProfileUsernameRules.normalize(username);
    if (normalized.isEmpty) {
      status = UsernameAvailabilityStatus.idle;
      statusMessage = null;
      onStatusChanged(status, statusMessage);
      return;
    }
    final String? localError =
        ProfileUsernameRules.localValidationMessage(normalized);
    if (localError != null) {
      status = localError.contains('3 characters')
          ? UsernameAvailabilityStatus.tooShort
          : UsernameAvailabilityStatus.invalid;
      statusMessage = localError;
      onStatusChanged(status, statusMessage);
      return;
    }
    status = UsernameAvailabilityStatus.checking;
    statusMessage = 'Checking...';
    onStatusChanged(status, statusMessage);
    try {
      final bool isAvailable =
          await _usernameLockService.isUsernameAvailableForUser(
        normalized,
        userId,
      );
      if (requestId != _requestId) {
        return;
      }
      if (isAvailable) {
        status = UsernameAvailabilityStatus.available;
        statusMessage = 'Username available';
      } else {
        status = UsernameAvailabilityStatus.taken;
        statusMessage = 'Username already taken';
      }
      onStatusChanged(status, statusMessage);
    } catch (error) {
      if (requestId != _requestId) {
        return;
      }
      status = UsernameAvailabilityStatus.error;
      statusMessage = 'Could not verify username. Try again.';
      onStatusChanged(status, statusMessage);
    }
  }
}
