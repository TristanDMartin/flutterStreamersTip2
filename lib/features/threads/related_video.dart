/// Related-video helpers for forum/thread pages.
/// Prefer canonical video IDs over stored absolute URLs.
library;

final RegExp _relatedVideoMd = RegExp(
  r'\n?---\n+\*\*Related Video:\*\*[^\n]*',
  caseSensitive: false,
);
final RegExp _relatedVideoInline = RegExp(
  r'\*\*Related Video:\*\*\s*\[[^\]]*\]\([^)]*\)',
  caseSensitive: false,
);
final RegExp _videoPathId = RegExp(
  r'/video/([A-Za-z0-9_-]+)',
  caseSensitive: false,
);

/// Strip legacy Related Video markdown from thread body for display.
String stripRelatedVideoMarkdown(String content) {
  if (content.isEmpty) {
    return '';
  }
  return content
      .replaceAll(_relatedVideoMd, '')
      .replaceAll(_relatedVideoInline, '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// Recover a video id from legacy markdown when fields are missing.
String? extractVideoIdFromRelatedMarkdown(String? content) {
  if (content == null || content.isEmpty) {
    return null;
  }
  final Match? match = _videoPathId.firstMatch(content);
  final String? id = match?.group(1);
  if (id == null || id.isEmpty) {
    return null;
  }
  return id;
}

String? resolveRelatedVideoId({
  String? sourceVideoId,
  String? linkedVideoId,
  String? relatedVideoId,
  String? content,
}) {
  final String fromFields = (relatedVideoId ?? sourceVideoId ?? linkedVideoId ?? '')
      .trim();
  if (fromFields.isNotEmpty) {
    return fromFields;
  }
  return extractVideoIdFromRelatedMarkdown(content);
}
