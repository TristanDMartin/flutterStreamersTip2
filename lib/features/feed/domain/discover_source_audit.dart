import 'package:flutter/foundation.dart';

import '../../../utils/category_schema.dart';
import '../../../utils/video_document_rules.dart';

/// Debug snapshot comparing Home vs Discover candidate sets.
class DiscoverSourceAuditReport {
  const DiscoverSourceAuditReport({
    required this.selectedCategory,
    required this.homeFeedCount,
    required this.totalFetched,
    required this.eligibleCount,
    required this.matchingCount,
    required this.deletedVideoCount,
    required this.missingCreatorCount,
    required this.categoryBreakdown,
    required this.skipReasonCounts,
  });

  final String selectedCategory;
  final int homeFeedCount;
  final int totalFetched;
  final int eligibleCount;
  final int matchingCount;
  final int deletedVideoCount;
  final int missingCreatorCount;
  final Map<String, int> categoryBreakdown;
  final Map<String, int> skipReasonCounts;
}

DiscoverSourceAuditReport buildDiscoverSourceAuditReport({
  required String selectedCategory,
  required int homeFeedCount,
  required Iterable<Map<String, dynamic>> rawDocs,
  required Iterable<Map<String, dynamic>> eligibleDocs,
  required Iterable<Map<String, dynamic>> matchingDocs,
}) {
  final Map<String, int> categoryBreakdown = <String, int>{};
  final Map<String, int> skipReasonCounts = <String, int>{};
  int deletedVideoCount = 0;
  int missingCreatorCount = 0;

  for (final Map<String, dynamic> data in rawDocs) {
    final CanonicalCategory category = readCanonicalCategoryFromVideo(data);
    final String slug =
        category.isPopulated ? category.categoryId : 'uncategorized';
    categoryBreakdown[slug] = (categoryBreakdown[slug] ?? 0) + 1;

    if (data['isDeleted'] == true || data['deleted'] == true) {
      deletedVideoCount++;
    }
    final String? reason = rejectDiscoverVideoCandidate(data);
    if (reason != null) {
      skipReasonCounts[reason] = (skipReasonCounts[reason] ?? 0) + 1;
    }
    if (_creatorLabelFromData(data).isEmpty) {
      missingCreatorCount++;
    }
  }

  return DiscoverSourceAuditReport(
    selectedCategory: selectedCategory,
    homeFeedCount: homeFeedCount,
    totalFetched: rawDocs.length,
    eligibleCount: eligibleDocs.length,
    matchingCount: matchingDocs.length,
    deletedVideoCount: deletedVideoCount,
    missingCreatorCount: missingCreatorCount,
    categoryBreakdown: categoryBreakdown,
    skipReasonCounts: skipReasonCounts,
  );
}

String _creatorLabelFromData(Map<String, dynamic> data) {
  final String? username = data['creator_username'] as String? ??
      data['creatorUsername'] as String? ??
      data['username'] as String?;
  if (username != null && username.trim().isNotEmpty) {
    return username.trim();
  }
  return (data['creator_display_name'] as String?) ??
      (data['creatorDisplayName'] as String?) ??
      '';
}

void logDiscoverSourceAudit(DiscoverSourceAuditReport report) {
  if (!kDebugMode) {
    return;
  }
  final String breakdown = report.categoryBreakdown.entries
      .map((MapEntry<String, int> e) => '${e.key}: ${e.value}')
      .join(', ');
  final String skips = report.skipReasonCounts.entries
      .map((MapEntry<String, int> e) => '${e.key}: ${e.value}')
      .join(', ');
  debugPrint(
    'DISCOVER_SOURCE_AUDIT '
    'selected=${report.selectedCategory} '
    'homeFeedCount=${report.homeFeedCount} '
    'discoverFeedCount=${report.matchingCount} '
    'totalFetched=${report.totalFetched} '
    'eligible=${report.eligibleCount} '
    'deletedVideoCount=${report.deletedVideoCount} '
    'missingCreatorCount=${report.missingCreatorCount} '
    'categoryBreakdown={$breakdown} '
    'skipReasons={$skips}',
  );
}
