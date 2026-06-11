import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/playback_loop_coordinator.dart';
import 'package:streamers_tip/services/video_resume_service.dart';

void main() {
  group('VideoResumeService', () {
    late VideoResumeService service;

    setUp(() {
      service = VideoResumeService();
      service.clearAll();
    });

    test('onPageLeave clamps near-end position to zero', () async {
      service.onPageLeave(
        'video-1',
        const Duration(seconds: 9, milliseconds: 800),
        const Duration(seconds: 10),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final Duration? resume = await service.onPageEnter('video-1');
      expect(resume, isNull);
    });

    test('onPageEnter resumes mid-video position within grace window', () async {
      service.onPageLeave(
        'video-2',
        const Duration(seconds: 5),
        const Duration(seconds: 30),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final Duration? resume = await service.onPageEnter('video-2');
      expect(resume, const Duration(seconds: 5));
    });

    test('onPageEnter restarts when saved position is near end', () async {
      service.onPageLeave(
        'video-3',
        const Duration(seconds: 29, milliseconds: 700),
        const Duration(seconds: 30),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final Duration? resume = await service.onPageEnter('video-3');
      expect(resume, isNull);
    });

    test('clamp helper matches service near-end behavior', () {
      expect(
        PlaybackLoopCoordinator.clampResumePosition(
          const Duration(seconds: 29, milliseconds: 600),
          const Duration(seconds: 30),
        ),
        Duration.zero,
      );
    });
  });
}
