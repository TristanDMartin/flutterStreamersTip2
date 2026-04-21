/// Enum representing the different feed tabs in the home view
/// This is the single source of truth for feed state
enum FeedTab {
  /// For You feed - shows algorithmically curated videos
  forYou,

  /// Progression — creator gamification (reads shared Firestore summary; not a video feed)
  following,

  /// Threads feed - shows forum-style discussion threads
  threads,
}

/// Extension to provide consistent string representations
extension FeedTabExtension on FeedTab {
  static const List<FeedTab> homeTabs = <FeedTab>[
    FeedTab.forYou,
    FeedTab.following,
    FeedTab.threads,
  ];

  String get displayName {
    switch (this) {
      case FeedTab.forYou:
        return 'For You';
      case FeedTab.following:
        return 'Progression';
      case FeedTab.threads:
        return 'Threads';
    }
  }

  String get tabId {
    switch (this) {
      case FeedTab.forYou:
        return 'home/forYou';
      case FeedTab.following:
        return 'home/progression';
      case FeedTab.threads:
        return 'home/threads';
    }
  }

  bool get supportsVideoFeed {
    switch (this) {
      case FeedTab.forYou:
        return true;
      case FeedTab.following:
      case FeedTab.threads:
        return false;
    }
  }

  bool get supportsRefresh => this == FeedTab.forYou;

  static FeedTab fromDisplayName(String displayName) {
    return homeTabs.firstWhere(
      (FeedTab tab) => tab.displayName == displayName,
      orElse: () => FeedTab.forYou,
    );
  }
}
