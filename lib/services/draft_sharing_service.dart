import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'local_draft_service.dart';

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
  final LocalDraftService _localDraftService = LocalDraftService();

  /// Share a local draft with connection network
  Future<bool> shareDraftWithConnections({
    required String draftId,
    required List<String> connectionIds,
    String? message,
  }) async {
    try {
      debugPrint('🔗 DraftSharingService: Sharing draft $draftId with ${connectionIds.length} connections');
      
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ User not authenticated');
        return false;
      }

      // 1. Get draft from local storage
      final drafts = await _localDraftService.getAllDrafts();
      final draft = drafts.firstWhere(
        (d) => d['id'] == draftId,
        orElse: () => {},
      );

      if (draft.isEmpty) {
        debugPrint('❌ Draft not found locally: $draftId');
        return false;
      }

      // 2. Create shared draft document in Firestore
      final sharedDraftId = _generateSharedDraftId();
      final sharedDraftData = {
        'id': sharedDraftId,
        'originalDraftId': draftId,
        'sharerId': currentUser.uid,
        'sharerUsername': currentUser.displayName ?? 'Unknown',
        'sharerAvatarUrl': currentUser.photoURL ?? '',
        'recipients': connectionIds,
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
        // Note: Video file is not uploaded to Firestore, only metadata
        // Recipients will need to request the actual video file
      };

      // 3. Save shared draft to Firestore
      await _firestore
          .collection('shared_drafts')
          .doc(sharedDraftId)
          .set(sharedDraftData);

      // 4. Update local draft to mark as shared
      await _localDraftService.shareDraftWithConnections(draftId, connectionIds);

      // 5. Create notification entries for each recipient
      await _createShareNotifications(sharedDraftId, connectionIds, message);

      debugPrint('✅ Draft shared successfully with connections');
      return true;

    } catch (e) {
      debugPrint('❌ Error sharing draft: $e');
      return false;
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

      // 1. Get shared draft data
      final doc = await _firestore
          .collection('shared_drafts')
          .doc(sharedDraftId)
          .get();

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
        sharedDraftId,
        sharedDraftData['originalDraftId'],
        sharedDraftData['sharerId'],
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
          'acceptedAt': DateTime.now().toIso8601String(),
        },
      );

      if (success) {
        // 5. Update shared draft status
        await _firestore
            .collection('shared_drafts')
            .doc(sharedDraftId)
            .update({
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

      // Update shared draft to mark as declined
      await _firestore
          .collection('shared_drafts')
          .doc(sharedDraftId)
          .update({
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
  Future<File?> _requestVideoFileFromSharer(
    String sharedDraftId,
    String originalDraftId,
    String sharerId,
  ) async {
    try {
      debugPrint('📤 Requesting video file from sharer: $sharerId');

      // TODO: Implement video file transfer
      // This could involve:
      // 1. Direct peer-to-peer transfer
      // 2. Temporary upload to Firebase Storage
      // 3. Real-time file sharing
      
      // For now, return null (implementation needed)
      debugPrint('⚠️ Video file transfer not implemented yet');
      return null;

    } catch (e) {
      debugPrint('❌ Error requesting video file: $e');
      return null;
    }
  }

  /// Create notifications for shared draft recipients
  Future<void> _createShareNotifications(
    String sharedDraftId,
    List<String> recipientIds,
    String? message,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final batch = _firestore.batch();

      for (final recipientId in recipientIds) {
        final notificationRef = _firestore
            .collection('notifications')
            .doc(recipientId)
            .collection('items')
            .doc();

        batch.set(notificationRef, {
          'id': notificationRef.id,
          'type': 'shared_draft',
          'from': currentUser.uid,
          'fromUsername': currentUser.displayName ?? 'Unknown',
          'fromAvatarUrl': currentUser.photoURL ?? '',
          'sharedDraftId': sharedDraftId,
          'message': message ?? '${currentUser.displayName ?? 'Someone'} shared a draft with you',
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'readAt': null,
        });
      }

      await batch.commit();
      debugPrint('✅ Created notifications for ${recipientIds.length} recipients');

    } catch (e) {
      debugPrint('❌ Error creating share notifications: $e');
    }
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

      // TODO: Implement connection fetching
      // This would involve getting the user's connection network
      
      debugPrint('🔗 Loading connections...');
      return [];

    } catch (e) {
      debugPrint('❌ Error loading connections: $e');
      return [];
    }
  }
}
