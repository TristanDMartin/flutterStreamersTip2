class TippyContextStripData {
  const TippyContextStripData({
    this.nicheLabel,
    this.cadenceLabel,
    this.topGoalLabel,
    this.memoryReady = false,
  });

  final String? nicheLabel;
  final String? cadenceLabel;
  final String? topGoalLabel;
  final bool memoryReady;

  factory TippyContextStripData.fromJson(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return const TippyContextStripData();
    }
    return TippyContextStripData(
      nicheLabel: _readString(raw['nicheLabel']),
      cadenceLabel: _readString(raw['cadenceLabel']),
      topGoalLabel: _readString(raw['topGoalLabel']),
      memoryReady: raw['memoryReady'] == true,
    );
  }

  bool get hasContent =>
      (nicheLabel?.isNotEmpty ?? false) ||
      (cadenceLabel?.isNotEmpty ?? false) ||
      (topGoalLabel?.isNotEmpty ?? false);
}

class TippyUiCardData {
  const TippyUiCardData({
    required this.type,
    required this.title,
    required this.body,
    this.planId,
    this.ctaLabel,
    this.ctaAction,
    this.ctaValue,
  });

  final String type;
  final String title;
  final String body;
  final String? planId;
  final String? ctaLabel;
  final String? ctaAction;
  final String? ctaValue;

  factory TippyUiCardData.fromJson(Map<String, dynamic> raw) {
    final Map<String, dynamic>? cta =
        raw['cta'] is Map ? Map<String, dynamic>.from(raw['cta'] as Map) : null;
    return TippyUiCardData(
      type: _readString(raw['type']) ?? 'insight',
      title: _readString(raw['title']) ?? '',
      body: _readString(raw['body']) ?? '',
      planId: _readString(raw['planId']),
      ctaLabel: cta == null ? null : _readString(cta['label']),
      ctaAction: cta == null ? null : _readString(cta['action']),
      ctaValue: cta == null ? null : _readString(cta['value']),
    );
  }
}

class TippyUiPayload {
  const TippyUiPayload({
    required this.contextStrip,
    required this.cards,
    required this.suggestedPrompts,
  });

  final TippyContextStripData contextStrip;
  final List<TippyUiCardData> cards;
  final List<String> suggestedPrompts;

  static const TippyUiPayload empty = TippyUiPayload(
    contextStrip: TippyContextStripData(),
    cards: <TippyUiCardData>[],
    suggestedPrompts: <String>[],
  );

  factory TippyUiPayload.fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return TippyUiPayload.empty;
    }
    final List<TippyUiCardData> cards = <TippyUiCardData>[];
    if (raw['cards'] is List) {
      for (final Object? item in raw['cards'] as List<Object?>) {
        if (item is Map<String, dynamic>) {
          cards.add(TippyUiCardData.fromJson(item));
        } else if (item is Map) {
          cards.add(
            TippyUiCardData.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return TippyUiPayload(
      contextStrip: TippyContextStripData.fromJson(
        raw['contextStrip'] is Map<String, dynamic>
            ? raw['contextStrip'] as Map<String, dynamic>
            : raw['contextStrip'] is Map
                ? Map<String, dynamic>.from(raw['contextStrip'] as Map)
                : null,
      ),
      cards: cards,
      suggestedPrompts: _readStringList(raw['suggestedPrompts']),
    );
  }
}

String? _readString(Object? raw) {
  if (raw is String && raw.trim().isNotEmpty) {
    return raw.trim();
  }
  return null;
}

List<String> _readStringList(Object? raw) {
  if (raw is! List) {
    return const <String>[];
  }
  return raw
      .map((dynamic item) => item.toString().trim())
      .where((String value) => value.isNotEmpty)
      .toList(growable: false);
}
