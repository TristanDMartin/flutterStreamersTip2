import 'package:video_player/video_player.dart';

/// Controller lifecycle states
enum ControllerState {
  creating, // Controller created but not yet initializing
  preloading, // Initialization started (prepare called)
  ready, // Initialized and ready to play
  inUse, // Currently active/playing
  coolingDown, // Marked for disposal but in cooldown period
  disposing, // Currently being disposed
  disposed, // Fully disposed
  failed, // Initialization failed
}

/// Comprehensive controller entry with lifecycle tracking
class ControllerEntry {
  final VideoPlayerController controller;
  final String videoId;
  final int controllerId; // hashCode for identification
  ControllerState state;
  final DateTime createdAt;
  DateTime? initStartedAt;
  DateTime? initCompletedAt;
  DateTime? firstFrameAt;
  DateTime? lastAccessedAt;
  DateTime? lastPlayRequestedAt;
  DateTime? coolingDownUntil;
  bool isPinned;
  int generation; // Monotonic counter to detect stale async completions
  int disposeAttempts;
  String? failureReason;

  ControllerEntry({
    required this.controller,
    required this.videoId,
    required this.controllerId,
    required this.state,
    required this.createdAt,
    this.initStartedAt,
    this.initCompletedAt,
    this.firstFrameAt,
    this.lastAccessedAt,
    this.lastPlayRequestedAt,
    this.coolingDownUntil,
    this.isPinned = false,
    this.generation = 0,
    this.disposeAttempts = 0,
    this.failureReason,
  });

  /// Check if controller is in a state that prevents disposal
  bool get canDispose {
    return state != ControllerState.creating &&
        state != ControllerState.preloading &&
        state != ControllerState.inUse &&
        state != ControllerState.disposing &&
        state != ControllerState.disposed &&
        !isPinned;
  }

  /// Check if controller is initializing (creating or preloading)
  bool get isInitializing {
    return state == ControllerState.creating ||
        state == ControllerState.preloading;
  }

  /// Check if controller is ready to use
  bool get isReady {
    return state == ControllerState.ready || state == ControllerState.inUse;
  }

  /// Check if controller is in cooldown
  bool get isInCooldown {
    return state == ControllerState.coolingDown &&
        coolingDownUntil != null &&
        coolingDownUntil!.isAfter(DateTime.now());
  }
}
