import 'dart:async' show TimeoutException;

import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/video_player/application/video_cell_init_error_classifier.dart';

void main() {
  group('VideoCellInitErrorClassifier', () {
    const VideoCellInitErrorClassifier classifier =
        VideoCellInitErrorClassifier();

    test('classify detects timeout', () {
      expect(
        classifier.classify(TimeoutException('slow')),
        VideoCellInitErrorKind.timeout,
      );
    });

    test('classify detects format errors', () {
      expect(
        classifier.classify(Exception('codec mime type not supported')),
        VideoCellInitErrorKind.format,
      );
    });

    test('classify detects network retry', () {
      expect(
        classifier.classify(Exception('SocketException: failed host lookup')),
        VideoCellInitErrorKind.networkRetry,
      );
    });

    test('userFriendlyMessage maps network errors', () {
      expect(
        classifier.userFriendlyMessage(Exception('network unreachable')),
        'Network connection issue',
      );
    });
  });
}
