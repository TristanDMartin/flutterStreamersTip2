import 'profile_username_rules.dart';

abstract final class ProfileUsernameUtils {
  static String generateUsernameFromDisplayName(String displayName) {
    if (displayName.isEmpty) {
      return '';
    }
    String username = ProfileUsernameRules.normalize(
      displayName.replaceAll(RegExp(r'\s+'), ''),
    );
    if (username.isEmpty) {
      username = 'user';
    }
    return username;
  }

  static String normalizeUsername(String raw) =>
      ProfileUsernameRules.normalize(raw);

  /// Resolves the public handle from root identity fields or Tippy pending
  /// stash (client cannot always write `users.username` yet).
  static String resolveUsername(Map<String, dynamic>? userData) {
    if (userData == null || userData.isEmpty) {
      return '';
    }
    final String fromRoot = _firstNonEmpty(<String?>[
      userData['username']?.toString(),
      userData['usernameLowercase']?.toString(),
      userData['usernameNormalized']?.toString(),
      userData['handle']?.toString(),
    ]);
    if (fromRoot.isNotEmpty) {
      return ProfileUsernameRules.normalize(fromRoot);
    }
    final Object? onboarding = userData['onboarding'];
    if (onboarding is Map) {
      final String pending = _firstNonEmpty(<String?>[
        onboarding['tippyPendingUsername']?.toString(),
      ]);
      if (pending.isNotEmpty) {
        return ProfileUsernameRules.normalize(pending);
      }
    }
    return '';
  }

  static String resolveDisplayName(Map<String, dynamic>? userData) {
    if (userData == null || userData.isEmpty) {
      return '';
    }
    final String fromRoot = _firstNonEmpty(<String?>[
      userData['displayName']?.toString(),
      userData['name']?.toString(),
    ]);
    if (fromRoot.isNotEmpty) {
      return fromRoot;
    }
    final Object? onboarding = userData['onboarding'];
    if (onboarding is Map) {
      final String pending = _firstNonEmpty(<String?>[
        onboarding['tippyPendingDisplayName']?.toString(),
      ]);
      if (pending.isNotEmpty) {
        return pending;
      }
    }
    return resolveUsername(userData);
  }

  /// `@handle` when a username exists; empty string when it does not.
  static String formatAtHandle(Map<String, dynamic>? userData) {
    final String username = resolveUsername(userData);
    if (username.isEmpty) {
      return '';
    }
    return '@$username';
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final String? value in values) {
      final String trimmed = (value ?? '').trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }
}
