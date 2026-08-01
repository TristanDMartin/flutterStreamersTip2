import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/feed/domain/discover_category_card_map.dart';
import 'package:streamers_tip/models/home_video.dart';
import 'package:streamers_tip/models/user.dart';
import 'package:streamers_tip/utils/video_url_resolver.dart';

HomeVideo _video({String? thumbnailURL, String videoURL = ''}) {
  return HomeVideo(
    id: 'v1',
    creator: const User(
      id: 'u1',
      username: 'streamer_one',
      displayName: 'Streamer One',
      avatarURL: 'https://example.com/avatar.jpg',
    ),
    videoURL: videoURL,
    thumbnailURL: thumbnailURL,
    likes: 42,
    views: 100,
    status: 'ready',
  );
}

void main() {
  test('fromHomeVideo maps thumbnail username likes and playback', () {
    final Map<String, dynamic> card = DiscoverCategoryCardMap.fromHomeVideo(
      _video(
        thumbnailURL: 'https://cdn.example.com/thumb.jpg',
        videoURL: 'https://stream.mux.com/abc123.m3u8',
      ),
    );
    expect(card['thumbnailUrl'], 'https://cdn.example.com/thumb.jpg');
    expect(card['creatorUsername'], 'streamer_one');
    expect(card['likes'], 42);
    expect(card['videoUrl'], contains('mux.com'));
    expect(card['isReadyForFeed'], isTrue);
    expect(card['status'], 'ready');
  });

  test('fromHomeVideo cards pass resolveReadyPlaybackUrl for grid filter', () {
    final Map<String, dynamic> card = DiscoverCategoryCardMap.fromHomeVideo(
      _video(videoURL: 'https://stream.mux.com/abc123.m3u8'),
    );
    expect(resolveReadyPlaybackUrl(card), isNotNull);
    final Map<String, dynamic> nested =
        card['data'] as Map<String, dynamic>;
    expect(resolveReadyPlaybackUrl(nested), isNotNull);
  });

  test('resolveDiscoverThumbnailUrl derives mux poster when legacy empty', () {
    final String url = resolveDiscoverThumbnailUrl(
      _video(videoURL: 'https://stream.mux.com/xyz789.m3u8'),
    );
    expect(url, contains('image.mux.com/xyz789'));
  });
}
