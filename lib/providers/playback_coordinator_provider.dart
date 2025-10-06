import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/global_playback_coordinator.dart';

/// Provider for the Global Playback Coordinator
final playbackCoordinatorProvider = Provider<GlobalPlaybackCoordinator>((ref) {
  return GlobalPlaybackCoordinator();
});

/// Provider for the active owner stream
final activeOwnerProvider = StreamProvider<String?>((ref) {
  final coordinator = ref.watch(playbackCoordinatorProvider);
  return coordinator.activeOwnerStream;
});

/// Provider for the playback blocked stream
final playbackBlockedProvider = StreamProvider<bool>((ref) {
  final coordinator = ref.watch(playbackCoordinatorProvider);
  return coordinator.playbackBlockedStream;
});

/// Provider for the active video ID stream
final activeVideoIdProvider = StreamProvider<String?>((ref) {
  final coordinator = ref.watch(playbackCoordinatorProvider);
  return coordinator.activeVideoIdStream;
});
