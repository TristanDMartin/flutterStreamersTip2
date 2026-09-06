/// Canonical Tippy Brain — same layers as website
/// `lib/tippy/intelligence/tippyBrainContract.ts`.
/// Path: users/{uid}/creatorMemory/main. Do not invent a second collection.
library;

const String kTippyBrainPath = 'users/{uid}/creatorMemory/main';
const String kTippyBrainApi = '/api/tippy/creator-memory';
const int kTippyBrainVersion = 1;
const List<String> kTippyBrainForbiddenPaths = <String>[
  'tippyBrain',
  'users/{uid}/tippyBrain',
];

const List<String> kTippyBrainInsightTypes = <String>[
  'observation',
  'inference',
  'recommendation',
  'confirmed',
];

const List<String> kTippyBrainHiddenAccountStatuses = <String>[
  'deleted',
  'deleting',
  'deactivated',
  'banned',
  'suspended',
  'disabled',
];

class TippyBrainInsight {
  const TippyBrainInsight({
    required this.id,
    required this.statement,
    required this.type,
    required this.source,
    this.evidenceIds = const <String>[],
    required this.confidence,
    required this.createdAt,
    this.lastValidatedAt,
  });

  final String id;
  final String statement;
  final String type;
  final String source;
  final List<String> evidenceIds;
  final double confidence;
  final String createdAt;
  final String? lastValidatedAt;

  factory TippyBrainInsight.fromJson(Map<String, dynamic> json) {
    return TippyBrainInsight(
      id: '${json['id'] ?? ''}',
      statement: '${json['statement'] ?? ''}',
      type: '${json['type'] ?? ''}',
      source: '${json['source'] ?? 'unknown'}',
      evidenceIds: _stringList(json['evidenceIds']),
      confidence: _clampConfidence(json['confidence']),
      createdAt: '${json['createdAt'] ?? ''}',
      lastValidatedAt: json['lastValidatedAt'] is String
          ? json['lastValidatedAt'] as String
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'statement': statement,
      'type': type,
      'source': source,
      'evidenceIds': evidenceIds,
      'confidence': confidence,
      'createdAt': createdAt,
      'lastValidatedAt': lastValidatedAt,
    };
  }
}

class TippyBrainPlatformIntelligence {
  const TippyBrainPlatformIntelligence({
    this.platforms = const <String>[],
    this.profiles = const <Map<String, String>>[],
    this.analyzedPlatforms = const <String>[],
  });

  final List<String> platforms;
  final List<Map<String, String>> profiles;
  final List<String> analyzedPlatforms;

  factory TippyBrainPlatformIntelligence.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const TippyBrainPlatformIntelligence();
    }
    return TippyBrainPlatformIntelligence(
      platforms: _stringList(json['platforms']),
      analyzedPlatforms: _stringList(json['analyzedPlatforms']),
      profiles: json['profiles'] is List
          ? (json['profiles'] as List<dynamic>)
              .whereType<Map>()
              .map(
                (Map row) => <String, String>{
                  'platform': '${row['platform'] ?? ''}',
                  'handleOrUrl': '${row['handleOrUrl'] ?? ''}',
                  'analysisStatus': '${row['analysisStatus'] ?? ''}',
                },
              )
              .toList()
          : const <Map<String, String>>[],
    );
  }
}

class TippyBrainCurrentStrategy {
  const TippyBrainCurrentStrategy({
    this.recommendedFocus,
    this.primaryOpportunity,
    this.weeklyFocus,
  });

  final String? recommendedFocus;
  final String? primaryOpportunity;
  final String? weeklyFocus;

  factory TippyBrainCurrentStrategy.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const TippyBrainCurrentStrategy();
    }
    return TippyBrainCurrentStrategy(
      recommendedFocus: json['recommendedFocus'] is String
          ? json['recommendedFocus'] as String
          : null,
      primaryOpportunity: json['primaryOpportunity'] is String
          ? json['primaryOpportunity'] as String
          : null,
      weeklyFocus: json['weeklyFocus'] is String
          ? json['weeklyFocus'] as String
          : null,
    );
  }
}

class TippyBrainLayers {
  const TippyBrainLayers({
    this.brainVersion = kTippyBrainVersion,
    this.confirmedFacts = const <TippyBrainInsight>[],
    this.observations = const <TippyBrainInsight>[],
    this.inferences = const <TippyBrainInsight>[],
    this.platformIntelligence = const TippyBrainPlatformIntelligence(),
    this.currentStrategy = const TippyBrainCurrentStrategy(),
    this.strategicMemory = const <Map<String, dynamic>>[],
    this.experiments = const <Map<String, dynamic>>[],
    this.outcomes = const <Map<String, dynamic>>[],
    this.recommendations = const <TippyBrainInsight>[],
    this.updatedAt,
  });

  final int brainVersion;
  final List<TippyBrainInsight> confirmedFacts;
  final List<TippyBrainInsight> observations;
  final List<TippyBrainInsight> inferences;
  final TippyBrainPlatformIntelligence platformIntelligence;
  final TippyBrainCurrentStrategy currentStrategy;
  final List<Map<String, dynamic>> strategicMemory;
  final List<Map<String, dynamic>> experiments;
  final List<Map<String, dynamic>> outcomes;
  final List<TippyBrainInsight> recommendations;
  final String? updatedAt;

  factory TippyBrainLayers.empty() => const TippyBrainLayers();

  factory TippyBrainLayers.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const TippyBrainLayers();
    }
    return TippyBrainLayers(
      brainVersion: (json['brainVersion'] as num?)?.toInt() ?? kTippyBrainVersion,
      confirmedFacts: _insights(json['confirmedFacts']),
      observations: _insights(json['observations']),
      inferences: _insights(json['inferences']),
      recommendations: _insights(json['recommendations']),
      platformIntelligence: TippyBrainPlatformIntelligence.fromJson(
        json['platformIntelligence'] is Map
            ? (json['platformIntelligence'] as Map).cast<String, dynamic>()
            : _legacyPlatforms(json),
      ),
      currentStrategy: TippyBrainCurrentStrategy.fromJson(
        json['currentStrategy'] is Map
            ? (json['currentStrategy'] as Map).cast<String, dynamic>()
            : null,
      ),
      strategicMemory: _mapList(json['strategicMemory']),
      experiments: _mapList(json['experiments']),
      outcomes: _mapList(json['outcomes']),
      updatedAt: json['updatedAt'] is String ? json['updatedAt'] as String : null,
    );
  }
}

class TippyBrainGuestMergeInput {
  const TippyBrainGuestMergeInput({
    required this.targetUid,
    required this.guestKey,
    required this.currentGuestKey,
    this.attachedUid,
    this.accountStatus,
    this.deletedUids = const <String>[],
    this.profiles = const <Map<String, dynamic>>[],
    this.inferred,
    this.confirmed,
  });

  final String targetUid;
  final String guestKey;
  final String? currentGuestKey;
  final String? attachedUid;
  final String? accountStatus;
  final List<String> deletedUids;
  final List<Map<String, dynamic>> profiles;
  final Map<String, dynamic>? inferred;
  final Map<String, dynamic>? confirmed;
}

class TippyBrainMergeDecision {
  const TippyBrainMergeDecision({required this.ok, this.reason});

  final bool ok;
  final String? reason;
}

TippyBrainMergeDecision canMergeGuestCheckupIntoBrain(
  TippyBrainGuestMergeInput input,
) {
  final String uid = input.targetUid.trim();
  if (uid.isEmpty) {
    return const TippyBrainMergeDecision(ok: false, reason: 'missing_uid');
  }
  if (input.accountStatus != null &&
      kTippyBrainHiddenAccountStatuses.contains(input.accountStatus)) {
    return const TippyBrainMergeDecision(
      ok: false,
      reason: 'account_not_attachable',
    );
  }
  if (input.deletedUids.contains(uid)) {
    return const TippyBrainMergeDecision(ok: false, reason: 'deleted_uid');
  }
  if (input.guestKey.isEmpty ||
      input.currentGuestKey == null ||
      input.currentGuestKey!.isEmpty) {
    return const TippyBrainMergeDecision(
      ok: false,
      reason: 'no_current_guest_session',
    );
  }
  if (input.guestKey != input.currentGuestKey) {
    return const TippyBrainMergeDecision(
      ok: false,
      reason: 'guest_key_mismatch',
    );
  }
  if (input.attachedUid != null &&
      input.attachedUid!.isNotEmpty &&
      input.attachedUid != uid) {
    return const TippyBrainMergeDecision(
      ok: false,
      reason: 'already_bound_other_uid',
    );
  }
  return const TippyBrainMergeDecision(ok: true);
}

List<String> confirmedPlatformIdsFromBrain(TippyBrainLayers? brain) {
  if (brain == null) {
    return const <String>[];
  }
  return _unique(brain.platformIntelligence.platforms);
}

bool hasConfirmedPlatformsInBrain(TippyBrainLayers? brain) {
  return confirmedPlatformIdsFromBrain(brain).isNotEmpty;
}

bool shouldSkipPlatformsQuestion({
  List<String> confirmedPlatformIds = const <String>[],
  Map<String, dynamic>? answers,
  TippyBrainLayers? brain,
}) {
  if (confirmedPlatformIds.isNotEmpty) {
    return true;
  }
  if (hasConfirmedPlatformsInBrain(brain)) {
    return true;
  }
  final Object? raw = answers?['platforms'];
  return raw is List && raw.isNotEmpty;
}

Map<String, dynamic> applyConfirmedPlatformsToAnswers(
  Map<String, dynamic> answers,
  List<String> confirmedPlatformIds,
) {
  if (confirmedPlatformIds.isEmpty) {
    return answers;
  }
  final Object? existing = answers['platforms'];
  if (existing is List && existing.isNotEmpty) {
    return answers;
  }
  return <String, dynamic>{
    ...answers,
    'platforms': List<String>.from(confirmedPlatformIds),
  };
}

const String kCreatorReadTitle = 'Your Creator Read';
const String kCreatorReadContinuityCopy =
    "I brought over what I learned from your Checkup. Here's what I want us to focus on first.";

class TippyCreatorRead {
  const TippyCreatorRead({
    required this.title,
    required this.continuityCopy,
    this.openingRead,
    this.platforms = const <String>[],
    this.creatorType,
    this.niche,
    this.biggestOpportunity,
    this.firstFocus,
    this.notices = const <String>[],
    this.observed = const <String>[],
    this.inferred = const <String>[],
    this.confirmed = const <String>[],
  });

  final String title;
  final String continuityCopy;
  final String? openingRead;
  final List<String> platforms;
  final String? creatorType;
  final String? niche;
  final String? biggestOpportunity;
  final String? firstFocus;
  final List<String> notices;
  final List<String> observed;
  final List<String> inferred;
  final List<String> confirmed;
}

bool isCheckupDerivedSource(String? source) {
  return (source ?? '').startsWith('checkup_');
}

List<TippyBrainInsight> _checkupInsights(List<TippyBrainInsight> rows) {
  return rows
      .where((TippyBrainInsight row) => isCheckupDerivedSource(row.source))
      .toList();
}

bool hasCheckupDerivedLayer(TippyBrainLayers? brain) {
  if (brain == null) {
    return false;
  }
  return _checkupInsights(brain.confirmedFacts).isNotEmpty ||
      _checkupInsights(brain.observations).isNotEmpty ||
      _checkupInsights(brain.inferences).isNotEmpty ||
      _checkupInsights(brain.recommendations).isNotEmpty;
}

bool shouldRedirectCheckupToMissionControl({
  required bool isAuthenticated,
  required bool isActivated,
  TippyBrainLayers? brain,
}) {
  if (!isAuthenticated || !isActivated) {
    return false;
  }
  return hasCheckupDerivedLayer(brain);
}

String? _insightStatement(List<TippyBrainInsight> rows, String id) {
  for (final TippyBrainInsight row in rows) {
    if (row.id == id && row.statement.trim().isNotEmpty) {
      return row.statement;
    }
  }
  return null;
}

String? _statementAfterPrefix(
  List<TippyBrainInsight> rows,
  String id,
  List<String> prefixes,
) {
  for (final TippyBrainInsight row in rows) {
    if (row.id != id) {
      continue;
    }
    String text = row.statement;
    for (final String prefix in prefixes) {
      if (text.toLowerCase().startsWith(prefix.toLowerCase())) {
        text = text.substring(prefix.length).trim();
      }
    }
    return text.isEmpty ? row.statement : text;
  }
  return null;
}

List<String> _uniqueDisplay(List<String> values, [int max = 12]) {
  final List<String> out = <String>[];
  final Set<String> seen = <String>{};
  for (final String raw in values) {
    final String value = raw.trim();
    final String key = value.toLowerCase();
    if (value.isEmpty || seen.contains(key)) {
      continue;
    }
    seen.add(key);
    out.add(value);
    if (out.length >= max) {
      break;
    }
  }
  return out;
}

TippyCreatorRead? projectCreatorReadFromBrain(TippyBrainLayers? brain) {
  if (!hasCheckupDerivedLayer(brain) || brain == null) {
    return null;
  }
  final List<TippyBrainInsight> confirmed =
      _checkupInsights(brain.confirmedFacts);
  final List<TippyBrainInsight> observed =
      _checkupInsights(brain.observations);
  final List<TippyBrainInsight> inferred = _checkupInsights(brain.inferences);
  final String? openingRead =
      _insightStatement(inferred, 'inferred_presence_summary') ??
          _insightStatement(inferred, 'inferred_creator_type');
  return TippyCreatorRead(
    title: kCreatorReadTitle,
    continuityCopy: kCreatorReadContinuityCopy,
    openingRead: openingRead,
    platforms: confirmedPlatformIdsFromBrain(brain),
    creatorType: _statementAfterPrefix(
      confirmed,
      'confirmed_creator_type',
      <String>['Creator type:', 'Appears to be a'],
    ),
    niche: _statementAfterPrefix(
      confirmed,
      'confirmed_niche',
      <String>['Niche:', 'Inferred niche:'],
    ),
    biggestOpportunity: brain.currentStrategy.primaryOpportunity,
    firstFocus: brain.currentStrategy.recommendedFocus,
    notices: _uniqueDisplay(
      <String>[
        ...observed.map((TippyBrainInsight row) => row.statement),
        ...inferred
            .where(
              (TippyBrainInsight row) =>
                  row.id != 'inferred_presence_summary' &&
                  row.id != 'inferred_creator_type',
            )
            .map((TippyBrainInsight row) => row.statement),
      ],
      3,
    ),
    observed: observed.map((TippyBrainInsight row) => row.statement).toList(),
    inferred: inferred.map((TippyBrainInsight row) => row.statement).toList(),
    confirmed: confirmed.map((TippyBrainInsight row) => row.statement).toList(),
  );
}

String? tippyKnowsSetupLine(List<String> platforms) {
  if (platforms.isEmpty) {
    return null;
  }
  const Map<String, String> labels = <String, String>{
    'twitch': 'Twitch',
    'youtube': 'YouTube',
    'tiktok': 'TikTok',
    'instagram': 'Instagram',
    'kick': 'Kick',
  };
  final List<String> named =
      platforms.map((String id) => labels[id] ?? id).toList();
  if (named.first == 'Twitch') {
    final String extra =
        named.length > 1 ? ', plus ${named.skip(1).join(', ')}' : '';
    return "I already know you're set up on Twitch first$extra.";
  }
  return "I already know you're on ${named.join(', ')}.";
}

Map<String, dynamic> checkupGuestForBrainAttach({
  required String sessionId,
  required bool startedFromCheckup,
  String? checkupSessionId,
  List<Map<String, String>> checkupProfiles = const <Map<String, String>>[],
  Map<String, dynamic> checkupConfirmedAnswers = const <String, dynamic>{},
  Map<String, dynamic> answers = const <String, dynamic>{},
  String? checkupPresenceSummary,
  String? recommendedFocus,
  String? primaryOpportunity,
}) {
  final Object? rawPlatforms =
      checkupConfirmedAnswers['platforms'] ?? answers['platforms'];
  final List<String> platforms = rawPlatforms is List
      ? rawPlatforms.map((Object? e) => e.toString()).toList()
      : const <String>[];
  return <String, dynamic>{
    'guestKey': checkupSessionId ?? sessionId,
    'currentGuestKey': checkupSessionId ?? sessionId,
    'attachedUid': null,
    'profiles': checkupProfiles
        .map(
          (Map<String, String> row) => <String, dynamic>{
            'platform': row['platform'],
            'handleOrUrl': row['handleOrUrl'],
            'analysisStatus': 'not_provided',
          },
        )
        .toList(),
    'inferred': checkupPresenceSummary == null
        ? null
        : <String, dynamic>{'summary': checkupPresenceSummary},
    'confirmed': <String, dynamic>{
      'creatorType': checkupConfirmedAnswers['creator_type'],
      'platforms': platforms,
      'formats': checkupConfirmedAnswers['content_formats'],
    },
    'recommendedFocus': recommendedFocus,
    'primaryOpportunity': primaryOpportunity,
    'startedFromCheckup': startedFromCheckup,
  };
}

List<String> _stringList(Object? raw) {
  if (raw is! List) {
    return const <String>[];
  }
  return raw.map((Object? e) => e.toString()).where((String e) => e.isNotEmpty).toList();
}

List<TippyBrainInsight> _insights(Object? raw) {
  if (raw is! List) {
    return const <TippyBrainInsight>[];
  }
  return raw
      .whereType<Map>()
      .map((Map row) => TippyBrainInsight.fromJson(row.cast<String, dynamic>()))
      .where((TippyBrainInsight row) => row.statement.isNotEmpty)
      .toList();
}

List<Map<String, dynamic>> _mapList(Object? raw) {
  if (raw is! List) {
    return const <Map<String, dynamic>>[];
  }
  return raw
      .whereType<Map>()
      .map((Map row) => row.cast<String, dynamic>())
      .toList();
}

Map<String, dynamic>? _legacyPlatforms(Map<String, dynamic> json) {
  final Object? platforms = json['platforms'];
  if (platforms is! Map) {
    return null;
  }
  final Object? primary = platforms['primary'];
  if (primary is! Map) {
    return null;
  }
  if (primary['sourceType'] != 'user_declared') {
    return null;
  }
  return <String, dynamic>{
    'platforms': primary['value'],
    'profiles': const <Map<String, String>>[],
    'analyzedPlatforms': const <String>[],
  };
}

List<String> _unique(List<String> values) {
  final List<String> out = <String>[];
  for (final String raw in values) {
    final String value = raw.trim().toLowerCase();
    if (value.isEmpty || out.contains(value)) {
      continue;
    }
    out.add(value);
  }
  return out;
}

double _clampConfidence(Object? value) {
  final double n = value is num ? value.toDouble() : 0.5;
  if (n.isNaN) {
    return 0.5;
  }
  return n.clamp(0, 1);
}
