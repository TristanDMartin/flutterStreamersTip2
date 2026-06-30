import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/utils/video_url_resolver.dart';

void main() {
  group('firstNonEmpty', () {
    test('returns first trimmed non-empty string', () {
      expect(
        firstNonEmpty(<dynamic>[null, '', '  ', 'ok', 'x']),
        'ok',
      );
    });
    test('returns null when all empty', () {
      expect(firstNonEmpty(<dynamic>[null, '', '  ']), isNull);
    });
  });

  group('resolvePlaybackUrl', () {
    test('builds mux URL from muxPlaybackId', () {
      final String? url = resolvePlaybackUrl(<String, dynamic>{
        'muxPlaybackId': 'abc123',
      });
      expect(url, contains('stream.mux.com'));
      expect(url, endsWith('.m3u8'));
    });

    test('prefers explicit hlsUrl', () {
      final String? url = resolvePlaybackUrl(<String, dynamic>{
        'hlsUrl': 'https://example.com/master.m3u8',
      });
      expect(url, 'https://example.com/master.m3u8');
    });

    test('prefers canonicalPlaybackUrl over synthesized mux URL', () {
      final String? url = resolvePlaybackUrl(<String, dynamic>{
        'canonicalPlaybackUrl': 'https://cdn.example.com/ready/master.m3u8',
        'muxPlaybackId': 'abc123',
      });
      expect(url, 'https://cdn.example.com/ready/master.m3u8');
    });

    test('prefers shared playback fields before synthesized mux URL', () {
      final String? url = resolvePlaybackUrl(<String, dynamic>{
        'hlsUrl': 'https://cdn.example.com/ready/master.m3u8',
        'mp4Url': 'https://cdn.example.com/ready/video.mp4',
        'playbackUrl': 'https://cdn.example.com/ready/fallback.mp4',
        'muxPlaybackId': 'abc123',
      });
      expect(url, 'https://cdn.example.com/ready/master.m3u8');
    });

    test('uses mp4Url before playbackUrl', () {
      final String? url = resolvePlaybackUrl(<String, dynamic>{
        'mp4Url': 'https://cdn.example.com/ready/video.mp4',
        'playbackUrl': 'https://cdn.example.com/ready/fallback.mp4',
      });
      expect(url, 'https://cdn.example.com/ready/video.mp4');
    });

    test('uses videoUrl when no mux or hls', () {
      final String? url = resolvePlaybackUrl(<String, dynamic>{
        'videoUrl': 'https://cdn.example.com/v.mp4',
      });
      expect(url, isNotNull);
      expect(url, contains('cdn.example.com'));
    });
  });

  group('resolveReadyPlaybackUrl', () {
    test('requires ready status, feed gate, and canonical URL', () {
      expect(
        resolveReadyPlaybackUrl(<String, dynamic>{
          'status': 'ready',
          'isReadyForFeed': true,
          'canonicalPlaybackUrl': 'https://stream.mux.com/abc.m3u8',
        }),
        'https://stream.mux.com/abc.m3u8',
      );
    });

    test('does not play processing videos', () {
      expect(
        resolveReadyPlaybackUrl(<String, dynamic>{
          'status': 'processing',
          'isReadyForFeed': true,
          'canonicalPlaybackUrl': 'https://stream.mux.com/abc.m3u8',
        }),
        isNull,
      );
    });

    test('does not play ready videos without the explicit feed gate', () {
      expect(
        resolveReadyPlaybackUrl(<String, dynamic>{
          'status': 'ready',
          'canonicalPlaybackUrl': 'https://stream.mux.com/abc.m3u8',
        }),
        isNull,
      );
    });

    test('plays ready legacy hlsUrl videos', () {
      expect(
        resolveReadyPlaybackUrl(<String, dynamic>{
          'status': 'ready',
          'isReadyForFeed': true,
          'hlsUrl': 'https://stream.mux.com/abc.m3u8',
        }),
        'https://stream.mux.com/abc.m3u8',
      );
    });

    test('uses mp4Url before playbackUrl for ready videos', () {
      expect(
        resolveReadyPlaybackUrl(<String, dynamic>{
          'status': 'ready',
          'isReadyForFeed': true,
          'mp4Url': 'https://cdn.example.com/ready/video.mp4',
          'playbackUrl': 'https://cdn.example.com/ready/fallback.mp4',
        }),
        'https://cdn.example.com/ready/video.mp4',
      );
    });
  });
}
