import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/video_service.dart';

export '../services/video_service.dart'
    show videoServiceStateProvider, userVideosProvider, categoryVideosProvider;

final videoServiceProvider = Provider<VideoService>((ref) {
  ref.watch(videoServiceStateProvider);
  return ref.read(videoServiceStateProvider.notifier);
});

class VideoServiceLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setIsLoading(bool isLoading) => state = isLoading;
}

// Track if VideoService is currently loading to prevent multiple simultaneous loads
final NotifierProvider<VideoServiceLoadingNotifier, bool>
    videoServiceLoadingProvider =
    NotifierProvider<VideoServiceLoadingNotifier, bool>(
        VideoServiceLoadingNotifier.new);
