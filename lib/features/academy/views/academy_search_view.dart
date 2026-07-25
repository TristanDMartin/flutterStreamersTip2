import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../routing/app_navigator.dart';
import '../academy_providers.dart';
import '../models/academy_models.dart';
import '../services/academy_search_service.dart';
import '../widgets/academy_widgets.dart';

class AcademySearchView extends ConsumerStatefulWidget {
  const AcademySearchView({super.key});

  @override
  ConsumerState<AcademySearchView> createState() => _AcademySearchViewState();
}

class _AcademySearchViewState extends ConsumerState<AcademySearchView> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<AcademySearchResult> _results = const <AcademySearchResult>[];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _runSearch(_controller.text);
    });
  }

  Future<void> _runSearch(String query) async {
    if (!mounted) {
      return;
    }
    setState(() => _isSearching = true);
    final List<AcademyCategory> categories =
        await ref.read(academyCategoriesProvider.future);
    final List<AcademyGuideSummary> guides =
        await ref.read(academyGuideSummariesProvider.future);
    final AcademySearchService search =
        ref.read(academySearchServiceProvider);
    final List<AcademySearchResult> results = search.search(
      query: query,
      guides: guides,
      categoriesById: academyCategoriesById(categories),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Academy')),
      body: Column(
        children: <Widget>[
          AcademySearchField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) {},
          ),
          Expanded(
            child: _isSearching
                ? const AcademySkeletonList(itemCount: 3)
                : _controller.text.trim().isEmpty
                    ? const AcademyEmptyState(
                        title: 'Find your next lesson',
                        message:
                            'Search guides, platforms, tools, and strategies.',
                      )
                    : _results.isEmpty
                        ? const AcademyEmptyState(
                            title: 'No matches yet',
                            message:
                                'Tippy could not find a lesson for that yet. '
                                'Try another topic or ask Tippy for help.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(
                              AcademyTokens.pagePadding,
                            ),
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (BuildContext context, int index) {
                              final AcademySearchResult result =
                                  _results[index];
                              return AcademyGuideCard(
                                title: result.guide.title,
                                description: result.guide.description,
                                difficulty: difficultyLabel(
                                  result.guide.difficulty,
                                ),
                                estimatedMinutes:
                                    result.guide.estimatedMinutes,
                                imageUrl: result.guide.imageUrl,
                                categoryName: result.categoryName,
                                onTap: () => AppNavigator.openAcademyGuide(
                                  context,
                                  guideId: result.guide.id,
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
