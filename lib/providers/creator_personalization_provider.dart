import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/creator_personalization_service.dart';
import 'current_user_provider.dart';

final Provider<CreatorPersonalizationService>
    creatorPersonalizationServiceProvider =
    Provider<CreatorPersonalizationService>(
  (Ref ref) => CreatorPersonalizationService(),
);

final StreamProvider<CreatorPersonalizationProfile>
    creatorPersonalizationProvider =
    StreamProvider<CreatorPersonalizationProfile>((Ref ref) {
  final String? userId = ref.watch(signedInUserIdProvider);
  if (userId == null || userId.isEmpty) {
    return Stream<CreatorPersonalizationProfile>.value(
      CreatorPersonalizationProfile.empty,
    );
  }
  return ref
      .watch(creatorPersonalizationServiceProvider)
      .watchProfile(userId);
});
