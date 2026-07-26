import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/academy_models.dart';

/// Merges website Academy pages into the app catalog.
///
/// Sources (highest priority first when merging by id):
/// 1. Firestore `academyGuides` / `academyConfig/siteCatalog`
/// 2. Live website sitemap (auto-picks up newly published pages)
/// 3. Bundled `assets/academy/site_catalog.json`
class AcademySiteCatalogService {
  AcademySiteCatalogService({
    FirebaseFirestore? firestore,
    http.Client? httpClient,
  })  : _firestoreOverride = firestore,
        _http = httpClient ?? http.Client();

  final FirebaseFirestore? _firestoreOverride;
  final http.Client _http;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  static const String bundledAssetPath = 'assets/academy/site_catalog.json';
  static const String sitemapUrl = 'https://streamerstip.com/sitemap.xml';
  static const Set<String> _excludedExactPaths = <String>{
    '/',
    '/about',
    '/pricing',
    '/ask-tippy',
    '/discover',
    '/streamer-academy',
    '/creator-tools',
    '/tools',
    '/terms',
    '/privacy',
    '/dmca',
    '/cookie-policy',
    '/guidelines',
    '/contact-support',
  };

  Future<List<AcademyGuideSummary>> loadBundledGuides() async {
    try {
      final String raw = await rootBundle.loadString(bundledAssetPath);
      return _guidesFromCatalogJson(raw);
    } catch (e) {
      debugPrint('AcademySiteCatalogService: bundled catalog failed: $e');
      return const <AcademyGuideSummary>[];
    }
  }

  Future<List<AcademyCategory>> loadBundledCategories() async {
    try {
      final String raw = await rootBundle.loadString(bundledAssetPath);
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const <AcademyCategory>[];
      }
      final Object? categories = decoded['categories'];
      if (categories is! List) {
        return const <AcademyCategory>[];
      }
      return categories
          .whereType<Map>()
          .map((Map<dynamic, dynamic> item) {
            final Map<String, dynamic> data =
                Map<String, dynamic>.from(item);
            final String id = (data['id'] ?? '').toString();
            return AcademyCategory(
              id: id,
              name: (data['name'] ?? 'Category').toString(),
              description: (data['description'] ?? '').toString(),
              iconKey: data['iconKey']?.toString(),
              sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
              isPublished: data['isPublished'] != false,
              guideCount: (data['guideCount'] as num?)?.toInt() ?? 0,
              slug: data['slug']?.toString() ?? id,
              keywords: _stringList(data['keywords']),
            );
          })
          .where((AcademyCategory c) => c.id.isNotEmpty)
          .toList(growable: false);
    } catch (e) {
      debugPrint(
        'AcademySiteCatalogService: bundled categories failed: $e',
      );
      return const <AcademyCategory>[];
    }
  }

  Future<List<AcademyGuideSummary>> fetchRemoteCatalogGuides() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap = await _firestore
          .collection('academyConfig')
          .doc('siteCatalog')
          .get();
      final Map<String, dynamic>? data = snap.data();
      if (data == null) {
        return const <AcademyGuideSummary>[];
      }
      final Object? guides = data['guides'];
      if (guides is! List) {
        return const <AcademyGuideSummary>[];
      }
      return guides
          .whereType<Map>()
          .map((Map<dynamic, dynamic> item) {
            final Map<String, dynamic> data =
                Map<String, dynamic>.from(item);
            final String id = (data['id'] ?? '').toString();
            if (id.isEmpty) {
              return null;
            }
            return AcademyGuideSummary.fromMap(id, <String, dynamic>{
              ...data,
              'contentMode': data['contentMode'] ?? 'website',
              'isPublished': true,
            });
          })
          .whereType<AcademyGuideSummary>()
          .toList(growable: false);
    } catch (e) {
      debugPrint(
        'AcademySiteCatalogService: remote siteCatalog failed: $e',
      );
      return const <AcademyGuideSummary>[];
    }
  }

  /// Parses the live website sitemap so newly added pages appear in-app
  /// even before the next Firestore sync.
  Future<List<AcademyGuideSummary>> fetchSitemapGuides() async {
    try {
      final http.Response response = await _http
          .get(Uri.parse(sitemapUrl))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const <AcademyGuideSummary>[];
      }
      final Iterable<RegExpMatch> matches =
          RegExp(r'<loc>([^<]+)</loc>').allMatches(response.body);
      final List<AcademyGuideSummary> guides = <AcademyGuideSummary>[];
      int sortOrder = 1000;
      for (final RegExpMatch match in matches) {
        final String loc = match.group(1)?.trim() ?? '';
        if (loc.isEmpty) {
          continue;
        }
        final Uri? uri = Uri.tryParse(loc);
        if (uri == null || uri.host.isEmpty) {
          continue;
        }
        if (!uri.host.contains('streamerstip.com')) {
          continue;
        }
        final String sitePath = uri.path.isEmpty ? '/' : uri.path;
        if (!_isAcademySitePath(sitePath)) {
          continue;
        }
        final String slug = sitePath.replaceFirst(RegExp(r'^/'), '');
        final String id = slug.replaceAll('/', '-');
        if (id.isEmpty) {
          continue;
        }
        guides.add(
          AcademyGuideSummary(
            id: id,
            title: _titleFromSlug(slug),
            description: 'Open this Streamer Academy guide on StreamersTip.',
            categoryId: _categoryForSlug(slug),
            sortOrder: sortOrder,
            slug: slug,
            webUrl: loc,
            sitePath: sitePath,
            contentMode: 'website',
            tags: const <String>['website', 'sitemap'],
            keywords: slug.split('-'),
          ),
        );
        sortOrder += 10;
      }
      return guides;
    } catch (e) {
      debugPrint('AcademySiteCatalogService: sitemap fetch failed: $e');
      return const <AcademyGuideSummary>[];
    }
  }

  /// Firestore guides win; then remote catalog; then sitemap; then bundled.
  List<AcademyGuideSummary> mergeGuides({
    required List<AcademyGuideSummary> firestoreGuides,
    List<AcademyGuideSummary> remoteCatalog = const <AcademyGuideSummary>[],
    List<AcademyGuideSummary> sitemapGuides = const <AcademyGuideSummary>[],
    List<AcademyGuideSummary> bundledGuides = const <AcademyGuideSummary>[],
  }) {
    final Map<String, AcademyGuideSummary> byId =
        <String, AcademyGuideSummary>{};
    void putAll(List<AcademyGuideSummary> list) {
      for (final AcademyGuideSummary guide in list) {
        if (guide.id.isEmpty || !guide.isPublished) {
          continue;
        }
        byId.putIfAbsent(guide.id, () => guide);
      }
    }

    putAll(firestoreGuides);
    putAll(remoteCatalog);
    putAll(sitemapGuides);
    putAll(bundledGuides);
    final List<AcademyGuideSummary> merged = byId.values.toList(growable: true)
      ..sort(
        (AcademyGuideSummary a, AcademyGuideSummary b) =>
            a.sortOrder.compareTo(b.sortOrder),
      );
    return merged;
  }

  List<AcademyCategory> mergeCategories({
    required List<AcademyCategory> firestoreCategories,
    List<AcademyCategory> bundledCategories = const <AcademyCategory>[],
  }) {
    if (firestoreCategories.isNotEmpty) {
      return firestoreCategories;
    }
    return bundledCategories;
  }

  List<AcademyGuideSummary> _guidesFromCatalogJson(String raw) {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return const <AcademyGuideSummary>[];
    }
    final Object? guides = decoded['guides'];
    if (guides is! List) {
      return const <AcademyGuideSummary>[];
    }
    return guides
        .whereType<Map>()
        .map((Map<dynamic, dynamic> item) {
          final Map<String, dynamic> data = Map<String, dynamic>.from(item);
          final String id = (data['id'] ?? '').toString();
          if (id.isEmpty) {
            return null;
          }
          return AcademyGuideSummary.fromMap(id, data);
        })
        .whereType<AcademyGuideSummary>()
        .toList(growable: false);
  }

  bool _isAcademySitePath(String sitePath) {
    if (_excludedExactPaths.contains(sitePath)) {
      return false;
    }
    if (sitePath.startsWith('/tools')) {
      return false;
    }
    if (sitePath.startsWith('/dashboard')) {
      return false;
    }
    if (sitePath.startsWith('/api')) {
      return false;
    }
    if (sitePath.contains('.')) {
      return false;
    }
    final List<String> segments =
        sitePath.split('/').where((String s) => s.isNotEmpty).toList();
    if (segments.isEmpty || segments.length > 2) {
      return false;
    }
    return true;
  }

  String _titleFromSlug(String slug) {
    return slug
        .split('/')
        .last
        .split('-')
        .where((String part) => part.isNotEmpty)
        .map(
          (String part) =>
              '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  String _categoryForSlug(String slug) {
    if (slug.startsWith('twitch') || slug.startsWith('twitch/')) {
      return 'twitch';
    }
    if (slug.startsWith('youtube') || slug.startsWith('youtube/')) {
      return 'youtube';
    }
    if (slug.startsWith('kick') || slug.startsWith('kick/')) {
      return 'kick';
    }
    if (slug.startsWith('tiktok') || slug.startsWith('tiktok/')) {
      return 'tiktok';
    }
    return 'beginner';
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((dynamic item) => item.toString())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
