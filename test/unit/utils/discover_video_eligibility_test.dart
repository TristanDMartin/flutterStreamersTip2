import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/utils/video_document_rules.dart';

void main() {
  group('isDiscoverEligibleFromFirestore', () {
    test('rejects processing without playable url', () {
      expect(
        isDiscoverEligibleFromFirestore(<String, dynamic>{
          'status': 'processing',
          'visibility': 'public',
          'ownerId': 'abc123owner0000000000000001',
        }),
        isFalse,
      );
    });

    test('allows ready public video with hls', () {
      expect(
        isDiscoverEligibleFromFirestore(<String, dynamic>{
          'status': 'ready',
          'isReadyForFeed': true,
          'visibility': 'public',
          'ownerId': 'abc123owner0000000000000001',
          'hlsUrl': 'https://stream.mux.com/abc.m3u8',
        }),
        isTrue,
      );
    });

    test('rejects private video', () {
      expect(
        isDiscoverEligibleFromFirestore(<String, dynamic>{
          'status': 'ready',
          'isReadyForFeed': true,
          'privacy': 'Only Me',
          'ownerId': 'abc123owner0000000000000001',
          'videoUrl': 'https://stream.mux.com/abc.m3u8',
        }),
        isFalse,
      );
    });
  });
}
