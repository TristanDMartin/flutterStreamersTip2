import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/features/academy/models/academy_models.dart';
import 'package:streamers_tip/features/academy/services/academy_search_service.dart';

void main() {
  group('AcademySearchService', () {
    final AcademySearchService service = AcademySearchService();
    final List<AcademyGuideSummary> guides = <AcademyGuideSummary>[
      const AcademyGuideSummary(
        id: 'g1',
        title: 'OBS Setup for Beginners',
        description: 'Configure scenes and audio for Twitch.',
        categoryId: 'streaming-setup',
        tags: <String>['OBS', 'streaming'],
        platforms: <String>['Twitch'],
        keywords: <String>['audio setup'],
        lessonCount: 3,
      ),
      const AcademyGuideSummary(
        id: 'g2',
        title: 'TikTok Hooks That Convert',
        description: 'Short-form growth strategies.',
        categoryId: 'audience-growth',
        tags: <String>['TikTok', 'hooks'],
        platforms: <String>['TikTok'],
        keywords: <String>['content calendar'],
        lessonCount: 2,
      ),
    ];
    final Map<String, AcademyCategory> categories = <String, AcademyCategory>{
      'streaming-setup': const AcademyCategory(
        id: 'streaming-setup',
        name: 'Streaming Setup',
        description: 'Gear and software',
      ),
      'audience-growth': const AcademyCategory(
        id: 'audience-growth',
        name: 'Audience Growth',
        description: 'Grow faster',
      ),
    };

    test('matches guide title and platform', () {
      final List<AcademySearchResult> results = service.search(
        query: 'OBS',
        guides: guides,
        categoriesById: categories,
      );
      expect(results, isNotEmpty);
      expect(results.first.guide.id, 'g1');
    });

    test('matches category and tags', () {
      final List<AcademySearchResult> results = service.search(
        query: 'TikTok hooks',
        guides: guides,
        categoriesById: categories,
      );
      expect(results.any((AcademySearchResult r) => r.guide.id == 'g2'), isTrue);
    });

    test('returns empty for unknown query', () {
      final List<AcademySearchResult> results = service.search(
        query: 'nonexistent topic xyz',
        guides: guides,
        categoriesById: categories,
      );
      expect(results, isEmpty);
    });

    test('empty query browses all guides', () {
      final List<AcademySearchResult> results = service.search(
        query: '',
        guides: guides,
        categoriesById: categories,
      );
      expect(results, hasLength(2));
      expect(
        results.map((AcademySearchResult r) => r.guide.id),
        containsAll(<String>['g1', 'g2']),
      );
    });
  });
}
