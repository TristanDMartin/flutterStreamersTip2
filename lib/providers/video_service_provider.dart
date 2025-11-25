import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/video_service.dart';

final videoServiceProvider = Provider<VideoService>((ref) {
  return VideoService();
});

// Track if VideoService is currently loading to prevent multiple simultaneous loads
final videoServiceLoadingProvider = StateProvider<bool>((ref) => false);
