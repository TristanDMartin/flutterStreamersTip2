import 'package:flutter_test/flutter_test.dart';

import 'package:streamers_tip/features/academy/models/academy_models.dart';
import 'package:streamers_tip/features/academy/services/academy_site_catalog_service.dart';

void main() {
  group('AcademySiteCatalogService.mergeGuides', () {
    final AcademySiteCatalogService service = AcademySiteCatalogService();

    test('firestore guides win over bundled duplicates', () {
      const AcademyGuideSummary firestore = AcademyGuideSummary(
        id: 'obs-setup',
        title: 'Firestore OBS',
        description: 'from firestore',
        categoryId: 'obs-and-setup',
        lessonCount: 3,
        contentMode: 'native',
      );
      const AcademyGuideSummary bundled = AcademyGuideSummary(
        id: 'obs-setup',
        title: 'Bundled OBS',
        description: 'from bundle',
        categoryId: 'beginner',
        webUrl: 'https://streamerstip.com/obs-setup',
        contentMode: 'website',
      );
      final List<AcademyGuideSummary> actual = service.mergeGuides(
        firestoreGuides: const <AcademyGuideSummary>[firestore],
        bundledGuides: const <AcademyGuideSummary>[bundled],
      );
      expect(actual, hasLength(1));
      expect(actual.single.title, 'Firestore OBS');
      expect(actual.single.contentMode, 'native');
    });

    test('adds sitemap-only pages that are not in firestore', () {
      const AcademyGuideSummary firestore = AcademyGuideSummary(
        id: 'obs-setup',
        title: 'OBS Setup',
        description: 'native',
        categoryId: 'obs-and-setup',
      );
      const AcademyGuideSummary sitemap = AcademyGuideSummary(
        id: 'kick-account-setup',
        title: 'Kick Account Setup',
        description: 'from sitemap',
        categoryId: 'kick',
        webUrl: 'https://streamerstip.com/kick-account-setup',
        contentMode: 'website',
      );
      final List<AcademyGuideSummary> actual = service.mergeGuides(
        firestoreGuides: const <AcademyGuideSummary>[firestore],
        sitemapGuides: const <AcademyGuideSummary>[sitemap],
      );
      expect(actual.map((AcademyGuideSummary g) => g.id),
          containsAll(<String>['obs-setup', 'kick-account-setup']));
    });
  });

  group('AcademySiteCatalogService.mergePaths', () {
    final AcademySiteCatalogService service = AcademySiteCatalogService();

    test('firestore paths win over bundled duplicates', () {
      const AcademyPath firestore = AcademyPath(
        id: 'beginner',
        title: 'Firestore Beginner',
        description: 'from firestore',
        guideIds: <String>['obs-setup'],
        lessonIds: <String>['obs-setup__web'],
        sortOrder: 10,
      );
      const AcademyPath bundled = AcademyPath(
        id: 'beginner',
        title: 'Bundled Beginner',
        description: 'from bundle',
        guideIds: <String>['new-to-streaming'],
        lessonIds: <String>['new-to-streaming__web'],
        sortOrder: 10,
      );
      final List<AcademyPath> actual = service.mergePaths(
        firestorePaths: const <AcademyPath>[firestore],
        bundledPaths: const <AcademyPath>[bundled],
      );
      expect(actual, hasLength(1));
      expect(actual.single.title, 'Firestore Beginner');
      expect(actual.single.guideIds, <String>['obs-setup']);
    });

    test('bundled fills when firestore is empty', () {
      const AcademyPath bundled = AcademyPath(
        id: 'beginner',
        title: 'Beginner Creator Path',
        description: 'from bundle',
        guideIds: <String>['obs-setup'],
        lessonIds: <String>['obs-setup__web'],
        sortOrder: 10,
      );
      final List<AcademyPath> actual = service.mergePaths(
        firestorePaths: const <AcademyPath>[],
        bundledPaths: const <AcademyPath>[bundled],
      );
      expect(actual.map((AcademyPath p) => p.id), <String>['beginner']);
      expect(actual.single.stepCount, 1);
      expect(actual.single.steps.single.isWebsiteBacked, isTrue);
      expect(actual.single.steps.single.displayGuideId, 'obs-setup');
    });
  });

  group('AcademyGuideSummary', () {
    test('isWebsiteBacked when web content has no lessons', () {
      const AcademyGuideSummary guide = AcademyGuideSummary(
        id: 'obs-setup',
        title: 'OBS Setup',
        description: 'desc',
        categoryId: 'obs-and-setup',
        webUrl: 'https://streamerstip.com/obs-setup',
        contentMode: 'website',
      );
      expect(guide.isWebsiteBacked, isTrue);
      expect(guide.shareUrl, 'https://streamerstip.com/obs-setup');
    });
  });
}
