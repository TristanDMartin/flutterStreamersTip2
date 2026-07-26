import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/support_shell_style.dart';
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
  bool _isSearching = true;
  bool _hasLoadedBrowse = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runSearch(''));
    });
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
      unawaited(_runSearch(_controller.text));
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
      _hasLoadedBrowse = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasQuery = _controller.text.trim().isNotEmpty;
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
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
            child: _isSearching && !_hasLoadedBrowse
                ? const AcademySkeletonList(itemCount: 6)
                : !hasQuery && _results.isEmpty && !_isSearching
                    ? const AcademyEmptyState(
                        title: 'Academy pages are loading',
                        message:
                            'Guides from Streamer Academy will appear here.',
                      )
                    : hasQuery && _results.isEmpty && !_isSearching
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
                            itemCount: _results.length + 1,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (BuildContext context, int index) {
                              if (index == 0) {
                                final String label = hasQuery
                                    ? '${_results.length} result'
                                        '${_results.length == 1 ? '' : 's'}'
                                    : 'All Academy pages';
                                return Text(
                                  label,
                                  style: TextStyle(
                                    color: shell.muted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                );
                              }
                              final AcademySearchResult result =
                                  _results[index - 1];
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
