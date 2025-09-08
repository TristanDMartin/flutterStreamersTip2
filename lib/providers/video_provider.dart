import 'package:flutter_riverpod/flutter_riverpod.dart';

class VideoProvider extends StateNotifier<VideoState> {
  VideoProvider() : super(VideoState.initial());

  // Placeholder implementation
}

class VideoState {
  final bool isLoading;
  final String? error;

  const VideoState({
    this.isLoading = false,
    this.error,
  });

  factory VideoState.initial() => const VideoState();
}

final videoProvider = StateNotifierProvider<VideoProvider, VideoState>((ref) {
  return VideoProvider();
});
