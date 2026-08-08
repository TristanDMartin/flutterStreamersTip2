/// Canonical thread invites — forumPosts/{postId}/invites/{userId}
/// Keep in sync with streamerstipReact/lib/threads/threadInvite.ts.
library;

import 'thread_visibility.dart';

const String kThreadInviteStatusPending = 'pending';
const String kThreadInviteStatusAccepted = 'accepted';
const String kThreadInviteStatusDeclined = 'declined';
const String kThreadInviteStatusRevoked = 'revoked';
const String kThreadInviteStatusExpired = 'expired';

const String kThreadInvitePolicyOwnerOnly = 'owner_only';
const String kThreadInvitePolicyAdmins = 'admins';
const String kThreadInvitePolicyParticipants = 'participants';
const String kThreadInvitePolicyClosed = 'closed';

class ThreadInviteRecord {
  const ThreadInviteRecord({
    required this.id,
    required this.entityId,
    required this.invitedUserId,
    required this.invitedBy,
    required this.status,
    this.entityType = 'forumPost',
    this.schemaVersion = 1,
  });

  final String id;
  final String entityId;
  final String entityType;
  final String invitedUserId;
  final String invitedBy;
  final String status;
  final int schemaVersion;
}

bool canInviteToThread({
  required String? currentUserId,
  required String? ownerId,
  required Object? visibility,
  String invitePolicy = kThreadInvitePolicyOwnerOnly,
}) {
  final String uid = (currentUserId ?? '').trim();
  final String owner = (ownerId ?? '').trim();
  if (uid.isEmpty || owner.isEmpty) {
    return false;
  }
  final String vis = normalizeThreadVisibility(visibility);
  if (vis != kThreadVisibilityInviteOnly) {
    return false;
  }
  if (invitePolicy == kThreadInvitePolicyClosed) {
    return false;
  }
  if (invitePolicy == kThreadInvitePolicyOwnerOnly ||
      invitePolicy == kThreadInvitePolicyAdmins) {
    return uid == owner;
  }
  return uid == owner;
}

bool isInviteStatusActive(String status) {
  return status == kThreadInviteStatusPending ||
      status == kThreadInviteStatusAccepted;
}
