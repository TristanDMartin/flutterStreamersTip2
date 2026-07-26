import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/academy_models.dart';

class AcademyRepository {
  AcademyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String categoriesCollection = 'academyCategories';
  static const String guidesCollection = 'academyGuides';
  static const String lessonsCollection = 'academyLessons';
  static const String pathsCollection = 'academyPaths';
  static const String progressCollection = 'academyUserProgress';
  static const String configCollection = 'academyConfig';

  static const String _cacheCategoriesKey = 'academy_cache_categories_v1';
  static const String _cacheGuidesKey = 'academy_cache_guides_v1';
  static const String _cachePathsKey = 'academy_cache_paths_v1';

  Future<List<AcademyCategory>> fetchCategories({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final List<AcademyCategory>? cached = await _readCachedCategories();
      if (cached != null && cached.isNotEmpty) {
        unawaited(_refreshCategoriesCache());
        return cached;
      }
    }
    return _refreshCategoriesCache();
  }

  Future<List<AcademyCategory>> _refreshCategoriesCache() async {
    final QuerySnapshot<Map<String, dynamic>> snap =
        await _queryPublishedOrdered(categoriesCollection);
    final List<AcademyCategory> categories = snap.docs
        .map(AcademyCategory.fromFirestore)
        .where((AcademyCategory c) => c.isPublished)
        .toList(growable: true)
      ..sort(
        (AcademyCategory a, AcademyCategory b) =>
            a.sortOrder.compareTo(b.sortOrder),
      );
    await _writeCache(
      _cacheCategoriesKey,
      categories.map((AcademyCategory c) => <String, dynamic>{
        'id': c.id,
        'name': c.name,
        'description': c.description,
        'iconKey': c.iconKey,
        'iconUrl': c.iconUrl,
        'sortOrder': c.sortOrder,
        'isPublished': c.isPublished,
        'guideCount': c.guideCount,
        'slug': c.slug,
        'keywords': c.keywords,
        'unlockLevel': c.unlockLevel,
      }).toList(),
    );
    return categories;
  }

  Future<List<AcademyGuideSummary>> fetchGuideSummaries({
    String? categoryId,
    int limit = 200,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(guidesCollection)
          .where('isPublished', isEqualTo: true)
          .orderBy('sortOrder');
      if (categoryId != null && categoryId.isNotEmpty) {
        query = query.where('categoryId', isEqualTo: categoryId);
      }
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      snap = await query.limit(limit).get();
    } on FirebaseException catch (e) {
      if (!_isMissingIndexError(e)) {
        rethrow;
      }
      debugPrint(
        'AcademyRepository: guides index missing, using client sort fallback',
      );
      Query<Map<String, dynamic>> fallback = _firestore
          .collection(guidesCollection)
          .where('isPublished', isEqualTo: true);
      if (categoryId != null && categoryId.isNotEmpty) {
        fallback = fallback.where('categoryId', isEqualTo: categoryId);
      }
      snap = await fallback.limit(limit).get();
    }
    final List<AcademyGuideSummary> guides = snap.docs
        .map(AcademyGuideSummary.fromFirestore)
        .where((AcademyGuideSummary g) => g.isPublished)
        .toList(growable: true)
      ..sort(
        (AcademyGuideSummary a, AcademyGuideSummary b) =>
            a.sortOrder.compareTo(b.sortOrder),
      );
    if (categoryId == null && startAfter == null) {
      await _writeCache(
        _cacheGuidesKey,
        guides.map(_guideToCacheJson).toList(),
      );
    }
    return guides;
  }

  Future<List<AcademyGuideSummary>> fetchCachedGuideSummaries() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_cacheGuidesKey);
    if (raw == null || raw.isEmpty) {
      return const <AcademyGuideSummary>[];
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((Map<dynamic, dynamic> m) {
            final Map<String, dynamic> data =
                Map<String, dynamic>.from(m);
            return AcademyGuideSummary(
              id: data['id']?.toString() ?? '',
              title: data['title']?.toString() ?? 'Guide',
              description: data['description']?.toString() ?? '',
              categoryId: data['categoryId']?.toString() ?? '',
              difficulty: _parseDifficultyCached(data['difficulty']),
              estimatedMinutes: data['estimatedMinutes'] as int? ?? 0,
              author: data['author']?.toString(),
              coverImageUrl: data['coverImageUrl']?.toString(),
              thumbnailUrl: data['thumbnailUrl']?.toString(),
              sortOrder: data['sortOrder'] as int? ?? 0,
              isPublished: data['isPublished'] != false,
              tags: _readStringListCached(data['tags']),
              platforms: _readStringListCached(data['platforms']),
              keywords: _readStringListCached(data['keywords']),
              lessonCount: data['lessonCount'] as int? ?? 0,
              slug: data['slug']?.toString(),
              webUrl: data['webUrl']?.toString(),
              sitePath: data['sitePath']?.toString(),
              contentMode: data['contentMode']?.toString() ?? 'native',
            );
          })
          .toList(growable: false);
    } catch (e) {
      debugPrint('AcademyRepository: guide cache decode failed: $e');
      return const <AcademyGuideSummary>[];
    }
  }

  Future<AcademyGuideSummary?> fetchGuideById(String guideId) async {
    final String trimmed = guideId.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
        .collection(guidesCollection)
        .doc(trimmed)
        .get();
    if (doc.exists) {
      final AcademyGuideSummary guide = AcademyGuideSummary.fromFirestore(doc);
      if (guide.isPublished) {
        return guide;
      }
    }
    // Website flat slugs may differ slightly from doc ids (nested hubs).
    final QuerySnapshot<Map<String, dynamic>> bySlug = await _firestore
        .collection(guidesCollection)
        .where('slug', isEqualTo: trimmed)
        .limit(1)
        .get();
    if (bySlug.docs.isNotEmpty) {
      final AcademyGuideSummary guide =
          AcademyGuideSummary.fromFirestore(bySlug.docs.first);
      if (guide.isPublished) {
        return guide;
      }
    }
    return null;
  }

  Future<List<AcademyLessonSummary>> fetchLessonSummariesForGuide(
    String guideId,
  ) async {
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _firestore
          .collection(lessonsCollection)
          .where('guideId', isEqualTo: guideId)
          .where('isPublished', isEqualTo: true)
          .orderBy('sortOrder')
          .get();
    } on FirebaseException catch (e) {
      if (!_isMissingIndexError(e)) {
        rethrow;
      }
      debugPrint(
        'AcademyRepository: lessons index missing, using client sort fallback',
      );
      snap = await _firestore
          .collection(lessonsCollection)
          .where('guideId', isEqualTo: guideId)
          .where('isPublished', isEqualTo: true)
          .get();
    }
    return snap.docs
        .map(AcademyLessonSummary.fromFirestore)
        .where((AcademyLessonSummary l) => l.isPublished)
        .toList(growable: true)
      ..sort(
        (AcademyLessonSummary a, AcademyLessonSummary b) =>
            a.sortOrder.compareTo(b.sortOrder),
      );
  }

  Future<AcademyLesson?> fetchLessonById(String lessonId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
        .collection(lessonsCollection)
        .doc(lessonId)
        .get();
    if (!doc.exists) {
      return null;
    }
    final AcademyLesson lesson = AcademyLesson.fromFirestore(doc);
    if (!lesson.summary.isPublished) {
      return null;
    }
    return lesson;
  }

  Future<List<AcademyPath>> fetchPaths({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final List<AcademyPath>? cached = await _readCachedPaths();
      if (cached != null && cached.isNotEmpty) {
        unawaited(_refreshPathsCache());
        return cached;
      }
    }
    return _refreshPathsCache();
  }

  Future<List<AcademyPath>> _refreshPathsCache() async {
    final QuerySnapshot<Map<String, dynamic>> snap =
        await _queryPublishedOrdered(pathsCollection);
    final List<AcademyPath> paths = snap.docs
        .map(AcademyPath.fromFirestore)
        .where((AcademyPath p) => p.isPublished)
        .toList(growable: true)
      ..sort(
        (AcademyPath a, AcademyPath b) => a.sortOrder.compareTo(b.sortOrder),
      );
    await _writeCache(
      _cachePathsKey,
      paths.map((AcademyPath p) => <String, dynamic>{
        'id': p.id,
        'title': p.title,
        'description': p.description,
        'lessonIds': p.lessonIds,
        'sortOrder': p.sortOrder,
        'isPublished': p.isPublished,
        'unlockLevel': p.unlockLevel,
        'iconKey': p.iconKey,
      }).toList(),
    );
    return paths;
  }

  Future<AcademyPath?> fetchPathById(String pathId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
        .collection(pathsCollection)
        .doc(pathId)
        .get();
    if (!doc.exists) {
      return null;
    }
    final AcademyPath path = AcademyPath.fromFirestore(doc);
    if (!path.isPublished) {
      return null;
    }
    return path;
  }

  Future<AcademyXpRewards> fetchXpRewards() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
          .collection(configCollection)
          .doc('xpRewards')
          .get();
      return AcademyXpRewards.fromFirestore(doc.data());
    } catch (e) {
      debugPrint('AcademyRepository: xp rewards fallback: $e');
      return AcademyXpRewards.defaults();
    }
  }

  Stream<List<AcademyUserProgress>> watchUserProgress(String userId) {
    return _firestore
        .collection(progressCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(AcademyUserProgress.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<AcademyUserProgress?> fetchProgressForLesson({
    required String userId,
    required String lessonId,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
        .collection(progressCollection)
        .doc('${userId}_$lessonId')
        .get();
    if (!doc.exists) {
      return null;
    }
    return AcademyUserProgress.fromFirestore(doc);
  }

  Future<void> upsertProgress(AcademyUserProgress progress) async {
    await _firestore
        .collection(progressCollection)
        .doc(progress.documentId)
        .set(progress.toFirestore(), SetOptions(merge: true));
  }

  Future<List<AcademyUserProgress>> fetchSavedGuides(String userId) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection(progressCollection)
        .where('userId', isEqualTo: userId)
        .where('isSaved', isEqualTo: true)
        .get();
    return snap.docs
        .map(AcademyUserProgress.fromFirestore)
        .toList(growable: false);
  }

  Future<List<AcademyCategory>?> _readCachedCategories() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_cacheCategoriesKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((Map<dynamic, dynamic> m) {
            final Map<String, dynamic> data =
                Map<String, dynamic>.from(m);
            return AcademyCategory(
              id: data['id']?.toString() ?? '',
              name: data['name']?.toString() ?? 'Category',
              description: data['description']?.toString() ?? '',
              iconKey: data['iconKey']?.toString(),
              iconUrl: data['iconUrl']?.toString(),
              sortOrder: data['sortOrder'] as int? ?? 0,
              isPublished: data['isPublished'] != false,
              guideCount: data['guideCount'] as int? ?? 0,
              slug: data['slug']?.toString(),
              keywords: _readStringListCached(data['keywords']),
              unlockLevel: data['unlockLevel'] as int? ?? 0,
            );
          })
          .toList(growable: false);
    } catch (e) {
      debugPrint('AcademyRepository: category cache decode failed: $e');
      return null;
    }
  }

  Future<List<AcademyPath>?> _readCachedPaths() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_cachePathsKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((Map<dynamic, dynamic> m) {
            final Map<String, dynamic> data =
                Map<String, dynamic>.from(m);
            return AcademyPath(
              id: data['id']?.toString() ?? '',
              title: data['title']?.toString() ?? 'Path',
              description: data['description']?.toString() ?? '',
              lessonIds: _readStringListCached(data['lessonIds']),
              sortOrder: data['sortOrder'] as int? ?? 0,
              isPublished: data['isPublished'] != false,
              unlockLevel: data['unlockLevel'] as int? ?? 0,
              iconKey: data['iconKey']?.toString(),
            );
          })
          .toList(growable: false);
    } catch (e) {
      debugPrint('AcademyRepository: path cache decode failed: $e');
      return null;
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _queryPublishedOrdered(
    String collection,
  ) async {
    try {
      return await _firestore
          .collection(collection)
          .where('isPublished', isEqualTo: true)
          .orderBy('sortOrder')
          .get();
    } on FirebaseException catch (e) {
      if (!_isMissingIndexError(e)) {
        rethrow;
      }
      debugPrint(
        'AcademyRepository: $collection index missing, '
        'using client sort fallback',
      );
      return _firestore
          .collection(collection)
          .where('isPublished', isEqualTo: true)
          .get();
    }
  }

  bool _isMissingIndexError(FirebaseException error) {
    return error.code == 'failed-precondition' ||
        (error.message?.contains('requires an index') ?? false);
  }

  Future<void> _writeCache(String key, List<Map<String, dynamic>> data) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(data));
    } catch (e) {
      debugPrint('AcademyRepository: cache write failed: $e');
    }
  }

  Map<String, dynamic> _guideToCacheJson(AcademyGuideSummary guide) {
    return <String, dynamic>{
      'id': guide.id,
      'title': guide.title,
      'description': guide.description,
      'categoryId': guide.categoryId,
      'difficulty': guide.difficulty.name,
      'estimatedMinutes': guide.estimatedMinutes,
      'author': guide.author,
      'coverImageUrl': guide.coverImageUrl,
      'thumbnailUrl': guide.thumbnailUrl,
      'sortOrder': guide.sortOrder,
      'isPublished': guide.isPublished,
      'tags': guide.tags,
      'platforms': guide.platforms,
      'keywords': guide.keywords,
      'lessonCount': guide.lessonCount,
      'slug': guide.slug,
      'webUrl': guide.webUrl,
      'sitePath': guide.sitePath,
      'contentMode': guide.contentMode,
    };
  }
}

AcademyDifficulty _parseDifficultyCached(dynamic value) {
  final String raw = value?.toString().toLowerCase() ?? '';
  switch (raw) {
    case 'intermediate':
      return AcademyDifficulty.intermediate;
    case 'advanced':
      return AcademyDifficulty.advanced;
    case 'expert':
      return AcademyDifficulty.expert;
    default:
      return AcademyDifficulty.beginner;
  }
}

List<String> _readStringListCached(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((dynamic e) => e?.toString().trim() ?? '')
      .where((String s) => s.isNotEmpty)
      .toList(growable: false);
}
