import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'local_draft_service.dart';
import 'chat_service.dart';

enum DraftShareFailureReason {
  unauthenticated,
  missingDraftId,
  noRecipients,
  recipientNotFound,
  draftNotFound,
  mediaPersistenceFailed,
  firestoreWriteFailed,
  unexpected,
}

class DraftShareResult {
  final bool isSuccess;
  final List<String> verifiedRecipientIds;
  final List<String> failedRecipientIds;
  final String? sharedDraftId;
  final DraftShareFailureReason? failureReason;
  final String? message;

  const DraftShareResult._({
    required this.isSuccess,
    this.verifiedRecipientIds = const [],
    this.failedRecipientIds = const [],
    this.sharedDraftId,
    this.failureReason,
    this.message,
  });

  const DraftShareResult.success({
    required String sharedDraftId,
    required List<String> verifiedRecipientIds,
    List<String> failedRecipientIds = const [],
    String? message,
  }) : this._(
          isSuccess: true,
          sharedDraftId: sharedDraftId,
          verifiedRecipientIds: verifiedRecipientIds,
          failedRecipientIds: failedRecipientIds,
          message: message,
        );

  const DraftShareResult.failure({
    required DraftShareFailureReason reason,
    String? message,
    List<String> verifiedRecipientIds = const [],
    List<String> failedRecipientIds = const [],
  }) : this._(
          isSuccess: false,
          failureReason: reason,
          message: message,
          verifiedRecipientIds: verifiedRecipientIds,
          failedRecipientIds: failedRecipientIds,
        );
}

/// Draft Sharing Service - Handles sharing drafts with connection network
///
/// Features:
/// - Share drafts with specific connections
/// - Receive shared drafts from connections
/// - Manage draft sharing permissions
/// - Real-time updates for shared drafts
class DraftSharingService {
  static final DraftSharingService _instance = DraftSharingService._internal();
  factory DraftSharingService() => _instance;
  DraftSharingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final LocalDraftService _localDraftService = LocalDraftService();
  final ChatService _chatService = ChatService.shared;

  /// Share a local draft with connection network
  Future<DraftShareResult> shareDraftWithConnections({
    required String draftId,
    required List<String> connectionIds,
    String? message,
  }) async {
    try {
      debugPrint(
          '🔗 DraftSharingService: Sharing draft $draftId with ${connectionIds.length} connections');

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ User not authenticated');
        return const DraftShareResult.failure(
          reason: DraftShareFailureReason.unauthenticated,
          message: 'You need to sign in before sharing drafts.',
        );
      }

      // Validate draft ID
      if (draftId.isEmpty) {
        debugPrint('❌ Draft ID is empty');
        return const DraftShareResult.failure(
          reason: DraftShareFailureReason.missingDraftId,
          message: 'This draft is missing its ID.',
        );
      }

      // Filter out empty connection IDs
      final validConnectionIds =
          connectionIds.where((id) => id.isNotEmpty).toList();
      if (validConnectionIds.isEmpty) {
        debugPrint('❌ No valid connection IDs provided');
        return const DraftShareResult.failure(
          reason: DraftShareFailureReason.noRecipients,
          message: 'Choose at least one valid person to share with.',
        );
      }

      // Verify all recipient users exist in Firestore before sharing
      final verifiedConnectionIds = <String>[];
      for (final recipientId in validConnectionIds) {
        try {
          final userDoc =
              await _firestore.collection('users').doc(recipientId).get();
          if (userDoc.exists && userDoc.data() != null) {
            verifiedConnectionIds.add(recipientId);
            debugPrint('✅ Verified user exists: $recipientId');
          } else {
            debugPrint('⚠️ User does not exist in Firestore: $recipientId');
          }
        } catch (e) {
          debugPrint('❌ Error verifying user $recipientId: $e');
        }
      }

      if (verifiedConnectionIds.isEmpty) {
        debugPrint(
            '❌ No valid users found to share with (all users may not exist in Firestore)');
        return const DraftShareResult.failure(
          reason: DraftShareFailureReason.recipientNotFound,
          message:
              'The selected person is not available for draft sharing yet.',
        );
      }

      if (verifiedConnectionIds.length < validConnectionIds.length) {
        debugPrint(
            '⚠️ Only ${verifiedConnectionIds.length} of ${validConnectionIds.length} users exist in Firestore');
      }

      // 1. Get draft from local storage
      final drafts = await _localDraftService.getAllDrafts();
      final draft = drafts.firstWhere(
        (d) => d['id'] == draftId,
        orElse: () => {},
      );

      if (draft.isEmpty) {
        debugPrint('❌ Draft not found locally: $draftId');
        return const DraftShareResult.failure(
          reason: DraftShareFailureReason.draftNotFound,
          message: 'This draft is no longer available on this device.',
        );
      }

      // 2. Persist the draft media to a canonical storage path before sharing.
      final persistedAssets = await _persistDraftAssets(
        ownerId: currentUser.uid,
        draftId: draftId,
        draft: draft,
      );

      if (persistedAssets['videoUrl']?.isNotEmpty != true) {
        debugPrint('❌ Failed to persist shared draft media');
        return const DraftShareResult.failure(
          reason: DraftShareFailureReason.mediaPersistenceFailed,
          message: 'We could not prepare the draft media for sharing.',
        );
      }

      // 3. Create shared draft document in Firestore (only with verified recipients)
      final sharedDraftId = _generateSharedDraftId();
      if (sharedDraftId.isEmpty) {
        debugPrint('❌ Failed to generate shared draft ID');
        return const DraftShareResult.failure(
          reason: DraftShareFailureReason.unexpected,
          message: 'We could not create a share record for this draft.',
        );
      }

      final duration = _resolveDraftDuration(draft);
      final persistedThumbnailUrl = persistedAssets['thumbnailUrl'] ?? '';

      final sharedDraftData = {
        'id': sharedDraftId,
        'canonicalDraftId': draftId,
        'originalDraftId': draftId,
        'sharerId': currentUser.uid,
        'sharerUsername': currentUser.displayName ?? 'Unknown',
        'sharerAvatarUrl': currentUser.photoURL ?? '',
        'recipients': verifiedConnectionIds, // Use verified recipients only
        'draftTitle': (draft['caption'] as String?)?.trim().isNotEmpty == true
            ? draft['caption']
            : 'Untitled Draft',
        'draftThumbnailUrl': persistedThumbnailUrl,
        'draftDuration': duration,
        'caption': draft['caption'],
        'hashtags': draft['hashtags'],
        'category': draft['category'],
        'privacy': draft['privacy'],
        'allowComments': draft['allowComments'],
        'message': message ?? '',
        'status': 'shared',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'metadata': draft['metadata'],
        'videoUrl': persistedAssets['videoUrl'],
        'thumbnailUrl': persistedThumbnailUrl,
        'videoStoragePath': persistedAssets['videoStoragePath'],
        'thumbnailStoragePath': persistedAssets['thumbnailStoragePath'],
        'assetSource': 'firebase_storage',
        'assetPersistedAt': FieldValue.serverTimestamp(),
      };

      // 4. Save shared draft to Firestore
      try {
        await _firestore
            .collection('shared_drafts')
            .doc(sharedDraftId)
            .set(sharedDraftData);
      } catch (e) {
        debugPrint('❌ Failed to save shared draft to Firestore: $e');
        return DraftShareResult.failure(
          reason: DraftShareFailureReason.firestoreWriteFailed,
          message: 'We could not save the shared draft right now.',
          verifiedRecipientIds: verifiedConnectionIds,
        );
      }

      // 5. Update local draft to mark as shared
      await _localDraftService.shareDraftWithConnections(
          draftId, verifiedConnectionIds);
      await _localDraftService.updateDraftFields(draftId, {
        'sharedDraftId': sharedDraftId,
        'canonicalDraftId': draftId,
        'videoUrl': persistedAssets['videoUrl'],
        'thumbnailUrl': persistedThumbnailUrl,
        'metadata': {
          'videoStoragePath': persistedAssets['videoStoragePath'],
          'thumbnailStoragePath': persistedAssets['thumbnailStoragePath'],
          'assetSource': 'firebase_storage',
        },
      });

      // 6. Create chat conversations and send draft messages for each verified recipient
      final failedRecipients = <String>[];
      for (final recipientId in verifiedConnectionIds) {
        try {
          await _createDraftChatConversation(
            sharedDraftId: sharedDraftId,
            recipientId: recipientId,
            draft: draft,
            persistedAssets: persistedAssets,
            message: message,
          );
        } catch (e) {
          debugPrint(
              '❌ Failed to create chat conversation for $recipientId: $e');
          failedRecipients.add(recipientId);
        }
      }

      if (failedRecipients.isNotEmpty) {
        debugPrint(
            '⚠️ Failed to create chat conversations for ${failedRecipients.length} recipients: $failedRecipients');
        // Don't fail the entire operation if some chats fail, but log it
      }

      // 7. Activity notifications are server-only — Cloud Function
      // onSharedDraftCreate reads shared_drafts/{sharedDraftId}.recipients
      // and writes notifications/{recipientId}/items for each.

      debugPrint(
          '✅ Draft shared successfully with ${verifiedConnectionIds.length} verified connections');
      return DraftShareResult.success(
        sharedDraftId: sharedDraftId,
        verifiedRecipientIds: verifiedConnectionIds,
        failedRecipientIds: failedRecipients,
        message: failedRecipients.isEmpty
            ? null
            : 'Draft shared, but ${failedRecipients.length} chat thread(s) could not be created automatically.',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error sharing draft: $e');
      debugPrint('❌ Stack trace: $stackTrace');

      // Provide more specific error information
      if (e.toString().contains('permission-denied')) {
        debugPrint('❌ Permission denied - check Firestore rules');
      } else if (e.toString().contains('not-found')) {
        debugPrint('❌ User document not found in Firestore');
      } else if (e.toString().contains('invalid-argument')) {
        debugPrint('❌ Invalid argument - check user IDs');
      }

      return DraftShareResult.failure(
        reason: DraftShareFailureReason.unexpected,
        message: e.toString(),
      );
    }
  }

  /// Get drafts shared with current user
  Future<List<Map<String, dynamic>>> getSharedDraftsWithMe() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      debugPrint('📥 Loading drafts shared with me...');

      final snapshot = await _firestore
          .collection('shared_drafts')
          .where('recipients', arrayContains: currentUser.uid)
          .where('status', isEqualTo: 'shared')
          .orderBy('createdAt', descending: true)
          .get();

      final sharedDrafts = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      debugPrint('📥 Found ${sharedDrafts.length} shared drafts');
      return sharedDrafts;
    } catch (e) {
      debugPrint('❌ Error loading shared drafts: $e');
      return [];
    }
  }

  /// Get drafts shared by current user
  Future<List<Map<String, dynamic>>> getDraftsSharedByMe() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      debugPrint('📤 Loading drafts shared by me...');

      final snapshot = await _firestore
          .collection('shared_drafts')
          .where('sharerId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'shared')
          .orderBy('createdAt', descending: true)
          .get();

      final sharedDrafts = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      debugPrint('📤 Found ${sharedDrafts.length} drafts shared by me');
      return sharedDrafts;
    } catch (e) {
      debugPrint('❌ Error loading drafts shared by me: $e');
      return [];
    }
  }

  /// Accept a shared draft (save to local storage)
  Future<bool> acceptSharedDraft(String sharedDraftId) async {
    try {
      debugPrint('✅ Accepting shared draft: $sharedDraftId');

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ User not authenticated');
        return false;
      }

      // Validate shared draft ID
      if (sharedDraftId.isEmpty) {
        debugPrint('❌ Shared draft ID is empty');
        return false;
      }

      // 1. Get shared draft data
      final doc =
          await _firestore.collection('shared_drafts').doc(sharedDraftId).get();

      if (!doc.exists) {
        debugPrint('❌ Shared draft not found: $sharedDraftId');
        return false;
      }

      final sharedDraftData = doc.data()!;

      // 2. Check if user is in recipients list
      final recipients = List<String>.from(sharedDraftData['recipients'] ?? []);
      if (!recipients.contains(currentUser.uid)) {
        debugPrint('❌ User not authorized to accept this draft');
        return false;
      }

      // 3. Request video file from sharer
      final videoFile = await _requestVideoFileFromSharer(
        sharedDraftId: sharedDraftId,
        sharedDraftData: sharedDraftData,
      );

      if (videoFile == null) {
        debugPrint('❌ Failed to get video file from sharer');
        return false;
      }

      // 4. Save as local draft
      final success = await _localDraftService.saveDraft(
        videoFile: videoFile,
        caption: sharedDraftData['caption'] ?? '',
        hashtags: List<String>.from(sharedDraftData['hashtags'] ?? []),
        privacy: sharedDraftData['privacy'] ?? 'Everyone',
        allowComments: sharedDraftData['allowComments'] ?? true,
        category: sharedDraftData['category'],
        additionalMetadata: {
          'sharedFrom': sharedDraftData['sharerId'],
          'sharedDraftId': sharedDraftId,
          'originalDraftId': sharedDraftData['originalDraftId'],
          'canonicalDraftId': sharedDraftData['canonicalDraftId'],
          'videoUrl': sharedDraftData['videoUrl'],
          'thumbnailUrl': sharedDraftData['thumbnailUrl'],
          'acceptedAt': DateTime.now().toIso8601String(),
        },
      );

      if (success) {
        // 5. Update shared draft status
        await _firestore.collection('shared_drafts').doc(sharedDraftId).update({
          'acceptedBy': FieldValue.arrayUnion([currentUser.uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint('✅ Shared draft accepted successfully');
        return true;
      } else {
        debugPrint('❌ Failed to save shared draft locally');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error accepting shared draft: $e');
      return false;
    }
  }

  /// Decline a shared draft
  Future<bool> declineSharedDraft(String sharedDraftId) async {
    try {
      debugPrint('❌ Declining shared draft: $sharedDraftId');

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ User not authenticated');
        return false;
      }

      // Validate shared draft ID
      if (sharedDraftId.isEmpty) {
        debugPrint('❌ Shared draft ID is empty');
        return false;
      }

      // Update shared draft to mark as declined
      await _firestore.collection('shared_drafts').doc(sharedDraftId).update({
        'declinedBy': FieldValue.arrayUnion([currentUser.uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Shared draft declined successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error declining shared draft: $e');
      return false;
    }
  }

  /// Request video file from sharer
  Future<File?> _requestVideoFileFromSharer({
    required String sharedDraftId,
    required Map<String, dynamic> sharedDraftData,
  }) async {
    try {
      final videoUrl = sharedDraftData['videoUrl'] as String?;
      if (videoUrl == null || videoUrl.isEmpty) {
        debugPrint('⚠️ Shared draft is missing a canonical video URL');
        return null;
      }

      debugPrint('📥 Downloading shared draft video from canonical storage');

      final response = await http.get(Uri.parse(videoUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
            '❌ Failed to download shared draft video: ${response.statusCode}');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final extension = path.extension(Uri.parse(videoUrl).path).isNotEmpty
          ? path.extension(Uri.parse(videoUrl).path)
          : '.mp4';
      final localFile = File(
        path.join(tempDir.path, '${sharedDraftId}_accepted$extension'),
      );

      await localFile.writeAsBytes(response.bodyBytes, flush: true);
      return localFile;
    } catch (e) {
      debugPrint('❌ Error requesting video file: $e');
      return null;
    }
  }

  /// Create chat conversation and send draft message
  Future<void> _createDraftChatConversation({
    required String sharedDraftId,
    required String recipientId,
    required Map<String, dynamic> draft,
    required Map<String, String> persistedAssets,
    String? message,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Validate required IDs
      if (sharedDraftId.isEmpty || recipientId.isEmpty) {
        debugPrint(
            '❌ Invalid IDs: sharedDraftId=$sharedDraftId, recipientId=$recipientId');
        return;
      }

      // 1. Create or fetch chat
      final chat = await _chatService.fetchOrCreateChat(recipientId);
      if (chat == null || chat.id == null || chat.id!.isEmpty) {
        debugPrint('❌ Failed to create/fetch chat for draft sharing');
        return;
      }

      final chatId = chat.id!;
      final draftId = draft['id'] as String? ?? '';
      final originalDraftId = draftId.isNotEmpty ? draftId : sharedDraftId;

      // 2. Create draft share message
      final draftMessage = {
        'type': 'draft_share',
        'messageType': 'draft_share',
        'from': currentUser.uid,
        'senderId': currentUser.uid,
        'to': recipientId,
        'text': message ?? 'Check out this draft and share your feedback!',
        'draftId': sharedDraftId,
        'originalDraftId': originalDraftId,
        'canonicalDraftId': draft['id'] ?? '',
        'caption': draft['caption'] ?? '',
        'hashtags': draft['hashtags'] ?? [],
        'thumbnailUrl': persistedAssets['thumbnailUrl'] ?? '',
        'videoUrl': persistedAssets['videoUrl'] ?? '',
        'videoStoragePath': persistedAssets['videoStoragePath'] ?? '',
        'thumbnailStoragePath': persistedAssets['thumbnailStoragePath'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'isRead': false,
        'readBy': [currentUser.uid],
        'recipients': [recipientId],
        'chatId': chatId,
      };

      // 3. Add message to chat
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(draftMessage);

      // 4. Update chat metadata
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': message ?? 'Shared a draft for feedback',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'unreadCount': FieldValue.increment(1),
        'chatType': 'draft_feedback',
      });

      debugPrint('✅ Created draft chat conversation with $recipientId');
    } catch (e, stackTrace) {
      debugPrint(
          '❌ Error creating draft chat conversation with $recipientId: $e');
      debugPrint('❌ Stack trace: $stackTrace');

      // Re-throw to allow caller to handle
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getSharedDraftById(String sharedDraftId) async {
    try {
      final doc =
          await _firestore.collection('shared_drafts').doc(sharedDraftId).get();
      if (!doc.exists || doc.data() == null) {
        return <String, dynamic>{};
      }
      return {
        'id': doc.id,
        ...doc.data()!,
      };
    } catch (e) {
      debugPrint('❌ Error loading shared draft by ID: $e');
      return <String, dynamic>{};
    }
  }

  Future<Map<String, String>> _persistDraftAssets({
    required String ownerId,
    required String draftId,
    required Map<String, dynamic> draft,
  }) async {
    final videoPath = draft['videoPath'] as String?;
    if (videoPath == null || videoPath.isEmpty) {
      debugPrint('❌ Draft is missing a local video path');
      return const <String, String>{};
    }

    final videoFile = File(videoPath);
    if (!await videoFile.exists()) {
      debugPrint('❌ Draft video file does not exist: $videoPath');
      return const <String, String>{};
    }

    final videoExtension = path.extension(videoPath).isNotEmpty
        ? path.extension(videoPath)
        : '.mp4';
    final videoStoragePath =
        'draft_assets/$ownerId/$draftId/video$videoExtension';
    final videoRef = _storage.ref().child(videoStoragePath);
    final videoSnapshot = await videoRef.putFile(videoFile);
    final videoUrl = await videoSnapshot.ref.getDownloadURL();

    String thumbnailUrl = '';
    String thumbnailStoragePath = '';
    final thumbnailPath = draft['thumbnailPath'] as String?;
    if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
      final thumbnailFile = File(thumbnailPath);
      if (await thumbnailFile.exists()) {
        final thumbnailExtension = path.extension(thumbnailPath).isNotEmpty
            ? path.extension(thumbnailPath)
            : '.jpg';
        thumbnailStoragePath =
            'draft_assets/$ownerId/$draftId/thumbnail$thumbnailExtension';
        final thumbnailRef = _storage.ref().child(thumbnailStoragePath);
        final thumbnailSnapshot = await thumbnailRef.putFile(thumbnailFile);
        thumbnailUrl = await thumbnailSnapshot.ref.getDownloadURL();
      }
    }

    return <String, String>{
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'videoStoragePath': videoStoragePath,
      'thumbnailStoragePath': thumbnailStoragePath,
    };
  }

  int _resolveDraftDuration(Map<String, dynamic> draft) {
    final metadata = draft['metadata'];
    final duration =
        metadata is Map<String, dynamic> ? metadata['duration'] : null;
    if (duration is int) {
      return duration;
    }
    if (duration is num) {
      return duration.round();
    }
    return 0;
  }

  String _generateSharedDraftId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'shared_draft_${timestamp}_$random';
  }

  /// Get connection list for current user
  Future<List<Map<String, dynamic>>> getConnections() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      // Connection fetching implementation
      // This would involve getting the user's connection network
      // Currently returns empty list as this feature is not implemented

      debugPrint('🔗 Loading connections...');
      return [];
    } catch (e) {
      debugPrint('❌ Error loading connections: $e');
      return [];
    }
  }
}
