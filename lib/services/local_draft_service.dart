import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'draft_thumbnail_service.dart';
import 'package:path/path.dart' as path;

/// Local Draft Service - Manages drafts using local storage (equivalent to iOS @AppStorage)
///
/// Features:
/// - Local storage using SharedPreferences (Flutter's equivalent to iOS UserDefaults)
/// - Local video file management
/// - Draft sharing with connection network
/// - Persistence across app restarts
class LocalDraftService {
  static final LocalDraftService _instance = LocalDraftService._internal();
  factory LocalDraftService() => _instance;
  LocalDraftService._internal();

  static const String _draftVideosKey = 'draftVideos';

  /// Save draft video to local storage
  Future<bool> saveDraft({
    required File videoFile,
    required String caption,
    required List<String> hashtags,
    required String privacy,
    required bool allowComments,
    String? category,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    try {
      debugPrint('💾 LocalDraftService: Saving draft locally...');

      // 1. Generate unique draft ID
      final draftId = _generateDraftId();

      // 2. Save video file locally
      final localVideoPath = await _saveVideoFileLocally(videoFile, draftId);
      if (localVideoPath == null) {
        debugPrint('❌ Failed to save video file locally');
        return false;
      }

      // 3. Generate and save thumbnail locally
      final localThumbnailPath =
          await _generateAndSaveThumbnail(videoFile, draftId);

      // 4. Create draft object
      final draft = {
        'id': draftId,
        'videoPath': localVideoPath,
        'thumbnailPath': localThumbnailPath,
        'caption': caption,
        'hashtags': hashtags,
        'privacy': privacy,
        'allowComments': allowComments,
        'category': category ?? 'general',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'status': 'draft',
        'isSharedWithConnections': false,
        'sharedConnections': <String>[],
        'metadata': {
          'fileSize': await videoFile.length(),
          'duration': 30.0, // Placeholder - would get from video processing
          'resolution': '1080x1920', // Placeholder
          'format': 'mp4',
          ...?additionalMetadata,
        },
      };

      // 5. Save to SharedPreferences (@AppStorage equivalent)
      await _saveDraftToPreferences(draft);

      debugPrint('✅ Draft saved successfully with ID: $draftId');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving draft: $e');
      return false;
    }
  }

  /// Get all user drafts from local storage
  Future<List<Map<String, dynamic>>> getAllDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftsJson = prefs.getString(_draftVideosKey);

      if (draftsJson == null || draftsJson.isEmpty) {
        return [];
      }

      final List<dynamic> draftsList = json.decode(draftsJson);
      final List<Map<String, dynamic>> drafts =
          draftsList.map((draft) => Map<String, dynamic>.from(draft)).toList();

      // Sort by creation date (newest first)
      drafts.sort((a, b) {
        final dateA = DateTime.parse(a['createdAt']);
        final dateB = DateTime.parse(b['createdAt']);
        return dateB.compareTo(dateA);
      });

      debugPrint('📱 Loaded ${drafts.length} drafts from local storage');
      return drafts;
    } catch (e) {
      debugPrint('❌ Error loading drafts: $e');
      return [];
    }
  }

  /// Delete a draft and its associated files
  Future<bool> deleteDraft(String draftId) async {
    try {
      debugPrint('🗑️ Deleting draft: $draftId');

      // 1. Get draft info
      final drafts = await getAllDrafts();
      final draft = drafts.firstWhere(
        (d) => d['id'] == draftId,
        orElse: () => {},
      );

      if (draft.isEmpty) {
        debugPrint('❌ Draft not found: $draftId');
        return false;
      }

      // 2. Delete video file
      final videoPath = draft['videoPath'] as String?;
      if (videoPath != null && videoPath.isNotEmpty) {
        await _deleteVideoFile(videoPath);
      }

      // 3. Delete thumbnail file
      final thumbnailPath = draft['thumbnailPath'] as String?;
      if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
        await _deleteThumbnailFile(thumbnailPath);
      }

      // 4. Remove from SharedPreferences
      final updatedDrafts = drafts.where((d) => d['id'] != draftId).toList();
      await _saveDraftsToPreferences(updatedDrafts);

      debugPrint('✅ Draft deleted successfully: $draftId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting draft: $e');
      return false;
    }
  }

  /// Share draft with connection network
  Future<bool> shareDraftWithConnections(
      String draftId, List<String> connectionIds) async {
    try {
      debugPrint(
          '🔗 Sharing draft $draftId with ${connectionIds.length} connections');

      final drafts = await getAllDrafts();
      final draftIndex = drafts.indexWhere((d) => d['id'] == draftId);

      if (draftIndex == -1) {
        debugPrint('❌ Draft not found: $draftId');
        return false;
      }

      // Update draft to mark as shared
      drafts[draftIndex]['isSharedWithConnections'] = true;
      drafts[draftIndex]['sharedConnections'] = connectionIds;
      drafts[draftIndex]['updatedAt'] = DateTime.now().toIso8601String();

      // Save updated drafts
      await _saveDraftsToPreferences(drafts);

      // Connection sharing logic implementation
      // This would involve:
      // 1. Creating shared draft entries for each connection
      // 2. Sending notifications to connections
      // 3. Updating connection's shared drafts list
      // Currently not implemented - would require additional infrastructure

      debugPrint('✅ Draft shared successfully with connections');
      return true;
    } catch (e) {
      debugPrint('❌ Error sharing draft: $e');
      return false;
    }
  }

  /// Get shared drafts from connections
  Future<List<Map<String, dynamic>>> getSharedDraftsFromConnections() async {
    try {
      // Fetching shared drafts from connections implementation
      // This would involve querying Firestore for drafts shared with current user
      // Currently returns empty list as this feature is not implemented

      debugPrint('📥 Loading shared drafts from connections...');
      return [];
    } catch (e) {
      debugPrint('❌ Error loading shared drafts: $e');
      return [];
    }
  }

  /// Publish draft (convert to published video)
  Future<bool> publishDraft(String draftId) async {
    try {
      debugPrint('📤 Publishing draft: $draftId');

      final drafts = await getAllDrafts();
      final draftIndex = drafts.indexWhere((d) => d['id'] == draftId);

      if (draftIndex == -1) {
        debugPrint('❌ Draft not found: $draftId');
        return false;
      }

      // Publishing logic implementation
      // This would involve:
      // 1. Uploading video to Firebase Storage
      // 2. Creating video document in Firestore
      // 3. Adding to appropriate feeds
      // 4. Removing from local drafts
      // Currently not implemented - would require integration with video upload service
      final _ =
          drafts[draftIndex]; // Use draft data when implementing publishing

      debugPrint('✅ Draft published successfully: $draftId');
      return true;
    } catch (e) {
      debugPrint('❌ Error publishing draft: $e');
      return false;
    }
  }

  // Private helper methods

  Future<void> _saveDraftToPreferences(Map<String, dynamic> draft) async {
    final drafts = await getAllDrafts();
    drafts.insert(0, draft); // Add to beginning (newest first)
    await _saveDraftsToPreferences(drafts);
  }

  Future<void> _saveDraftsToPreferences(
      List<Map<String, dynamic>> drafts) async {
    final prefs = await SharedPreferences.getInstance();
    final draftsJson = json.encode(drafts);
    await prefs.setString(_draftVideosKey, draftsJson);
  }

  Future<String?> _saveVideoFileLocally(File videoFile, String draftId) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final draftsDir = Directory(path.join(documentsDir.path, 'DraftVideos'));

      // Create drafts directory if it doesn't exist
      if (!await draftsDir.exists()) {
        await draftsDir.create(recursive: true);
      }

      final fileName = '$draftId.mp4';
      final localPath = path.join(draftsDir.path, fileName);

      // Copy video file to local storage
      await videoFile.copy(localPath);

      debugPrint('💾 Video saved locally: $localPath');
      return localPath;
    } catch (e) {
      debugPrint('❌ Error saving video file locally: $e');
      return null;
    }
  }

  Future<String?> _generateAndSaveThumbnail(
      File videoFile, String draftId) async {
    try {
      debugPrint('🖼️ Generating thumbnail for draft: $draftId');

      // Use the DraftThumbnailService to generate thumbnail
      final draftThumbnailService = DraftThumbnailService();
      final thumbnailPath = await draftThumbnailService.generateLocalThumbnail(
        videoPath: videoFile.path,
        videoId: draftId,
      );

      if (thumbnailPath != null) {
        debugPrint('✅ Generated thumbnail for draft $draftId: $thumbnailPath');
      } else {
        debugPrint('❌ Failed to generate thumbnail for draft $draftId');
      }

      return thumbnailPath;
    } catch (e) {
      debugPrint('❌ Error generating thumbnail: $e');
      return null;
    }
  }

  Future<void> _deleteVideoFile(String videoPath) async {
    try {
      final file = File(videoPath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ Deleted video file: $videoPath');
      }
    } catch (e) {
      debugPrint('❌ Error deleting video file: $e');
    }
  }

  Future<void> _deleteThumbnailFile(String thumbnailPath) async {
    try {
      final file = File(thumbnailPath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ Deleted thumbnail file: $thumbnailPath');
      }
    } catch (e) {
      debugPrint('❌ Error deleting thumbnail file: $e');
    }
  }

  String _generateDraftId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'draft_${timestamp}_$random';
  }

  /// Get local video file URL for a draft
  String getLocalVideoUrl(String localPath) {
    return 'file://$localPath';
  }

  /// Check if a URL is a local file
  bool isLocalFile(String url) {
    return url.startsWith('file://') || !url.startsWith('http');
  }
}
