import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/utils/video_ready_contract.dart';

void main() {
  group('videoHasPlayableSource', () {
    test('accepts muxPlaybackId', () {
      expect(
        videoHasPlayableSource(<String, dynamic>{'muxPlaybackId': 'abc'}),
        isTrue,
      );
    });

    test('accepts hls/canonical/playback without mux id', () {
      expect(
        videoHasPlayableSource(<String, dynamic>{
          'hlsUrl': 'https://stream.mux.com/x.m3u8',
        }),
        isTrue,
      );
      expect(
        videoHasPlayableSource(<String, dynamic>{
          'canonicalPlaybackUrl': 'https://cdn.example.com/v.m3u8',
        }),
        isTrue,
      );
      expect(
        videoHasPlayableSource(<String, dynamic>{
          'playbackUrl': 'https://cdn.example.com/v.mp4',
        }),
        isTrue,
      );
    });

    test('rejects empty / null-playback ready shape', () {
      expect(videoHasPlayableSource(<String, dynamic>{}), isFalse);
      expect(
        videoHasPlayableSource(<String, dynamic>{
          'muxPlaybackId': '  ',
          'hlsUrl': '',
        }),
        isFalse,
      );
    });
  });

  group('isCanonicalFeedReady', () {
    test('requires explicit isReadyForFeed true', () {
      expect(
        isCanonicalFeedReady(<String, dynamic>{
          'status': 'ready',
          'hlsUrl': 'https://stream.mux.com/x.m3u8',
        }),
        isFalse,
      );
      expect(
        isCanonicalFeedReady(<String, dynamic>{
          'status': 'ready',
          'isReadyForFeed': true,
          'hlsUrl': 'https://stream.mux.com/x.m3u8',
        }),
        isTrue,
      );
    });
  });
}
