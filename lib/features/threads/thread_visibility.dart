/// Canonical thread audience values — keep in sync with
/// `streamerstipReact/lib/threads/threadVisibility.ts`.
library;

const String kThreadVisibilityPublic = 'public';
const String kThreadVisibilityFollowers = 'followers';
const String kThreadVisibilityInviteOnly = 'inviteOnly';

const List<String> kThreadVisibilityValues = <String>[
  kThreadVisibilityPublic,
  kThreadVisibilityFollowers,
  kThreadVisibilityInviteOnly,
];

/// Normalize legacy aliases (`invite_only`) to the stored camelCase value.
String normalizeThreadVisibility(Object? raw) {
  final String key = (raw?.toString() ?? kThreadVisibilityPublic)
      .trim()
      .toLowerCase();
  if (key == 'followers') {
    return kThreadVisibilityFollowers;
  }
  if (key == 'inviteonly' || key == 'invite_only' || key == 'invite') {
    return kThreadVisibilityInviteOnly;
  }
  return kThreadVisibilityPublic;
}

String threadVisibilityLabel(String visibility) {
  switch (normalizeThreadVisibility(visibility)) {
    case kThreadVisibilityFollowers:
      return 'Followers';
    case kThreadVisibilityInviteOnly:
      return 'Invite';
    default:
      return 'Public';
  }
}

String threadVisibilityIconLabel(String visibility) {
  switch (normalizeThreadVisibility(visibility)) {
    case kThreadVisibilityFollowers:
      return '🔒 Followers';
    case kThreadVisibilityInviteOnly:
      return '🔐 Invite';
    default:
      return 'Public';
  }
}

/// Decide whether [viewerId] may see a thread with [visibility].
///
/// `inviteOnly` allows the author or viewers with invite access.
bool canViewerAccessThread({
  required Object? visibility,
  required String authorId,
  String? viewerId,
  bool viewerFollowsAuthor = false,
  bool viewerHasInviteAccess = false,
}) {
  final String vis = normalizeThreadVisibility(visibility);
  if (vis == kThreadVisibilityPublic) {
    return true;
  }
  final String viewer = (viewerId ?? '').trim();
  final String author = authorId.trim();
  if (viewer.isEmpty || author.isEmpty) {
    return false;
  }
  if (viewer == author) {
    return true;
  }
  if (vis == kThreadVisibilityFollowers) {
    return viewerFollowsAuthor;
  }
  if (vis == kThreadVisibilityInviteOnly) {
    return viewerHasInviteAccess;
  }
  return false;
}
