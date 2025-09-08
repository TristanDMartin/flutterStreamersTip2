import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/content_normalizer.dart';

/// Result of content moderation check
class ModerationResult {
  final bool isAllowed;
  final String? reason;
  final List<String> matchedTerms;
  final List<TextMatch> highlightedMatches;
  final String? ruleId;
  final ModerationSeverity severity;

  const ModerationResult({
    required this.isAllowed,
    this.reason,
    this.matchedTerms = const [],
    this.highlightedMatches = const [],
    this.ruleId,
    this.severity = ModerationSeverity.low,
  });
}

enum ModerationSeverity {
  low,
  medium,
  high,
  critical,
}

/// Content moderation service for detecting hate speech and inappropriate content
class ContentModerationService {
  static final ContentModerationService _instance = ContentModerationService._internal();
  factory ContentModerationService() => _instance;
  ContentModerationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cached moderation rules
  List<String> _blockTerms = [];
  List<String> _contextTerms = [];
  List<String> _protectedEntities = [];
  List<String> _allowlist = [];
  bool _isInitialized = false;

  /// Initialize the moderation service with default rules
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadDefaultRules();
      _isInitialized = true;
    } catch (e) {
      print('Error initializing content moderation: $e');
      // Fallback to basic rules
      _blockTerms = ['hate', 'racist'];
      _contextTerms = ['stupid', 'idiot'];
      _protectedEntities = ['race', 'gender'];
      _allowlist = ['educational'];
      _isInitialized = true;
    }
  }

  /// Load default rules as fallback
  Future<void> _loadDefaultRules() async {
    _blockTerms = _getDefaultBlockTerms();
    _contextTerms = _getDefaultContextTerms();
    _protectedEntities = _getDefaultProtectedEntities();
    _allowlist = _getDefaultAllowlist();
  }

  /// Check if content is appropriate
  Future<ModerationResult> checkContent(String text) async {
    print('🔍 Content moderation check for: "$text"');
    
    if (!_isInitialized) {
      print('🔍 Initializing content moderation service...');
      await initialize();
    }

    if (text.trim().isEmpty) {
      print('🔍 Empty text, allowing');
      return const ModerationResult(isAllowed: true);
    }

    final normalizedText = ContentNormalizer.normalize(text);
    final tokens = ContentNormalizer.extractTokens(normalizedText);
    
    print('🔍 Normalized text: "$normalizedText"');
    print('🔍 Tokens: $tokens');
    print('🔍 Block terms loaded: ${_blockTerms.length}');

    // Check for hard blocks
    final hardBlockResult = _checkHardBlocks(normalizedText, tokens);
    if (!hardBlockResult.isAllowed) {
      print('🚫 Content blocked: ${hardBlockResult.reason}');
      return hardBlockResult;
    }

    // Check for context violations
    final contextResult = _checkContextViolations(normalizedText, tokens);
    if (!contextResult.isAllowed) {
      return contextResult;
    }

    // Check allowlist exceptions
    final allowlistResult = _checkAllowlistExceptions(text, normalizedText);
    if (allowlistResult.isAllowed) {
      return allowlistResult;
    }

    return const ModerationResult(isAllowed: true);
  }

  /// Check for hard block terms
  ModerationResult _checkHardBlocks(String normalizedText, List<String> tokens) {
    final matchedTerms = <String>[];
    final highlightedMatches = <TextMatch>[];

    print('🔍 Checking against ${_blockTerms.length} block terms...');
    
    for (final term in _blockTerms) {
      final normalizedTerm = ContentNormalizer.normalize(term);
      if (normalizedText.contains(normalizedTerm)) {
        print('🚫 Found blocked term: "$term" (normalized: "$normalizedTerm")');
        matchedTerms.add(term);
        highlightedMatches.addAll(
          ContentNormalizer.findMatches(normalizedText, normalizedTerm),
        );
      }
    }

    if (matchedTerms.isNotEmpty) {
      print('🚫 Content blocked! Matched terms: $matchedTerms');
      return ModerationResult(
        isAllowed: false,
        reason: 'Content contains prohibited language',
        matchedTerms: matchedTerms,
        highlightedMatches: highlightedMatches,
        ruleId: 'hard_block',
        severity: ModerationSeverity.critical,
      );
    }

    print('✅ No blocked terms found');
    return const ModerationResult(isAllowed: true);
  }

  /// Check for context violations (profanity + protected groups)
  ModerationResult _checkContextViolations(String normalizedText, List<String> tokens) {
    final matchedTerms = <String>[];
    final highlightedMatches = <TextMatch>[];

    // Find context terms and protected entities
    final contextTermPositions = <int>[];
    final protectedEntityPositions = <int>[];

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      
      // Check if token matches context terms
      for (final contextTerm in _contextTerms) {
        if (ContentNormalizer.normalize(contextTerm) == token) {
          contextTermPositions.add(i);
          matchedTerms.add(contextTerm);
        }
      }

      // Check if token matches protected entities
      for (final protectedEntity in _protectedEntities) {
        if (ContentNormalizer.normalize(protectedEntity) == token) {
          protectedEntityPositions.add(i);
        }
      }
    }

    // Check if context terms and protected entities are within 3 tokens
    for (final contextPos in contextTermPositions) {
      for (final protectedPos in protectedEntityPositions) {
        if ((contextPos - protectedPos).abs() <= 3) {
          highlightedMatches.addAll(
            ContentNormalizer.findMatches(normalizedText, tokens[contextPos]),
          );
          highlightedMatches.addAll(
            ContentNormalizer.findMatches(normalizedText, tokens[protectedPos]),
          );

          return ModerationResult(
            isAllowed: false,
            reason: 'Content contains inappropriate language in context',
            matchedTerms: matchedTerms,
            highlightedMatches: highlightedMatches,
            ruleId: 'context_violation',
            severity: ModerationSeverity.high,
          );
        }
      }
    }

    return const ModerationResult(isAllowed: true);
  }

  /// Check for allowlist exceptions
  ModerationResult _checkAllowlistExceptions(String originalText, String normalizedText) {
    for (final allowedTerm in _allowlist) {
      if (normalizedText.contains(ContentNormalizer.normalize(allowedTerm))) {
        return const ModerationResult(
          isAllowed: true,
          reason: 'Content matches allowlist exception',
          ruleId: 'allowlist_exception',
        );
      }
    }

    return const ModerationResult(isAllowed: false);
  }

  /// Report content for manual review
  Future<void> reportContent({
    required String userId,
    required String content,
    required String reason,
    String? additionalNotes,
  }) async {
    try {
      await _firestore.collection('moderation_appeals').add({
        'userId': userId,
        'content': content,
        'reason': reason,
        'additionalNotes': additionalNotes,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      print('Error reporting content: $e');
    }
  }

  /// Get default block terms (comprehensive list)
  List<String> _getDefaultBlockTerms() {
    return [
      // Racial slurs and hate terms
      'chink', 'chinks', 'nigger', 'nigga', 'niggaz', 'niggah', 'niggahs',
      'kike', 'kikes', 'spic', 'spics', 'wetback', 'wetbacks', 'gook', 'gooks',
      'jap', 'japs', 'chink', 'chinks', 'slant', 'slants', 'yellow', 'yellows',
      'cracker', 'crackers', 'honky', 'honkies', 'redneck', 'rednecks',
      'towelhead', 'towelheads', 'sandnigger', 'sandniggers', 'cameljockey',
      'cameljockeys', 'raghead', 'ragheads', 'taco', 'tacos', 'beaner', 'beaners',
      'wetback', 'wetbacks', 'spic', 'spics', 'greaser', 'greasers',
      
      // General hate speech
      'hate', 'racist', 'bigot', 'bigotry', 'nazi', 'fascist', 'supremacist',
      'white power', 'white supremacy', 'black power', 'black supremacy',
      
      // Violence and threats
      'kill', 'murder', 'violence', 'harm', 'hurt', 'beat', 'beating',
      'lynch', 'lynching', 'hang', 'hanging', 'shoot', 'shooting',
      'bomb', 'bombing', 'terrorist', 'terrorism',
      
      // Harassment and derogatory terms
      'harass', 'bully', 'threaten', 'intimidate', 'intimidation',
      'retard', 'retarded', 'faggot', 'fag', 'fags', 'dyke', 'dykes',
      'tranny', 'trannies', 'shemale', 'shemales', 'trannie', 'trannies',
      
      // Workarounds and variations
      'n1gg3r', 'n1gger', 'nigg3r', 'n1gga', 'nigg@', 'n1gg@', 'nigg3r',
      'ch1nk', 'ch1nks', 'k1ke', 'k1kes', 'sp1c', 'sp1cs', 'g00k', 'g00ks',
      'n1gga', 'n1ggas', 'n1gger', 'n1ggers', 'n1ggah', 'n1ggahs',
      
      // Additional offensive terms
      'fuck', 'fucking', 'fucked', 'fucker', 'fuckers', 'fuckface',
      'shit', 'shitting', 'shitted', 'shitty', 'shithead', 'shitheads',
      'bitch', 'bitches', 'bitching', 'bitched', 'bitchy', 'bitchass',
      'ass', 'asses', 'asshole', 'assholes', 'dick', 'dicks', 'dickhead',
      'pussy', 'pussies', 'cunt', 'cunts', 'whore', 'whores', 'slut', 'sluts',
    ];
  }

  /// Get default context terms
  List<String> _getDefaultContextTerms() {
    return [
      'stupid', 'idiot', 'moron', 'dumb', 'crazy',
      'hate', 'disgusting', 'gross', 'awful', 'terrible',
    ];
  }

  /// Get default protected entities
  List<String> _getDefaultProtectedEntities() {
    return [
      'race', 'ethnicity', 'religion', 'gender', 'sexuality',
      'disability', 'age', 'nationality', 'immigration',
      'black', 'white', 'asian', 'hispanic', 'latino',
      'muslim', 'christian', 'jewish', 'hindu', 'buddhist',
      'gay', 'lesbian', 'transgender', 'nonbinary',
      'disabled', 'elderly', 'immigrant', 'refugee',
    ];
  }

  /// Get default allowlist
  List<String> _getDefaultAllowlist() {
    return [
      'educational', 'academic', 'research', 'history',
      'news', 'journalism', 'reporting', 'documentary',
    ];
  }
}
