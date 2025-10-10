/// Enum representing the different feed tabs in the home view
/// This is the single source of truth for feed state
enum FeedTab {
  /// For You feed - shows algorithmically curated videos
  forYou,

  /// Following feed - shows videos from users the current user follows
  following
}

/// Extension to provide consistent string representations
extension FeedTabExtension on FeedTab {
  String get displayName {
    switch (this) {
      case FeedTab.forYou:
        return 'For You';
      case FeedTab.following:
        return 'Following';
    }
  }

  String get tabId {
    switch (this) {
      case FeedTab.forYou:
        return 'home/forYou';
      case FeedTab.following:
        return 'home/following';
    }
  }
}
