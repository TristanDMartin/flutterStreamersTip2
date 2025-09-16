import 'package:flutter/material.dart';
import '../widgets/capture_button.dart';

/// Demo page showcasing the CaptureButton widget
class CaptureButtonDemo extends StatefulWidget {
  const CaptureButtonDemo({super.key});

  @override
  State<CaptureButtonDemo> createState() => _CaptureButtonDemoState();
}

class _CaptureButtonDemoState extends State<CaptureButtonDemo> {
  int _recordCount = 0;
  int _tapCount = 0;
  String _lastAction = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Capture Button Demo'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Main capture button (tap to record/stop)
            const Text(
              'Tap to Record/Stop',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            
            CaptureButton(
              size: 72,
              ringWidth: 8,
              duration: const Duration(seconds: 10),
              onStart: () {
                setState(() {
                  _recordCount++;
                  _lastAction = 'Recording started...';
                });
              },
              onFinish: () {
                setState(() {
                  _lastAction = 'Recording finished!';
                });
              },
            ),
            
            const SizedBox(height: 40),
            
            // Simple tap button
            const Text(
              'Simple Tap Button',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            
            CaptureButton(
              size: 64,
              ringWidth: 6,
              onTap: () {
                setState(() {
                  _tapCount++;
                  _lastAction = 'Tapped $_tapCount times';
                });
              },
              onStart: () {}, // Required but not used
              onFinish: () {}, // Required but not used
            ),
            
            const SizedBox(height: 40),
            
            // Stats
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Records: $_recordCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Taps: $_tapCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last Action: $_lastAction',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Reset button
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _recordCount = 0;
                  _tapCount = 0;
                  _lastAction = 'Reset';
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9248D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Reset Counters'),
            ),
          ],
        ),
      ),
    );
  }
}
