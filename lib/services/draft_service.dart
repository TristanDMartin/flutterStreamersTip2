import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/shared_draft.dart';
import 'logging_service.dart';

class DraftService {
  static final DraftService _instance = DraftService._internal();
  factory DraftService() => _instance;
  DraftService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  // Cache for better performance
  final Map<String, SharedDraft> _draftCache = {};

  /// Create a new draft
  Future<SharedDraft?> createDraft({
    required String title,
    required String message,
    required String receiverId,
    String? thumbnailUrl,
    int duration = 0,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    try {
      final draftData = {
        'draftId': _firestore.collection('drafts').doc().id,
        'senderId': currentUser.uid,
        'receiverId': receiverId,
        'senderName': currentUser.displayName ?? 'Unknown User',
        'senderAvatar': currentUser.photoURL,
        'draftTitle': title,
        'draftThumbnailUrl': thumbnailUrl,
        'draftDuration': duration,
        'message': message,
        'status': SharedDraftStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
        'sharedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection('shared_drafts').add(draftData);
      final draft = _mapSharedDraft(docRef.id, draftData);
      _draftCache[docRef.id] = draft;

      LoggingService.instance.info('Draft created successfully: ${docRef.id}');
      return draft;
    } catch (e) {
      LoggingService.instance.error('Error creating draft: $e');
      return null;
    }
  }

  /// Update an existing draft
  Future<bool> updateDraft(String draftId, {
    String? title,
    String? message,
    String? thumbnailUrl,
    int? duration,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (title != null) updateData['draftTitle'] = title;
      if (message != null) updateData['message'] = message;
      if (thumbnailUrl != null) updateData['draftThumbnailUrl'] = thumbnailUrl;
      if (duration != null) updateData['draftDuration'] = duration;
      updateData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('shared_drafts').doc(draftId).update(updateData);
      
      // Update cache
      if (_draftCache.containsKey(draftId)) {
        final cachedDraft = _draftCache[draftId]!;
        _draftCache[draftId] = SharedDraft(
          id: cachedDraft.id,
          draftId: cachedDraft.draftId,
          senderId: cachedDraft.senderId,
          receiverId: cachedDraft.receiverId,
          senderName: cachedDraft.senderName,
          senderAvatar: cachedDraft.senderAvatar,
          draftTitle: title ?? cachedDraft.draftTitle,
          draftThumbnailUrl: thumbnailUrl ?? cachedDraft.draftThumbnailUrl,
          draftDuration: duration ?? cachedDraft.draftDuration,
          message: message ?? cachedDraft.message,
          status: cachedDraft.status,
          sharedAt: cachedDraft.sharedAt,
          viewedAt: cachedDraft.viewedAt,
        );
      }

      LoggingService.instance.info('Draft updated successfully: $draftId');
      return true;
    } catch (e) {
      LoggingService.instance.error('Error updating draft: $e');
      return false;
    }
  }

  /// Delete a draft
  Future<bool> deleteDraft(String draftId) async {
    try {
      await _firestore.collection('shared_drafts').doc(draftId).delete();
      _draftCache.remove(draftId);
      
      LoggingService.instance.info('Draft deleted successfully: $draftId');
      return true;
    } catch (e) {
      LoggingService.instance.error('Error deleting draft: $e');
      return false;
    }
  }

  /// Mark draft as viewed
  Future<bool> markDraftAsViewed(String draftId) async {
    try {
      await _firestore.collection('shared_drafts').doc(draftId).update({
        'status': SharedDraftStatus.viewed.name,
        'viewedAt': FieldValue.serverTimestamp(),
      });

      // Update cache
      if (_draftCache.containsKey(draftId)) {
        final cachedDraft = _draftCache[draftId]!;
        _draftCache[draftId] = SharedDraft(
          id: cachedDraft.id,
          draftId: cachedDraft.draftId,
          senderId: cachedDraft.senderId,
          receiverId: cachedDraft.receiverId,
          senderName: cachedDraft.senderName,
          senderAvatar: cachedDraft.senderAvatar,
          draftTitle: cachedDraft.draftTitle,
          draftThumbnailUrl: cachedDraft.draftThumbnailUrl,
          draftDuration: cachedDraft.draftDuration,
          message: cachedDraft.message,
          status: SharedDraftStatus.viewed,
          sharedAt: cachedDraft.sharedAt,
          viewedAt: DateTime.now(),
        );
      }

      LoggingService.instance.info('Draft marked as viewed: $draftId');
      return true;
    } catch (e) {
      LoggingService.instance.error('Error marking draft as viewed: $e');
      return false;
    }
  }

  /// Get user's sent drafts
  Future<List<SharedDraft>> getSentDrafts() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    try {
      final query = await _firestore
          .collection('shared_drafts')
          .where('senderId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .get();

      final drafts = <SharedDraft>[];
      for (final doc in query.docs) {
        final draft = _mapSharedDraft(doc.id, doc.data());
        _draftCache[doc.id] = draft;
        drafts.add(draft);
      }

      return drafts;
    } catch (e) {
      LoggingService.instance.error('Error getting sent drafts: $e');
      return [];
    }
  }

  /// Stream sent drafts in real-time
  Stream<List<SharedDraft>> streamSentDrafts() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('shared_drafts')
        .where('senderId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final drafts = <SharedDraft>[];
      for (final doc in snapshot.docs) {
        final draft = _mapSharedDraft(doc.id, doc.data());
        _draftCache[doc.id] = draft;
        drafts.add(draft);
      }
      return drafts;
    });
  }

  /// Map Firestore document to SharedDraft model
  SharedDraft _mapSharedDraft(String id, Map<String, dynamic> data) {
    return SharedDraft(
      id: id,
      draftId: data['draftId'] ?? '',
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderAvatar: data['senderAvatar'] ?? '',
      draftTitle: data['draftTitle'] ?? '',
      draftThumbnailUrl: data['draftThumbnailUrl'] ?? '',
      draftDuration: data['draftDuration'] ?? 0,
      sharedAt: (data['sharedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: SharedDraftStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => SharedDraftStatus.pending,
      ),
      message: data['message'],
      viewedAt: (data['viewedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Clear cache
  void clearCache() {
    _draftCache.clear();
  }

  /// Dispose resources
  void dispose() {
    clearCache();
  }
}
