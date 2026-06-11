import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('overlay entry removes after animation callback', (
    WidgetTester tester,
  ) async {
    var removed = false;
    late OverlayEntry entry;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              entry = OverlayEntry(
                builder: (BuildContext context) => IgnorePointer(
                  child: _TestHeartOverlay(
                    onComplete: () {
                      entry.remove();
                      removed = true;
                    },
                  ),
                ),
              );
              Overlay.of(context).insert(entry);
            });
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(removed, isFalse);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(removed, isTrue);
  });
}

class _TestHeartOverlay extends StatefulWidget {
  const _TestHeartOverlay({required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<_TestHeartOverlay> createState() => _TestHeartOverlayState();
}

class _TestHeartOverlayState extends State<_TestHeartOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
