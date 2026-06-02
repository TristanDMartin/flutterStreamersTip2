import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/video_player/application/video_cell_watchdog_tokens.dart';

void main() {
  test('firstFrameTimeoutMs differs by platform', () {
    expect(
      VideoCellWatchdogTokens.firstFrameTimeoutMs(
        platform: TargetPlatform.android,
      ),
      900,
    );
    expect(
      VideoCellWatchdogTokens.firstFrameTimeoutMs(
        platform: TargetPlatform.iOS,
      ),
      600,
    );
  });
}
