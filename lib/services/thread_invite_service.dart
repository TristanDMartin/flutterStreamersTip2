import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';

import '../features/threads/thread_invite.dart';

/// Canonical thread invite CRUD — mirrors web threadInviteService.
class ThreadInviteService {
  ThreadInviteService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _invitesCol(String postId) {
    return _firestore.collection('forumPosts').doc(postId).collection('invites');
  }

  DocumentReference<Map<String, dynamic>> _inviteRef(
    String postId,
    String userId,
  ) {
    return _invitesCol(postId).doc(userId);
  }

  Future<ThreadInviteRecord?> getThreadInvite(
    String postId,
    String userId,
  ) async {
    if (postId.isEmpty || userId.isEmpty) {
      return null;
    }
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await _inviteRef(postId, userId).get();
    if (!snap.exists || snap.data() == null) {
      return null;
    }
    return _fromDoc(snap.id, postId, snap.data()!);
  }

  Future<bool> viewerHasThreadInviteAccess(
    String postId,
    String userId,
  ) async {
    final ThreadInviteRecord? invite = await getThreadInvite(postId, userId);
    if (invite == null) {
      return false;
    }
    return isInviteStatusActive(invite.status);
  }

  Future<List<ThreadInviteRecord>> listThreadInvites(String postId) async {
    if (postId.isEmpty) {
      return const <ThreadInviteRecord>[];
    }
    final QuerySnapshot<Map<String, dynamic>> snap =
        await _invitesCol(postId).get();
    return snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              _fromDoc(d.id, postId, d.data()),
        )
        .toList(growable: false);
  }

  Future<({List<String> sent, List<String> skipped})> sendThreadInvites({
    required String postId,
    required String postTitle,
    required String ownerId,
    required String visibility,
    required List<String> invitedUserIds,
    String? inviterDisplayName,
    String? inviterAvatarUrl,
  }) async {
    final String? inviterId =
        firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (!canInviteToThread(
      currentUserId: inviterId,
      ownerId: ownerId,
      visibility: visibility,
    )) {
      throw Exception('You do not have permission to invite');
    }
    final List<String> sent = <String>[];
    final List<String> skipped = <String>[];
    final WriteBatch batch = _firestore.batch();
    final List<Map<String, dynamic>> notifyPayloads = <Map<String, dynamic>>[];
    for (final String rawId in invitedUserIds) {
      final String userId = rawId.trim();
      if (userId.isEmpty ||
          userId == inviterId ||
          userId == ownerId) {
        skipped.add(userId);
        continue;
      }
      final ThreadInviteRecord? existing =
          await getThreadInvite(postId, userId);
      if (existing != null && isInviteStatusActive(existing.status)) {
        skipped.add(userId);
        continue;
      }
      batch.set(
        _inviteRef(postId, userId),
        <String, dynamic>{
          'id': userId,
          'entityId': postId,
          'entityType': 'forumPost',
          'invitedUserId': userId,
          'invitedBy': inviterId,
          'status': kThreadInviteStatusPending,
          'createdAt': FieldValue.serverTimestamp(),
          'respondedAt': null,
          'schemaVersion': 1,
        },
        SetOptions(merge: true),
      );
      sent.add(userId);
      final String fromName =
          (inviterDisplayName ?? '').trim().isEmpty
              ? 'Someone'
              : inviterDisplayName!.trim();
      notifyPayloads.add(<String, dynamic>{
        'userId': userId,
        'type': 'thread_invite',
        'postId': postId,
        'postTitle': postTitle,
        'fromUserId': inviterId,
        'fromUserName': fromName,
        'fromUserAvatar': inviterAvatarUrl ?? '',
        'message': '$fromName invited you to $postTitle',
        'metadata': <String, dynamic>{
          'inviteId': userId,
          'route': '/threads/$postId',
          'schemaVersion': 1,
        },
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    if (sent.isEmpty) {
      return (sent: sent, skipped: skipped);
    }
    await batch.commit();
    for (final Map<String, dynamic> payload in notifyPayloads) {
      try {
        await _firestore.collection('forumNotifications').add(payload);
      } catch (e) {
        debugPrint('⚠️ thread invite notify failed: $e');
      }
    }
    return (sent: sent, skipped: skipped);
  }

  Future<void> respondToThreadInvite({
    required String postId,
    required String status,
  }) async {
    final String? uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('Sign in required');
    }
    if (status != kThreadInviteStatusAccepted &&
        status != kThreadInviteStatusDeclined) {
      throw Exception('Invalid invite status');
    }
    final DocumentReference<Map<String, dynamic>> ref =
        _inviteRef(postId, uid);
    final DocumentSnapshot<Map<String, dynamic>> snap = await ref.get();
    if (!snap.exists) {
      throw Exception('Invite not found');
    }
    await ref.update(<String, dynamic>{
      'status': status,
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  ThreadInviteRecord _fromDoc(
    String id,
    String postId,
    Map<String, dynamic> data,
  ) {
    return ThreadInviteRecord(
      id: id,
      entityId: (data['entityId'] as String?) ?? postId,
      entityType: (data['entityType'] as String?) ?? 'forumPost',
      invitedUserId: (data['invitedUserId'] as String?) ?? id,
      invitedBy: (data['invitedBy'] as String?) ?? '',
      status: (data['status'] as String?) ?? kThreadInviteStatusPending,
      schemaVersion: (data['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}
