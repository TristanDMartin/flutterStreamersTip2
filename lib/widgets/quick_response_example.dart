import 'package:flutter/material.dart';
import '../utils/quick_response_button.dart';

class QuickResponseExample extends StatelessWidget {
  const QuickResponseExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Response Button Examples'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Basic Quick Response Button
            QuickResponseButton(
              onPressed: () {
    // print('Basic button tapped!');
              },
              child: const Text(
                'Basic Quick Response Button',
                style: TextStyle(fontSize: 16),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Custom styled button
            QuickResponseButton(
              onPressed: () {
    // print('Custom styled button tapped!');
              },
              style: const QuickResponseButtonStyle(),
              child: const Text(
                'Custom Styled Button',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Using the extension method
            const Text('Using Extension Methods:')
                .quickResponseButton(
                  onPressed: () {
    // print('Extension method button tapped!');
                  },
                ),
            
            const SizedBox(height: 16),
            
            // Haptic feedback example
            const Text('Haptic Feedback Button')
                .hapticFeedback(
                  onTap: () {
    // print('Haptic feedback button tapped!');
                  },
                  type: HapticFeedbackType.mediumImpact,
                ),
            
            const SizedBox(height: 16),
            
            // Always responsive example
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Always Responsive Area',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ).alwaysResponsive(
              onTap: () {
    // print('Always responsive area tapped!');
              },
            ),
            
            const SizedBox(height: 16),
            
            // Custom corner radius example
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Custom Corner Radius',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ).cornerRadius(16, [Corner.topLeft, Corner.bottomRight]),
            
            const SizedBox(height: 16),
            
            // Haptic feedback utility examples
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => HapticFeedbackUtil.light(),
                  child: const Text('Light'),
                ),
                ElevatedButton(
                  onPressed: () => HapticFeedbackUtil.medium(),
                  child: const Text('Medium'),
                ),
                ElevatedButton(
                  onPressed: () => HapticFeedbackUtil.heavy(),
                  child: const Text('Heavy'),
                ),
                ElevatedButton(
                  onPressed: () => HapticFeedbackUtil.success(),
                  child: const Text('Success'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
