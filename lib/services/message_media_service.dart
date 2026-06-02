import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'logging_service.dart';

class MessageMediaService {
  static final MessageMediaService _instance = MessageMediaService._internal();
  factory MessageMediaService() => _instance;
  MessageMediaService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();

  // Supported media types
  static const List<String> supportedImageTypes = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp'
  ];
  static const List<String> supportedVideoTypes = [
    'mp4',
    'mov',
    'avi',
    'mkv',
    'webm'
  ];
  static const List<String> supportedAudioTypes = [
    'mp3',
    'wav',
    'aac',
    'm4a',
    'ogg'
  ];
  static const List<String> supportedDocumentTypes = [
    'pdf',
    'doc',
    'docx',
    'txt',
    'rtf'
  ];

  /// Upload image to Firebase Storage
  Future<String?> uploadImage(XFile imageFile, String chatId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';
      final path = 'chats/$chatId/images/$fileName';

      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(File(imageFile.path));

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      LoggingService.instance.info('Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      LoggingService.instance.error('Error uploading image: $e');
      return null;
    }
  }

  /// Upload video to Firebase Storage
  Future<String?> uploadVideo(XFile videoFile, String chatId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${videoFile.name}';
      final path = 'chats/$chatId/videos/$fileName';

      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(File(videoFile.path));

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      LoggingService.instance.info('Video uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      LoggingService.instance.error('Error uploading video: $e');
      return null;
    }
  }

  /// Upload audio to Firebase Storage
  Future<String?> uploadAudio(XFile audioFile, String chatId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${audioFile.name}';
      final path = 'chats/$chatId/audio/$fileName';

      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(File(audioFile.path));

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      LoggingService.instance.info('Audio uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      LoggingService.instance.error('Error uploading audio: $e');
      return null;
    }
  }

  /// Upload document to Firebase Storage
  Future<String?> uploadDocument(XFile documentFile, String chatId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${documentFile.name}';
      final path = 'chats/$chatId/documents/$fileName';

      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(File(documentFile.path));

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      LoggingService.instance
          .info('Document uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      LoggingService.instance.error('Error uploading document: $e');
      return null;
    }
  }

  /// Generate video thumbnail (simplified)
  Future<String?> generateVideoThumbnail(String videoPath) async {
    try {
      // Simplified thumbnail generation - in a real app, you'd use a proper video thumbnail library
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath =
          '${tempDir.path}/thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // For now, just return a placeholder path
      LoggingService.instance
          .info('Video thumbnail placeholder generated: $thumbnailPath');
      return thumbnailPath;
    } catch (e) {
      LoggingService.instance.error('Error generating video thumbnail: $e');
      return null;
    }
  }

  /// Upload video with thumbnail
  Future<Map<String, String>?> uploadVideoWithThumbnail(
      XFile videoFile, String chatId) async {
    try {
      // Upload video
      final videoUrl = await uploadVideo(videoFile, chatId);
      if (videoUrl == null) return null;

      // Generate and upload thumbnail
      final thumbnailPath = await generateVideoThumbnail(videoFile.path);
      String? thumbnailUrl;

      if (thumbnailPath != null) {
        final thumbnailFile = XFile(thumbnailPath);
        thumbnailUrl = await uploadImage(thumbnailFile, chatId);
      }

      return {
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl ?? '',
      };
    } catch (e) {
      LoggingService.instance.error('Error uploading video with thumbnail: $e');
      return null;
    }
  }

  /// Pick image from gallery
  Future<XFile?> pickImageFromGallery() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        LoggingService.instance
            .info('Image picked from gallery: ${image.path}');
      }

      return image;
    } catch (e) {
      LoggingService.instance.error('Error picking image from gallery: $e');
      return null;
    }
  }

  /// Pick image from camera
  Future<XFile?> pickImageFromCamera() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        LoggingService.instance.info('Image picked from camera: ${image.path}');
      }

      return image;
    } catch (e) {
      LoggingService.instance.error('Error picking image from camera: $e');
      return null;
    }
  }

  /// Pick video from gallery
  Future<XFile?> pickVideoFromGallery() async {
    try {
      final video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        LoggingService.instance
            .info('Video picked from gallery: ${video.path}');
      }

      return video;
    } catch (e) {
      LoggingService.instance.error('Error picking video from gallery: $e');
      return null;
    }
  }

  /// Pick video from camera
  Future<XFile?> pickVideoFromCamera() async {
    try {
      final video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        LoggingService.instance.info('Video picked from camera: ${video.path}');
      }

      return video;
    } catch (e) {
      LoggingService.instance.error('Error picking video from camera: $e');
      return null;
    }
  }

  /// Pick multiple images
  Future<List<XFile>> pickMultipleImages() async {
    try {
      final images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      LoggingService.instance.info('${images.length} images picked');
      return images;
    } catch (e) {
      LoggingService.instance.error('Error picking multiple images: $e');
      return [];
    }
  }

  /// Get file size in MB
  double getFileSizeInMB(String filePath) {
    try {
      final file = File(filePath);
      final bytes = file.lengthSync();
      return bytes / (1024 * 1024);
    } catch (e) {
      LoggingService.instance.error('Error getting file size: $e');
      return 0.0;
    }
  }

  /// Check if file type is supported
  bool isFileTypeSupported(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return supportedImageTypes.contains(extension) ||
        supportedVideoTypes.contains(extension) ||
        supportedAudioTypes.contains(extension) ||
        supportedDocumentTypes.contains(extension);
  }

  /// Get media type from file extension
  String getMediaType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    if (supportedImageTypes.contains(extension)) return 'image';
    if (supportedVideoTypes.contains(extension)) return 'video';
    if (supportedAudioTypes.contains(extension)) return 'audio';
    if (supportedDocumentTypes.contains(extension)) return 'document';

    return 'unknown';
  }

  /// Delete media from Firebase Storage
  Future<bool> deleteMedia(String mediaUrl) async {
    try {
      final ref = _storage.refFromURL(mediaUrl);
      await ref.delete();

      LoggingService.instance.info('Media deleted successfully: $mediaUrl');
      return true;
    } catch (e) {
      LoggingService.instance.error('Error deleting media: $e');
      return false;
    }
  }

  /// Get media metadata
  Future<Map<String, dynamic>?> getMediaMetadata(String mediaUrl) async {
    try {
      final ref = _storage.refFromURL(mediaUrl);
      final metadata = await ref.getMetadata();

      return {
        'name': metadata.name,
        'size': metadata.size,
        'contentType': metadata.contentType,
        'timeCreated': metadata.timeCreated?.toIso8601String(),
        'updated': metadata.updated?.toIso8601String(),
      };
    } catch (e) {
      LoggingService.instance.error('Error getting media metadata: $e');
      return null;
    }
  }

  /// Compress image
  Future<XFile?> compressImage(XFile imageFile) async {
    try {
      // This is a simplified compression - in a real app, you'd use a proper image compression library
      // For now, just return the original file
      // In production, you'd compress the image here
      LoggingService.instance
          .info('Image compression placeholder for: ${imageFile.path}');
      return imageFile;
    } catch (e) {
      LoggingService.instance.error('Error compressing image: $e');
      return imageFile;
    }
  }
}
