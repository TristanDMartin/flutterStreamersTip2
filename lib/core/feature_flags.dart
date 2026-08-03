class FeatureFlags {
  const FeatureFlags._();

  static const bool crossPostingEnabled = false;
  static const bool autoCaptions = false;
  static const bool videoDownload = false;
  static const bool watermarkExport = false;
  static const bool discoverFilters = false;
  static const bool chatReplies = true;
  static const bool trendingInvite = false;
  static const bool advancedShare = false;
  static const bool linkedPlatforms = false;
  static const bool tippyPlannerSync = true;
  static const bool progression = true;

  /// Creator Threads v2 shell (compile-time / dart-define).
  static const bool threadsV2Ui = bool.fromEnvironment(
    'THREADS_V2_UI',
    defaultValue: true,
  );
  static const bool threadsV2Reads = bool.fromEnvironment(
    'THREADS_V2_READS',
    defaultValue: true,
  );
  static const bool threadsV2Writes = bool.fromEnvironment(
    'THREADS_V2_WRITES',
    defaultValue: true,
  );
  static const bool threadsV2Cutover = bool.fromEnvironment(
    'THREADS_V2_CUTOVER',
    defaultValue: false,
  );
}
