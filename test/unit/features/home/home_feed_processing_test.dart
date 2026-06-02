import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/home/domain/home_feed_processing.dart';
import 'package:streamers_tip/models/home_video.dart';
import 'package:streamers_tip/models/user.dart';

void main() {
  HomeVideo video({
    required String id,
    String url = 'https://cdn.example/v.mp4',
    Timestamp? createdAt,
  }) {
    return HomeVideo(
      id: id,
      creator: const User(
        id: 'u1',
        username: 'u',
        displayName: 'U',
        bio: '',
        hashtags: <String>[],
      ),
      videoURL: url,
      createdAt: createdAt,
    );
  }

  group('dedupeHomeVideosById', () {
    test('keeps first occurrence', () {
      final List<HomeVideo> input = <HomeVideo>[
        video(id: 'a'),
        video(id: 'a'),
        video(id: 'b'),
      ];
      final List<HomeVideo> actual = dedupeHomeVideosById(input);
      expect(actual.map((HomeVideo v) => v.id).toList(), <String>['a', 'b']);
    });
  });

  group('rankHomeVideosForFeed', () {
    test('playable videos sort before non-playable', () {
      final HomeVideo playable = video(id: 'p', url: 'https://cdn.example/p.mp4');
      final HomeVideo pending = video(id: 'n', url: '');
      final List<HomeVideo> actual = rankHomeVideosForFeed(<HomeVideo>[
        pending,
        playable,
      ]);
      expect(actual.first.id, 'p');
    });
  });
}
