import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/video_service.dart';

final videoServiceProvider = Provider<VideoService>((ref) {
  return VideoService();
});
