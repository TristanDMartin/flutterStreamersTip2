import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gamification/gamification_providers.dart';
import '../gamification/missions/mission_engine.dart';
import '../gamification/models/user_progress_bundle.dart';
import 'data/academy_repository.dart';
import 'models/academy_models.dart';
import 'services/academy_search_service.dart';
import 'services/academy_site_catalog_service.dart';
import 'services/academy_xp_service.dart';

final academyRepositoryProvider = Provider<AcademyRepository>((Ref ref) {
  return AcademyRepository();
});

final academySiteCatalogServiceProvider =
    Provider<AcademySiteCatalogService>((Ref ref) {
  return AcademySiteCatalogService();
});

final academyXpServiceProvider = Provider<AcademyXpService>((Ref ref) {
  return AcademyXpService(
    repository: ref.watch(academyRepositoryProvider),
  );
});

final academySearchServiceProvider = Provider<AcademySearchService>((Ref ref) {
  return AcademySearchService();
});

final academyXpRewardsProvider = FutureProvider<AcademyXpRewards>((Ref ref) {
  return ref.watch(academyRepositoryProvider).fetchXpRewards();
});

final academyGuideSummariesProvider =
    FutureProvider<List<AcademyGuideSummary>>((Ref ref) async {
  final AcademyRepository repo = ref.watch(academyRepositoryProvider);
  final AcademySiteCatalogService catalog =
      ref.watch(academySiteCatalogServiceProvider);
  List<AcademyGuideSummary> firestoreGuides = const <AcademyGuideSummary>[];
  try {
    firestoreGuides = await repo.fetchGuideSummaries(limit: 200);
  } catch (_) {
    firestoreGuides = await repo.fetchCachedGuideSummaries();
  }
  final List<List<AcademyGuideSummary>> extras =
      await Future.wait(<Future<List<AcademyGuideSummary>>>[
    catalog.fetchRemoteCatalogGuides(),
    catalog.fetchSitemapGuides(),
    catalog.loadBundledGuides(),
  ]);
  return catalog.mergeGuides(
    firestoreGuides: firestoreGuides,
    remoteCatalog: extras[0],
    sitemapGuides: extras[1],
    bundledGuides: extras[2],
  );
});

final academyCategoriesProvider =
    FutureProvider<List<AcademyCategory>>((Ref ref) async {
  final AcademyRepository repo = ref.watch(academyRepositoryProvider);
  final AcademySiteCatalogService catalog =
      ref.watch(academySiteCatalogServiceProvider);
  List<AcademyCategory> firestoreCategories = const <AcademyCategory>[];
  try {
    firestoreCategories = await repo.fetchCategories();
  } catch (_) {
    firestoreCategories = const <AcademyCategory>[];
  }
  final List<AcademyCategory> bundled = await catalog.loadBundledCategories();
  return catalog.mergeCategories(
    firestoreCategories: firestoreCategories,
    bundledCategories: bundled,
  );
});

final academyPathsProvider = FutureProvider<List<AcademyPath>>((Ref ref) async {
  return ref.watch(academyRepositoryProvider).fetchPaths();
});

final academyUserProgressProvider =
    StreamProvider<List<AcademyUserProgress>>((Ref ref) {
  final User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream<List<AcademyUserProgress>>.value(
      const <AcademyUserProgress>[],
    );
  }
  return ref.watch(academyRepositoryProvider).watchUserProgress(user.uid);
});

final academySavedGuidesProvider =
    FutureProvider<List<AcademyUserProgress>>((Ref ref) async {
  final User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return const <AcademyUserProgress>[];
  }
  return ref.watch(academyRepositoryProvider).fetchSavedGuides(user.uid);
});

final academyDiscoverCardStatusProvider =
    Provider<AcademyDiscoverCardStatus>((Ref ref) {
  final AsyncValue<List<AcademyUserProgress>> progressAsync =
      ref.watch(academyUserProgressProvider);
  final AsyncValue<List<AcademyPath>> pathsAsync =
      ref.watch(academyPathsProvider);
  final List<AcademyUserProgress> progress =
      progressAsync.valueOrNull ?? const <AcademyUserProgress>[];
  final List<AcademyPath> paths =
      pathsAsync.valueOrNull ?? const <AcademyPath>[];
  if (progress.isEmpty) {
    return const AcademyDiscoverCardStatus(
      headline: 'Start your creator journey',
      actionLabel: 'Start Learning',
    );
  }
  final DateTime weekStart =
      DateTime.now().subtract(const Duration(days: 7));
  final int completedThisWeek = progress
      .where(
        (AcademyUserProgress p) =>
            p.isCompleted &&
            p.completedAt != null &&
            p.completedAt!.isAfter(weekStart),
      )
      .length;
  if (completedThisWeek > 0) {
    return AcademyDiscoverCardStatus(
      headline: '$completedThisWeek lessons completed this week',
      actionLabel: 'Continue learning',
    );
  }
  for (final AcademyPath path in paths) {
    final int completedInPath = progress
        .where(
          (AcademyUserProgress p) =>
              p.isCompleted && path.lessonIds.contains(p.lessonId),
        )
        .length;
    if (completedInPath > 0 && completedInPath < path.lessonIds.length) {
      return AcademyDiscoverCardStatus(
        headline: 'Continue: ${path.title}',
        actionLabel: 'Continue learning',
      );
    }
  }
  return const AcademyDiscoverCardStatus(
    headline: 'Explore the Academy',
    actionLabel: 'Start Learning',
  );
});

final academyHomeSnapshotProvider =
    FutureProvider<AcademyHomeSnapshot>((Ref ref) async {
  final AcademyRepository repo = ref.watch(academyRepositoryProvider);
  final List<Object?> results = await Future.wait(<Future<Object?>>[
    ref.watch(academyCategoriesProvider.future),
    ref.watch(academyGuideSummariesProvider.future),
    repo.fetchPaths(),
    repo.fetchXpRewards(),
  ]);
  return AcademyHomeSnapshot(
    categories: results[0]! as List<AcademyCategory>,
    guides: results[1]! as List<AcademyGuideSummary>,
    paths: results[2]! as List<AcademyPath>,
    xpRewards: results[3]! as AcademyXpRewards,
  );
});

final academyQuestSectionsProvider = Provider<List<MissionSection>>((Ref ref) {
  final UserProgressBundle? bundle =
      ref.watch(userProgressBundleProvider).valueOrNull;
  final User? user = FirebaseAuth.instance.currentUser;
  if (bundle == null || user == null) {
    return const <MissionSection>[];
  }
  return MissionEngine.resolveSections(bundle, user.uid, DateTime.now());
});

class AcademyDiscoverCardStatus {
  const AcademyDiscoverCardStatus({
    required this.headline,
    required this.actionLabel,
  });

  final String headline;
  final String actionLabel;
}

class AcademyHomeSnapshot {
  const AcademyHomeSnapshot({
    required this.categories,
    required this.guides,
    required this.paths,
    required this.xpRewards,
  });

  final List<AcademyCategory> categories;
  final List<AcademyGuideSummary> guides;
  final List<AcademyPath> paths;
  final AcademyXpRewards xpRewards;
}

int academyCompletedLessonCount({
  required List<AcademyUserProgress> progress,
  Iterable<String> lessonIds = const <String>[],
}) {
  final Set<String> ids = lessonIds.toSet();
  return progress
      .where(
        (AcademyUserProgress p) =>
            p.isCompleted &&
            (ids.isEmpty || ids.contains(p.lessonId)),
      )
      .length;
}

double academyCompletionPercent({
  required int completed,
  required int total,
}) {
  if (total <= 0) {
    return 0;
  }
  return (completed / total).clamp(0, 1);
}

Map<String, AcademyCategory> academyCategoriesById(
  List<AcademyCategory> categories,
) {
  return <String, AcademyCategory>{
    for (final AcademyCategory c in categories) c.id: c,
  };
}

final academyGuideProvider =
    FutureProvider.family<AcademyGuideSummary?, String>((Ref ref, String id) async {
  final AcademyRepository repo = ref.watch(academyRepositoryProvider);
  final AcademyGuideSummary? fromFirestore = await repo.fetchGuideById(id);
  if (fromFirestore != null) {
    return fromFirestore;
  }
  final List<AcademyGuideSummary> guides =
      await ref.watch(academyGuideSummariesProvider.future);
  for (final AcademyGuideSummary guide in guides) {
    if (guide.id == id || guide.slug == id || guide.sitePath == '/$id') {
      return guide;
    }
  }
  return null;
});

final academyGuideLessonsProvider =
    FutureProvider.family<List<AcademyLessonSummary>, String>(
        (Ref ref, String guideId) {
  return ref
      .watch(academyRepositoryProvider)
      .fetchLessonSummariesForGuide(guideId);
});

final academyLessonProvider =
    FutureProvider.family<AcademyLesson?, String>((Ref ref, String id) {
  return ref.watch(academyRepositoryProvider).fetchLessonById(id);
});

final academyPathProvider =
    FutureProvider.family<AcademyPath?, String>((Ref ref, String id) {
  return ref.watch(academyRepositoryProvider).fetchPathById(id);
});
