import 'tippy_onboarding_contract.dart';

/// Guided post-auth creator profile draft for Tippy onboarding.
class TippyProfileDraft {
  TippyProfileDraft({
    this.avatarUrl,
    this.localAvatarPath,
    this.displayName = '',
    this.username = '',
    this.bio = '',
    this.platformIds = const <String>[],
    this.platformHandles = const <String, String>{},
    this.platformUrls = const <String, String>{},
    this.categoryIds = const <String>[],
    this.skippedAvatar = false,
    this.skippedBio = false,
    this.bioRemixCount = 0,
    this.bioRemixHistory = const <String>[],
  });

  final String? avatarUrl;
  final String? localAvatarPath;
  final String displayName;
  final String username;
  final String bio;
  final List<String> platformIds;
  final Map<String, String> platformHandles;
  final Map<String, String> platformUrls;
  final List<String> categoryIds;
  final bool skippedAvatar;
  final bool skippedBio;
  final int bioRemixCount;
  final List<String> bioRemixHistory;

  bool get hasEssentialIdentity => username.trim().isNotEmpty;

  /// Fill username only when the draft does not already have a real handle.
  TippyProfileDraft withReservedUsername(String? username) {
    final String handle = tippyIdentityFromUsername(username ?? '').username;
    if (handle.isEmpty) {
      return this;
    }
    final String existing = tippyIdentityFromUsername(this.username).username;
    if (existing.isNotEmpty) {
      return this;
    }
    return copyWith(
      username: handle,
      displayName: displayName.trim().isNotEmpty ? displayName : handle,
    );
  }

  TippyProfileDraft copyWith({
    String? avatarUrl,
    String? localAvatarPath,
    bool clearLocalAvatarPath = false,
    String? displayName,
    String? username,
    String? bio,
    List<String>? platformIds,
    Map<String, String>? platformHandles,
    Map<String, String>? platformUrls,
    List<String>? categoryIds,
    bool? skippedAvatar,
    bool? skippedBio,
    int? bioRemixCount,
    List<String>? bioRemixHistory,
  }) {
    return TippyProfileDraft(
      avatarUrl: avatarUrl ?? this.avatarUrl,
      localAvatarPath: clearLocalAvatarPath
          ? null
          : (localAvatarPath ?? this.localAvatarPath),
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      platformIds: platformIds ?? List<String>.from(this.platformIds),
      platformHandles:
          platformHandles ?? Map<String, String>.from(this.platformHandles),
      platformUrls: platformUrls ?? Map<String, String>.from(this.platformUrls),
      categoryIds: categoryIds ?? List<String>.from(this.categoryIds),
      skippedAvatar: skippedAvatar ?? this.skippedAvatar,
      skippedBio: skippedBio ?? this.skippedBio,
      bioRemixCount: bioRemixCount ?? this.bioRemixCount,
      bioRemixHistory:
          bioRemixHistory ?? List<String>.from(this.bioRemixHistory),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'avatarUrl': avatarUrl,
      'localAvatarPath': localAvatarPath,
      'displayName': displayName,
      'username': username,
      'bio': bio,
      'platformIds': platformIds,
      'platformHandles': platformHandles,
      'platformUrls': platformUrls,
      'categoryIds': categoryIds,
      'skippedAvatar': skippedAvatar,
      'skippedBio': skippedBio,
      'bioRemixCount': bioRemixCount,
      'bioRemixHistory': bioRemixHistory,
    };
  }

  factory TippyProfileDraft.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return TippyProfileDraft();
    }
    final Object? rawRemix = json['bioRemixCount'];
    final int remixCount = rawRemix is int
        ? rawRemix.clamp(0, 3)
        : (rawRemix is num ? rawRemix.toInt().clamp(0, 3) : 0);
    return TippyProfileDraft(
      avatarUrl: json['avatarUrl'] as String?,
      localAvatarPath: json['localAvatarPath'] as String?,
      displayName: (json['displayName'] as String?)?.trim() ?? '',
      username: (json['username'] as String?)?.trim() ?? '',
      bio: (json['bio'] as String?)?.trim() ?? '',
      platformIds: (json['platformIds'] as List?)
              ?.whereType<String>()
              .toList() ??
          <String>[],
      platformHandles: _stringMap(json['platformHandles']),
      platformUrls: _stringMap(json['platformUrls']),
      categoryIds: (json['categoryIds'] as List?)
              ?.whereType<String>()
              .toList() ??
          <String>[],
      skippedAvatar: json['skippedAvatar'] == true,
      skippedBio: json['skippedBio'] == true,
      bioRemixCount: remixCount,
      bioRemixHistory: (json['bioRemixHistory'] as List?)
              ?.whereType<String>()
              .map((String v) => v.trim())
              .where((String v) => v.isNotEmpty)
              .take(4)
              .toList() ??
          <String>[],
    );
  }

  static Map<String, String> _stringMap(Object? raw) {
    final Map<String, String> out = <String, String>{};
    if (raw is! Map) {
      return out;
    }
    raw.forEach((Object? key, Object? value) {
      if (key is String && value is String) {
        out[key] = value;
      }
    });
    return out;
  }
}

abstract final class TippyGuidedProfileOptions {
  static const List<({String id, String label})> platforms =
      <({String id, String label})>[
    (id: 'twitch', label: 'Twitch'),
    (id: 'youtube', label: 'YouTube'),
    (id: 'tiktok', label: 'TikTok'),
    (id: 'instagram', label: 'Instagram'),
    (id: 'kick', label: 'Kick'),
    (id: 'facebook', label: 'Facebook'),
    (id: 'x', label: 'X'),
    (id: 'discord', label: 'Discord'),
    (id: 'other', label: 'Other'),
  ];

  static const List<({String id, String label})> categories =
      <({String id, String label})>[
    (id: 'gaming', label: 'Gaming'),
    (id: 'streaming', label: 'Streaming'),
    (id: 'commentary', label: 'Commentary'),
    (id: 'education', label: 'Education'),
    (id: 'lifestyle', label: 'Lifestyle'),
    (id: 'music', label: 'Music'),
    (id: 'art', label: 'Art'),
    (id: 'technology', label: 'Technology'),
    (id: 'fitness', label: 'Fitness'),
    (id: 'beauty', label: 'Beauty'),
    (id: 'podcasts', label: 'Podcasts'),
    (id: 'comedy', label: 'Comedy'),
  ];

  static const int displayNameMaxLength = 40;
  static const int bioMaxLength = 160;
  static const int usernameMinLength = 3;
  static const int usernameMaxLength = 30;
}

({String username, String displayName}) tippyIdentityFromUsername(String raw) {
  String username = raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
  if (username.length > TippyGuidedProfileOptions.usernameMaxLength) {
    username = username.substring(0, TippyGuidedProfileOptions.usernameMaxLength);
  }
  return (username: username, displayName: username);
}

String emailLocalPartUsername(String? email) {
  final String local = (email ?? '').split('@').first;
  return tippyIdentityFromUsername(local).username;
}

TippyProfileDraft applyDnaAnswersToProfileDraft({
  required TippyProfileDraft draft,
  required Map<String, dynamic> answers,
  List<Map<String, String>> checkupProfiles = const <Map<String, String>>[],
}) {
  final List<String> platforms = _answerIdList(answers['platforms']);
  final List<String> niche = _answerIdList(answers['niche']);
  final String existingBio = draft.bio.trim();
  final String bio = existingBio.isNotEmpty
      ? existingBio
      : hasTippyDnaAnswers(answers)
          ? suggestBioFromAnswers(answers)
          : '';
  return applyCheckupProfilesToProfileDraft(
    draft: draft.copyWith(
      platformIds: platforms.isNotEmpty ? platforms : draft.platformIds,
      categoryIds: niche.isNotEmpty ? niche : draft.categoryIds,
      bio: bio,
      skippedBio: bio.isEmpty ? draft.skippedBio : false,
    ),
    checkupProfiles: checkupProfiles,
  );
}

const Set<String> _youtubeReservedPaths = <String>{
  'watch',
  'shorts',
  'playlist',
  'feed',
  'results',
  'live',
  'embed',
  'channel',
  'user',
  'c',
  'account',
};

bool _looksLikeProfileUrl(String value) {
  final String lower = value.toLowerCase();
  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('www.')) {
    return true;
  }
  return RegExp(
    r'(?:twitch\.tv|youtube\.com|youtu\.be|tiktok\.com|instagram\.com|'
    r'kick\.com|facebook\.com|twitter\.com|(?:^|\.)x\.com|'
    r'discord\.(?:gg|com))/',
    caseSensitive: false,
  ).hasMatch(value);
}

String _guidedPlatformId(String platform) {
  final String raw = platform.trim().toLowerCase();
  if (raw == 'twitter') {
    return 'x';
  }
  return raw;
}

/// Bare handle for identity socials. `@imdanewtech` → `imdanewtech`.
String onboardingHandleFromCheckupInput(String platform, String handleOrUrl) {
  final String raw = handleOrUrl.trim();
  if (raw.isEmpty) {
    return '';
  }
  final String type = platform.trim().toLowerCase();
  if (_looksLikeProfileUrl(raw)) {
    final String candidate = raw.toLowerCase().startsWith('http://') ||
            raw.toLowerCase().startsWith('https://')
        ? raw
        : 'https://${raw.replaceFirst(RegExp(r'^//'), '')}';
    final Uri? url = Uri.tryParse(candidate);
    if (url != null) {
      final List<String> parts =
          url.path.split('/').where((String p) => p.isNotEmpty).toList();
      String? at;
      for (final String part in parts) {
        if (part.startsWith('@')) {
          at = part;
          break;
        }
      }
      if (at != null) {
        final String handle = Uri.decodeComponent(at.replaceFirst(RegExp(r'^@+'), ''));
        return type == 'twitch' || type == 'kick' ? handle.toLowerCase() : handle;
      }
      final String host = url.host.replaceFirst(RegExp(r'^www\.'), '').toLowerCase();
      if (host.endsWith('youtube.com') || host == 'youtu.be') {
        final String first = parts.isEmpty ? '' : parts.first;
        if (first.toLowerCase() == 'channel') {
          return '';
        }
        if (first.isNotEmpty &&
            !_youtubeReservedPaths.contains(first.toLowerCase())) {
          return Uri.decodeComponent(first.replaceFirst(RegExp(r'^@+'), ''));
        }
        return '';
      }
      if (parts.isNotEmpty) {
        final String handle = Uri.decodeComponent(
          parts.first.replaceFirst(RegExp(r'^@+'), ''),
        );
        return type == 'twitch' || type == 'kick'
            ? handle.toLowerCase()
            : handle;
      }
      if (type == 'other') {
        return raw;
      }
    }
  }
  final String handle = raw.replaceFirst(RegExp(r'^@+'), '').replaceFirst(
        RegExp(r'/+$'),
        '',
      );
  return type == 'twitch' || type == 'kick' ? handle.toLowerCase() : handle;
}

/// Prefill identity `platform_handles`. Does not skip that screen.
TippyProfileDraft applyCheckupProfilesToProfileDraft({
  required TippyProfileDraft draft,
  List<Map<String, String>> checkupProfiles = const <Map<String, String>>[],
}) {
  if (checkupProfiles.isEmpty) {
    return draft;
  }
  final Set<String> allowed = TippyGuidedProfileOptions.platforms
      .map((({String id, String label}) p) => p.id)
      .toSet();
  final List<String> platformIds = List<String>.from(draft.platformIds);
  final Map<String, String> platformHandles =
      Map<String, String>.from(draft.platformHandles);
  final Map<String, String> platformUrls =
      Map<String, String>.from(draft.platformUrls);
  for (final Map<String, String> row in checkupProfiles) {
    final String id = _guidedPlatformId(row['platform'] ?? '');
    if (!allowed.contains(id)) {
      continue;
    }
    final String raw =
        (row['handleOrUrl'] ?? row['profileUrl'] ?? '').trim();
    if (raw.isEmpty) {
      continue;
    }
    final String handle = onboardingHandleFromCheckupInput(id, raw);
    if (!platformIds.contains(id)) {
      platformIds.add(id);
    }
    if (handle.isNotEmpty && (platformHandles[id] ?? '').trim().isEmpty) {
      platformHandles[id] = handle;
    }
    if (_looksLikeProfileUrl(raw) && (platformUrls[id] ?? '').trim().isEmpty) {
      platformUrls[id] = raw.startsWith('http') ? raw : 'https://$raw';
    }
  }
  return draft.copyWith(
    platformIds: platformIds,
    platformHandles: platformHandles,
    platformUrls: platformUrls,
  );
}

List<String> _answerIdList(Object? raw) {
  if (raw is List) {
    return raw.whereType<String>().toList();
  }
  if (raw is String && raw.trim().isNotEmpty) {
    return <String>[raw.trim()];
  }
  return const <String>[];
}

/// Visible "What should creators call you?" value. Owned handle first, then draft, then Auth name.
String seedCreatorCallName({
  String? ownedUsername,
  String? draftDisplayName,
  String? authDisplayName,
}) {
  final String owned = tippyIdentityFromUsername(ownedUsername ?? '').username;
  if (owned.isNotEmpty) {
    return owned;
  }
  final String draft = (draftDisplayName ?? '').trim();
  if (draft.isNotEmpty) {
    return draft;
  }
  return (authDisplayName ?? '').trim();
}

/// Canonical onboarding username.
///
/// Precedence: preferDraft → real users.username → preferred reservation /
/// email-stand-in recover → non-email draft.
/// Email-local users.username alone is not identity authority.
String resolveCanonicalOnboardingUsername({
  String? accountUsername,
  String? preferredUsername,
  String? draftUsername,
  String? email,
  bool preferDraft = false,
}) {
  final String account = tippyIdentityFromUsername(accountUsername ?? '').username;
  final String preferred =
      tippyIdentityFromUsername(preferredUsername ?? '').username;
  final String draft = tippyIdentityFromUsername(draftUsername ?? '').username;
  final String emailLocal = emailLocalPartUsername(email);
  if (preferDraft && draft.isNotEmpty) {
    return draft;
  }
  if (account.isNotEmpty && account != emailLocal) {
    return account;
  }
  if (preferred.isNotEmpty) {
    return preferred;
  }
  if (draft.isNotEmpty && draft != emailLocal) {
    return draft;
  }
  return '';
}

/// Prefill guided identity from the live account, never email-first.
String selectTippyIdentitySeed({
  String? accountUsername,
  String? preferredUsername,
  String? draftUsername,
  String? displayName,
  String? email,
}) {
  return resolveCanonicalOnboardingUsername(
    accountUsername: accountUsername,
    preferredUsername: preferredUsername,
    draftUsername: draftUsername,
    email: email,
  );
}

/// Status-owned identity: username or signup reservation. Never email.
String canonicalUsernameFromAccountFields({
  String? username,
  String? preferredUsername,
  String? email,
}) {
  return resolveCanonicalOnboardingUsername(
    accountUsername: username,
    preferredUsername: preferredUsername,
    email: email,
  );
}

/// Username the identity step must show.
/// Email-local canonical/users.username is not identity — prefer the
/// signup reservation (`tester0505`) over an email prefix stand-in.
String ownedUsernameFromAccountStatus({
  String? canonicalUsername,
  String? username,
  String? preferredUsername,
  String? draftUsername,
  String? email,
}) {
  return resolveCanonicalOnboardingUsername(
    accountUsername: (canonicalUsername ?? '').trim().isNotEmpty
        ? canonicalUsername
        : username,
    preferredUsername: preferredUsername,
    draftUsername: draftUsername,
    email: email,
  );
}

enum CreatorUsernameScreenState { loading, canonical, select, reconcile }

/// Creator username UI never invents identity from email.
/// Phase 1J.1: never return a blank loading interstitial — paint select
/// immediately while status/provision continue in the background.
CreatorUsernameScreenState resolveCreatorUsernameScreen({
  bool statusLoaded = false,
  String? canonicalUsername,
  String? preferredUsername,
  bool provisioned = false,
}) {
  final String canonical =
      tippyIdentityFromUsername(canonicalUsername ?? '').username;
  if (canonical.isNotEmpty) {
    return CreatorUsernameScreenState.canonical;
  }
  final String preferred =
      tippyIdentityFromUsername(preferredUsername ?? '').username;
  if (preferred.isNotEmpty) {
    return CreatorUsernameScreenState.select;
  }
  if (provisioned) {
    return CreatorUsernameScreenState.select;
  }
  // statusLoaded false / reconcile pending → still select (no spinner stage).
  return CreatorUsernameScreenState.select;
}

bool isOwnedTippyUsername(String candidate, String? ownedUsername) {
  final String left = tippyIdentityFromUsername(candidate).username;
  final String right = tippyIdentityFromUsername(ownedUsername ?? '').username;
  return left.length >= TippyGuidedProfileOptions.usernameMinLength &&
      left == right;
}
