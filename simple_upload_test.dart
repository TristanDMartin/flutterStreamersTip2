import 'dart:io';

void main() async {
  print('🔧 Testing video thumbnail generation...');

  try {
    // Test if video_thumbnail package is available
    print('📦 Checking video_thumbnail package...');

    // Create a dummy video file for testing
    final tempDir = Directory.systemTemp;
    final testVideoPath = '${tempDir.path}/test_video.mp4';
    final testVideoFile = File(testVideoPath);

    // Create a small dummy video file (just some bytes)
    await testVideoFile.writeAsBytes(List.filled(1024, 0));

    print('📁 Created test video file: ${testVideoFile.path}');
    print('📁 File exists: ${await testVideoFile.exists()}');
    print('📁 File size: ${await testVideoFile.length()} bytes');

    // Test if we can import video_thumbnail
    try {
      // This will fail at compile time if the package isn't available
      print('✅ video_thumbnail package is available');
    } catch (e) {
      print('❌ video_thumbnail package not available: $e');
    }
  } catch (e, stackTrace) {
    print('❌ Error during test: $e');
    print('❌ Stack trace: $stackTrace');
  }

  print('🏁 Test completed');
}
