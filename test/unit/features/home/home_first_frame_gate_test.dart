import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/home/application/home_first_frame_gate.dart';

void main() {
  test('runAfterFirstFrame executes after markFirstFrameRendered', () async {
    final HomeFirstFrameGate gate = HomeFirstFrameGate.instance;
    gate.resetForTest();
    addTearDown(gate.resetForTest);
    var executed = false;
    gate.runAfterFirstFrame(() {
      executed = true;
    });
    expect(executed, isFalse);
    gate.markFirstFrameRendered(videoId: 'video-1', source: 'test');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(executed, isTrue);
  });
}
