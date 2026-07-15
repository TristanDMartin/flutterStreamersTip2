import 'dart:collection';

/// Pure helpers for Tippy New Post caption / hashtag assist.

final RegExp _hashtagTokenPattern = RegExp(r'#([\w]+)');

String normalizeTippyHashtag(String raw) {
  final String trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final String withoutHash =
      trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
  final String cleaned = withoutHash.replaceAll(RegExp(r'[^\w]'), '');
  if (cleaned.isEmpty) {
    return '';
  }
  return '#$cleaned';
}

List<String> normalizeTippyHashtags(Iterable<String> rawTags) {
  final LinkedHashSet<String> unique = LinkedHashSet<String>();
  for (final String raw in rawTags) {
    final String normalized = normalizeTippyHashtag(raw);
    if (normalized.length > 1) {
      unique.add(normalized);
    }
  }
  return unique.toList(growable: false);
}

List<String> extractHashtagsFromText(String text) {
  final Iterable<RegExpMatch> matches = _hashtagTokenPattern.allMatches(text);
  return normalizeTippyHashtags(
    matches.map((RegExpMatch match) => match.group(0) ?? ''),
  );
}

String stripHashtagsFromCaption(String caption) {
  final String withoutTags =
      caption.replaceAll(_hashtagTokenPattern, ' ').replaceAll(RegExp(r'\s+'), ' ');
  return withoutTags.trim();
}

String appendHashtagsToCaption({
  required String caption,
  required List<String> hashtags,
}) {
  final List<String> normalized = normalizeTippyHashtags(hashtags);
  if (normalized.isEmpty) {
    return caption;
  }
  final Set<String> existing = extractHashtagsFromText(caption)
      .map((String tag) => tag.toLowerCase())
      .toSet();
  final List<String> toAdd = normalized
      .where((String tag) => !existing.contains(tag.toLowerCase()))
      .toList(growable: false);
  if (toAdd.isEmpty) {
    return caption;
  }
  final String trimmed = caption.trimRight();
  if (trimmed.isEmpty) {
    return toAdd.join(' ');
  }
  return '$trimmed ${toAdd.join(' ')}';
}

String replaceHashtagsInCaption({
  required String caption,
  required List<String> hashtags,
}) {
  final String base = stripHashtagsFromCaption(caption);
  final List<String> normalized = normalizeTippyHashtags(hashtags);
  if (normalized.isEmpty) {
    return base;
  }
  if (base.isEmpty) {
    return normalized.join(' ');
  }
  return '$base ${normalized.join(' ')}';
}

enum TippyHashtagApplyMode {
  addAll,
  addSelected,
  replace,
}

String applyTippyHashtags({
  required String caption,
  required List<String> allHashtags,
  required List<String> selectedHashtags,
  required TippyHashtagApplyMode mode,
}) {
  switch (mode) {
    case TippyHashtagApplyMode.addAll:
      return appendHashtagsToCaption(
        caption: caption,
        hashtags: allHashtags,
      );
    case TippyHashtagApplyMode.addSelected:
      return appendHashtagsToCaption(
        caption: caption,
        hashtags: selectedHashtags,
      );
    case TippyHashtagApplyMode.replace:
      return replaceHashtagsInCaption(
        caption: caption,
        hashtags: selectedHashtags.isEmpty ? allHashtags : selectedHashtags,
      );
  }
}
