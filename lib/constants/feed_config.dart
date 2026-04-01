/// Feed configuration - algorithm and ordering
///
/// When [usePersonalizationAlgorithm] is false, feed shows raw newest-first
/// order. Set to true when algorithm is ready for TikTok-style personalized feed.
class FeedConfig {
  FeedConfig._();
  static const bool usePersonalizationAlgorithm = false;
}
