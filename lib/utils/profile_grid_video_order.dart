import '../models/home_video.dart';

bool isPromoFixtureVideo(Map<String, dynamic> data) {
  if (data['isPromoFixture'] == true || data['promoFixture'] == true) {
    return true;
  }
  final Object? tags = data['tags'];
  if (tags is Iterable) {
    return tags.any((Object? tag) => tag?.toString() == 'promo_fixture');
  }
  return false;
}

bool promoFixtureHasThumbnail(Map<String, dynamic> data) {
  final String? thumbnailUrl =
      (data['thumbnailUrl'] ?? data['thumbnailURL']) as String?;
  if (thumbnailUrl != null && thumbnailUrl.trim().isNotEmpty) {
    return true;
  }
  final Object? thumbnails = data['thumbnails'];
  if (thumbnails is Map) {
    return thumbnails.values.any(
      (Object? value) => value is String && value.trim().isNotEmpty,
    );
  }
  return false;
}

List<HomeVideo> orderProfileGridVideos(List<HomeVideo> videos) {
  final List<HomeVideo> ordered = List<HomeVideo>.from(videos);
  ordered.sort((HomeVideo a, HomeVideo b) {
    final bool aPromo = _isPromoHomeVideo(a);
    final bool bPromo = _isPromoHomeVideo(b);
    if (aPromo != bPromo) {
      return aPromo ? -1 : 1;
    }
    final int aMs = a.createdAt?.millisecondsSinceEpoch ?? 0;
    final int bMs = b.createdAt?.millisecondsSinceEpoch ?? 0;
    return bMs.compareTo(aMs);
  });
  return ordered;
}

bool shouldLeadProfileGridWithPromoThumbnails({
  required bool isViewingOwnProfile,
  required List<HomeVideo> videos,
}) {
  if (!isViewingOwnProfile || videos.isEmpty) {
    return false;
  }
  return videos.any(
    (HomeVideo video) =>
        _isPromoHomeVideo(video) &&
        ((video.thumbnailURL ?? '').trim().isNotEmpty ||
            video.thumbnails != null),
  );
}

bool _isPromoHomeVideo(HomeVideo video) {
  return video.tags.contains('promo_fixture') ||
      video.id.startsWith('promo_fixture') ||
      video.categoryId == 'promo_fixture';
}
