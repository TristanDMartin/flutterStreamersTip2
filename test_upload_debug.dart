import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  print('🔧 Testing video thumbnail generation...');

  // Test video thumbnail generation
  try {
    final tempDir = Directory.systemTemp;
    final testVideoPath = '${tempDir.path}/test_video.mp4';
    final thumbnailPath = '${tempDir.path}/test_thumbnail.jpg';

    // Create a dummy video file for testing
    final testVideoFile = File(testVideoPath);
    await testVideoFile.writeAsBytes(List.filled(1024, 0)); // 1KB dummy file

    print('📁 Created test video file: ${testVideoFile.path}');
    print('📁 File exists: ${await testVideoFile.exists()}');
    print('📁 File size: ${await testVideoFile.length()} bytes');

    // Test thumbnail generation
    print('🖼️ Generating thumbnail...');
    final result = await VideoThumbnail.thumbnailFile(
      video: testVideoPath,
      thumbnailPath: thumbnailPath,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 320,
      maxHeight: 240,
      timeMs: 1000,
      quality: 85,
    );

    print('🖼️ Thumbnail result: $result');

    if (result != null) {
      final thumbnailFile = File(result);
      print('🖼️ Thumbnail file exists: ${await thumbnailFile.exists()}');
      if (await thumbnailFile.exists()) {
        print('🖼️ Thumbnail file size: ${await thumbnailFile.length()} bytes');
      }
    }

    // Test Firebase Storage
    print('🔥 Testing Firebase Storage...');
    final storage = FirebaseStorage.instance;
    final ref = storage.ref().child('test_thumbnails/test.jpg');

    if (result != null && await File(result).exists()) {
      print('📤 Uploading thumbnail to Firebase Storage...');
      await ref.putFile(File(result));
      final downloadUrl = await ref.getDownloadURL();
      print('✅ Thumbnail uploaded successfully: $downloadUrl');
    } else {
      print('❌ No thumbnail to upload');
    }
  } catch (e, stackTrace) {
    print('❌ Error during test: $e');
    print('❌ Stack trace: $stackTrace');
  }

  print('🏁 Test completed');
}
