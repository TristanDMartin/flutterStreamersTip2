import '../models/academy_models.dart';

class AcademySearchService {
  List<AcademySearchResult> search({
    required String query,
    required List<AcademyGuideSummary> guides,
    required Map<String, AcademyCategory> categoriesById,
    Map<String, List<AcademyLessonSummary>> lessonsByGuideId =
        const <String, List<AcademyLessonSummary>>{},
  }) {
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const <AcademySearchResult>[];
    }
    final List<AcademySearchResult> results = <AcademySearchResult>[];
    for (final AcademyGuideSummary guide in guides) {
      final List<String> matched = <String>[];
      if (_contains(guide.title, normalized)) {
        matched.add('title');
      }
      if (_contains(guide.description, normalized)) {
        matched.add('description');
      }
      if (guide.tags.any((String t) => _contains(t, normalized))) {
        matched.add('tags');
      }
      if (guide.platforms.any((String p) => _contains(p, normalized))) {
        matched.add('platforms');
      }
      if (guide.keywords.any((String k) => _contains(k, normalized))) {
        matched.add('keywords');
      }
      if (_contains(difficultyLabel(guide.difficulty), normalized)) {
        matched.add('difficulty');
      }
      final AcademyCategory? category = categoriesById[guide.categoryId];
      if (category != null) {
        if (_contains(category.name, normalized)) {
          matched.add('category');
        }
        if (category.keywords.any((String k) => _contains(k, normalized))) {
          matched.add('categoryKeywords');
        }
      }
      final List<AcademyLessonSummary> lessons =
          lessonsByGuideId[guide.id] ?? const <AcademyLessonSummary>[];
      if (lessons.any((AcademyLessonSummary l) => _contains(l.title, normalized))) {
        matched.add('lesson');
      }
      if (matched.isNotEmpty) {
        results.add(
          AcademySearchResult(
            guide: guide,
            categoryName: category?.name,
            matchedFields: matched,
          ),
        );
      }
    }
    results.sort((AcademySearchResult a, AcademySearchResult b) {
      final int scoreA = _score(a, normalized);
      final int scoreB = _score(b, normalized);
      return scoreB.compareTo(scoreA);
    });
    return results;
  }

  int _score(AcademySearchResult result, String query) {
    int score = 0;
    if (result.matchedFields.contains('title')) {
      score += 100;
    }
    if (result.matchedFields.contains('tags')) {
      score += 40;
    }
    if (result.matchedFields.contains('platforms')) {
      score += 35;
    }
    if (result.matchedFields.contains('category')) {
      score += 30;
    }
    if (result.matchedFields.contains('lesson')) {
      score += 25;
    }
    if (result.guide.title.toLowerCase().startsWith(query)) {
      score += 20;
    }
    return score;
  }

  bool _contains(String? value, String query) {
    if (value == null || value.isEmpty) {
      return false;
    }
    return value.toLowerCase().contains(query);
  }
}
