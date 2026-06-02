/// Computes neighbor indices to warm around [index] in a feed.
///
/// [direction] < 0 biases backward neighbors first; >= 0 biases forward first.
List<int> computePlaybackPreloadIndices({
  required int index,
  required int videoCount,
  required int direction,
  required int backwardRadius,
  required int forwardRadius,
}) {
  final List<int> orderedOffsets = <int>[0];
  if (direction < 0) {
    for (int offset = -1; offset >= -backwardRadius; offset--) {
      orderedOffsets.add(offset);
    }
    for (int offset = 1; offset <= forwardRadius; offset++) {
      orderedOffsets.add(offset);
    }
  } else {
    for (int offset = 1; offset <= forwardRadius; offset++) {
      orderedOffsets.add(offset);
    }
    for (int offset = -1; offset >= -backwardRadius; offset--) {
      orderedOffsets.add(offset);
    }
  }
  final Set<int> seen = <int>{};
  return orderedOffsets
      .map((int offset) => index + offset)
      .where(
        (int candidate) =>
            candidate >= 0 && candidate < videoCount && seen.add(candidate),
      )
      .toList(growable: false);
}

/// Suppresses redundant preload bursts during rapid rebuilds / swipes.
class PlaybackPreloadBurstGuard {
  static const Duration burstWindow = Duration(milliseconds: 180);

  int? _lastCenterIndex;
  String? _lastCenterVideoId;
  DateTime? _lastRequestedAt;

  bool shouldSkipDuplicateBurst({
    required int index,
    required String centerVideoId,
    DateTime? now,
  }) {
    final DateTime effectiveNow = now ?? DateTime.now();
    final DateTime? lastRequestAt = _lastRequestedAt;
    return _lastCenterIndex == index &&
        _lastCenterVideoId == centerVideoId &&
        lastRequestAt != null &&
        effectiveNow.difference(lastRequestAt) < burstWindow;
  }

  void recordRequest({
    required int index,
    required String centerVideoId,
    DateTime? now,
  }) {
    _lastCenterIndex = index;
    _lastCenterVideoId = centerVideoId;
    _lastRequestedAt = now ?? DateTime.now();
  }
}
