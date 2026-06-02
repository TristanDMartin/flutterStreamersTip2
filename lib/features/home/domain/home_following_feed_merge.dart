import '../../../models/home_video.dart';

/// Firestore cursor wrapper used by home feed slices.
Map<String, dynamic>? nextCursorFromLastDocument(Object? lastDocument) {
  if (lastDocument == null) {
    return null;
  }
  return <String, dynamic>{'lastDoc': lastDocument};
}

/// Appends or replaces following-feed items for refresh vs pagination.
List<HomeVideo> mergeFollowingFeedPage({
  required List<HomeVideo> existing,
  required List<HomeVideo> pageVideos,
  required bool reset,
}) {
  if (reset) {
    return List<HomeVideo>.from(pageVideos);
  }
  return <HomeVideo>[...existing, ...pageVideos];
}

/// Dedupes following feed pages while preserving first-seen order.
List<HomeVideo> dedupeFollowingFeedVideos({
  required List<HomeVideo> existing,
  required List<HomeVideo> newVideos,
}) {
  final Map<String, HomeVideo> uniqueVideos = <String, HomeVideo>{};
  for (final HomeVideo video in existing) {
    if (video.id.isNotEmpty) {
      uniqueVideos[video.id] = video;
    }
  }
  for (final HomeVideo video in newVideos) {
    if (video.id.isNotEmpty && !uniqueVideos.containsKey(video.id)) {
      uniqueVideos[video.id] = video;
    }
  }
  return uniqueVideos.values.toList(growable: false);
}
