import '../utils/content_normalizer.dart';

class ModerationResult {
  final bool isAllowed;
  final String? reason;
  final List<String> matchedTerms;
  final ModerationSeverity severity;

  const ModerationResult({
    required this.isAllowed,
    this.reason,
    this.matchedTerms = const [],
    this.severity = ModerationSeverity.low,
  });
}

enum ModerationSeverity { low, medium, high, critical }

class ContentModerationService {
  static final ContentModerationService _instance =
      ContentModerationService._internal();
  factory ContentModerationService() => _instance;

  // Basic prohibited words - we can expand this later
  static const List<String> _blockTerms = [
    'nigger',
    'nigga',
    'faggot',
    'fag',
    'dyke',
    'bitch',
    'whore',
    'slut',
    'cunt',
    'retard',
    'retarded',
    'spastic',
    'spaz',
    'cripple',
    'lame',
    'dumb',
    'stupid',
    'idiot',
    'moron',
    'kill yourself',
    'kys',
    'suicide',
    'die',
    'death',
    'hate',
    'racist',
    'sexist',
    'homophobic',
    'nazi',
    'hitler',
    'fascist',
    'kkk',
    'klan',
  ];

  static const List<String> _contextTerms = [
    'stupid',
    'idiot',
    'moron',
    'dumb',
    'crazy',
    'hate',
    'disgusting',
    'gross',
    'awful',
    'terrible',
  ];

  static const List<String> _protectedEntities = [
    'race',
    'ethnicity',
    'religion',
    'gender',
    'sexuality',
    'disability',
    'age',
    'nationality',
    'black',
    'white',
    'asian',
    'hispanic',
    'latino',
    'muslim',
    'christian',
    'jewish',
    'gay',
    'lesbian',
    'transgender',
    'nonbinary',
    'disabled',
    'elderly',
    'immigrant',
  ];

  static const List<String> _allowlist = [
    'educational',
    'academic',
    'research',
    'history',
    'news',
    'journalism',
    'reporting',
    'documentary',
  ];

  final int window;
  final Set<String> _block, _ctx, _prot, _allow;

  ContentModerationService._internal()
      : window = 3,
        _block = _nSet(_blockTerms),
        _ctx = _nSet(_contextTerms),
        _prot = _nSet(_protectedEntities),
        _allow = _nSet(_allowlist);

  static Set<String> _nSet(List<String> xs) =>
      xs.map(ContentNormalizer.normalize).toSet();

  Future<ModerationResult> check(String text) async {
    if (text.trim().isEmpty) {
      return const ModerationResult(isAllowed: true);
    }

    final norm = ContentNormalizer.normalize(text);

    // Allowlist first
    for (final a in _allow) {
      if (norm.contains(a)) {
        return const ModerationResult(
          isAllowed: true,
          reason: 'Allowlisted context',
          severity: ModerationSeverity.low,
        );
      }
    }

    // Hard block
    for (final b in _block) {
      if (norm.contains(b)) {
        return ModerationResult(
          isAllowed: false,
          reason: 'Contains prohibited language',
          matchedTerms: [b],
          severity: ModerationSeverity.critical,
        );
      }
    }

    // Context window
    final tokens = ContentNormalizer.extractTokens(norm);
    final ctxPos = <int>[];
    final protPos = <int>[];

    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (_ctx.contains(t)) ctxPos.add(i);
      if (_prot.contains(t)) protPos.add(i);
    }

    for (final c in ctxPos) {
      for (final p in protPos) {
        if ((c - p).abs() <= window) {
          return ModerationResult(
            isAllowed: false,
            reason: 'Inappropriate language in protected context',
            matchedTerms: [tokens[c], tokens[p]],
            severity: ModerationSeverity.high,
          );
        }
      }
    }

    return const ModerationResult(isAllowed: true);
  }

  /// Check if content is appropriate for display names
  static ModerationResult validateDisplayName(String displayName) {
    if (displayName.isEmpty) {
      return const ModerationResult(
        isAllowed: false,
        reason: 'Display name cannot be empty',
        severity: ModerationSeverity.medium,
      );
    }

    if (displayName.length > 30) {
      return const ModerationResult(
        isAllowed: false,
        reason: 'Display name must be 30 characters or less',
        severity: ModerationSeverity.medium,
      );
    }

    // Use synchronous content checking
    final norm = ContentNormalizer.normalize(displayName);

    // Check allowlist first
    for (final a in _allowlist) {
      if (norm.contains(ContentNormalizer.normalize(a))) {
        return const ModerationResult(
          isAllowed: true,
          reason: 'Allowlisted context',
          severity: ModerationSeverity.low,
        );
      }
    }

    // Check hard block
    for (final b in _blockTerms) {
      if (norm.contains(ContentNormalizer.normalize(b))) {
        return ModerationResult(
          isAllowed: false,
          reason:
              'Display name contains inappropriate content. Please choose a different name.',
          matchedTerms: [b],
          severity: ModerationSeverity.critical,
        );
      }
    }

    return const ModerationResult(isAllowed: true);
  }

  /// Check if content is appropriate for bio
  static ModerationResult validateBio(String bio) {
    if (bio.length > 200) {
      return const ModerationResult(
        isAllowed: false,
        reason: 'Bio must be 200 characters or less',
        severity: ModerationSeverity.medium,
      );
    }

    // Use synchronous content checking
    final norm = ContentNormalizer.normalize(bio);

    // Check allowlist first
    for (final a in _allowlist) {
      if (norm.contains(ContentNormalizer.normalize(a))) {
        return const ModerationResult(
          isAllowed: true,
          reason: 'Allowlisted context',
          severity: ModerationSeverity.low,
        );
      }
    }

    // Check hard block
    for (final b in _blockTerms) {
      if (norm.contains(ContentNormalizer.normalize(b))) {
        return ModerationResult(
          isAllowed: false,
          reason:
              'Bio contains inappropriate content. Please remove offensive language.',
          matchedTerms: [b],
          severity: ModerationSeverity.critical,
        );
      }
    }

    return const ModerationResult(isAllowed: true);
  }

  /// Check if content is appropriate for hashtags
  static ModerationResult validateHashtags(List<String> hashtags) {
    for (final hashtag in hashtags) {
      if (hashtag.isEmpty) continue;

      // Use synchronous content checking
      final norm = ContentNormalizer.normalize(hashtag);

      // Check allowlist first
      for (final a in _allowlist) {
        if (norm.contains(ContentNormalizer.normalize(a))) {
          continue; // This hashtag is allowed
        }
      }

      // Check hard block
      for (final b in _blockTerms) {
        if (norm.contains(ContentNormalizer.normalize(b))) {
          return ModerationResult(
            isAllowed: false,
            reason:
                'Hashtag "$hashtag" contains inappropriate content. Please remove offensive hashtags.',
            matchedTerms: [hashtag],
            severity: ModerationSeverity.critical,
          );
        }
      }
    }

    return const ModerationResult(isAllowed: true);
  }

  /// Check if content is appropriate for platforms/social links
  static ModerationResult validatePlatforms(
      List<Map<String, dynamic>> platforms) {
    for (final platform in platforms) {
      final username = platform['username']?.toString() ?? '';
      final url = platform['url']?.toString() ?? '';

      // Check username
      if (username.isNotEmpty) {
        final usernameNorm = ContentNormalizer.normalize(username);

        // Check hard block for username
        for (final b in _blockTerms) {
          if (usernameNorm.contains(ContentNormalizer.normalize(b))) {
            return const ModerationResult(
              isAllowed: false,
              reason:
                  'Social media username contains inappropriate content. Please remove offensive language.',
              severity: ModerationSeverity.critical,
            );
          }
        }
      }

      // Check URL
      if (url.isNotEmpty) {
        final urlNorm = ContentNormalizer.normalize(url);

        // Check hard block for URL
        for (final b in _blockTerms) {
          if (urlNorm.contains(ContentNormalizer.normalize(b))) {
            return const ModerationResult(
              isAllowed: false,
              reason:
                  'Social media URL contains inappropriate content. Please remove offensive language.',
              severity: ModerationSeverity.critical,
            );
          }
        }
      }
    }

    return const ModerationResult(isAllowed: true);
  }
}
