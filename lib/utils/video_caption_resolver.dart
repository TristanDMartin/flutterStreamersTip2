/// Resolves the caption text shown on feed / playback surfaces.
String resolveVideoCaptionFromFirestoreData(Map<String, dynamic> data) {
  final Object? metadataRaw = data['metadata'];
  final Map<String, dynamic>? metadata = metadataRaw is Map<String, dynamic>
      ? metadataRaw
      : metadataRaw is Map
          ? Map<String, dynamic>.from(metadataRaw)
          : null;
  final List<Object?> candidates = <Object?>[
    data['caption'],
    data['title'],
    data['description'],
    metadata?['preview_manual_caption'],
  ];
  for (final Object? candidate in candidates) {
    if (candidate is String && candidate.trim().isNotEmpty) {
      return candidate.trim();
    }
  }
  return '';
}

/// Caption written to Firestore during publish (post caption + preview fallback).
String resolveUploadCaption({
  required String caption,
  Map<String, dynamic>? additionalMetadata,
}) {
  final String trimmedCaption = caption.trim();
  if (trimmedCaption.isNotEmpty) {
    return trimmedCaption;
  }
  final Object? previewRaw = additionalMetadata?['preview_manual_caption'];
  if (previewRaw is String && previewRaw.trim().isNotEmpty) {
    return previewRaw.trim();
  }
  return trimmedCaption;
}

/// On-video overlay text from preview editor metadata (separate from description).
String resolveVideoOverlayCaptionFromFirestoreData(Map<String, dynamic> data) {
  final Object? metadataRaw = data['metadata'];
  final Map<String, dynamic>? metadata = metadataRaw is Map<String, dynamic>
      ? metadataRaw
      : metadataRaw is Map
          ? Map<String, dynamic>.from(metadataRaw)
          : null;
  final Object? manualRaw = metadata?['preview_manual_caption'];
  if (manualRaw is String && manualRaw.trim().isNotEmpty) {
    return manualRaw.trim();
  }
  return '';
}

/// Text shown under the creator row on the home feed.
String resolveFeedDisplayCaption({
  required String caption,
  required String overlayCaption,
}) {
  final String trimmedCaption = caption.trim();
  if (trimmedCaption.isNotEmpty) {
    return trimmedCaption;
  }
  return overlayCaption.trim();
}
