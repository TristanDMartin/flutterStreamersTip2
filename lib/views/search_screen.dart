import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../services/creator_intelligence_analytics_service.dart';
import '../services/search_api_service.dart';
import '../services/logging_service.dart';
import '../providers/follow_refresh_provider.dart';
import '../models/creator_profile_snapshot.dart';
import '../routing/app_navigator.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/support_shell_style.dart';

/// StreamersTip search screen with unified results feed
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  String _searchQuery = '';
  List<SearchResult> _allResults = [];
  List<String> _recentSearches = [];
  List<Map<String, dynamic>> _thingsYouMayLike = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadRecentSearches();
    _loadThingsYouMayLike();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text.trim();
      if (query != _searchQuery) {
        setState(() {
          _searchQuery = query;
        });
        if (query.isNotEmpty) {
          _saveRecentSearch(query);
          _performSearch();
        }
      }
    });
  }

  Future<void> _loadRecentSearches() async {
    final currentUser = fa.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final recentSearches = data?['recentSearches'] as List<dynamic>?;
        setState(() {
          _recentSearches =
              recentSearches?.map((e) => e.toString()).toList() ?? [];
        });
      }
    } catch (e) {
      LoggingService.instance.error(
        'Error loading recent searches: $e',
        tag: 'SearchScreen',
      );
    }
  }

  Future<void> _saveRecentSearch(String query) async {
    final currentUser = fa.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Remove if already exists
      _recentSearches.remove(query);
      // Add to front
      _recentSearches.insert(0, query);
      // Keep only last 10
      if (_recentSearches.length > 10) {
        _recentSearches = _recentSearches.take(10).toList();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({'recentSearches': _recentSearches});

      setState(() {});
    } catch (e) {
      LoggingService.instance.error(
        'Error saving recent search: $e',
        tag: 'SearchScreen',
      );
    }
  }

  Future<void> _deleteRecentSearch(String query) async {
    final currentUser = fa.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      setState(() {
        _recentSearches.remove(query);
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({'recentSearches': _recentSearches});
    } catch (e) {
      LoggingService.instance.error(
        'Error deleting recent search: $e',
        tag: 'SearchScreen',
      );
    }
  }

  Future<void> _loadThingsYouMayLike() async {
    final currentUser = fa.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get user's recent activity or interests
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        // Get trending hashtags
        final searchService = ref.read(searchApiServiceProvider);
        final trending = await searchService.getTrendingHashtags(limit: 5);

        // Get recent videos
        final videosQuery = await FirebaseFirestore.instance
            .collection('videos')
            .where('isPublic', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();

        setState(() {
          _thingsYouMayLike = [
            ...trending.map((t) => {
                  'type': 'hashtag',
                  'title': t.title,
                  'subtitle': t.subtitle,
                }),
            ...videosQuery.docs.map((doc) {
              final videoData = doc.data();
              return {
                'type': 'video',
                'title': videoData['caption'] ?? 'Video',
                'subtitle': 'by @${videoData['creatorUsername'] ?? 'unknown'}',
                'thumbnailUrl': videoData['thumbnailUrl'],
                'videoId': doc.id,
                'views': videoData['views'] ?? 0,
              };
            }),
          ];
          _isLoading = false;
        });
      }
    } catch (e) {
      LoggingService.instance.error(
        'Error loading things you may like: $e',
        tag: 'SearchScreen',
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _performSearch() async {
    if (_searchQuery.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final searchService = ref.read(searchApiServiceProvider);

      // Search for users and videos together
      final users = await searchService.searchUsers(_searchQuery, limit: 20);
      final videos = await searchService.searchVideos(_searchQuery, limit: 20);

      setState(() {
        _allResults = [...users, ...videos];
        _isLoading = false;
      });
      unawaited(
        ref.read(creatorIntelligenceAnalyticsProvider).trackSearchPerformed(
              query: _searchQuery,
              resultsCount: users.length + videos.length,
            ),
      );
    } catch (e) {
      LoggingService.instance.error(
        'Error performing search: $e',
        tag: 'SearchScreen',
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(followRefreshProvider, (previous, next) {
      if (previous == next) return;
      if (_searchQuery.isNotEmpty) {
        _performSearch();
      } else {
        _loadThingsYouMayLike();
      }
    });
    final ColorScheme cs = Theme.of(context).colorScheme;
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: shell.pageGradient,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: shell.onChrome,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: shell.onChrome),
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: _buildSearchBar(cs, shell),
        ),
        body: Padding(
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: _searchQuery.isEmpty
              ? _buildTrendingAndRecent(cs, shell)
              : _buildSearchResults(cs, shell),
        ),
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme cs, StSupportShellStyle shell) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: shell.panelSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: shell.panelBorder),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 12),
          Icon(
            Icons.search_rounded,
            color: shell.iconDim,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: TextStyle(color: cs.onSurface, fontSize: 16),
              cursorColor: cs.primary,
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(color: cs.onSurfaceVariant),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              autofocus: false,
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (BuildContext context, TextEditingValue v, Widget? _) {
              if (v.text.isEmpty) {
                return const SizedBox(width: 12);
              }
              return GestureDetector(
                onTap: () {
                  _searchController.clear();
                  _searchFocusNode.unfocus();
                  setState(() {
                    _searchQuery = '';
                    _allResults = [];
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.clear_rounded,
                    color: shell.iconDim,
                    size: 20,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingAndRecent(ColorScheme cs, StSupportShellStyle shell) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: <Widget>[
        // Recent Searches
        if (_recentSearches.isNotEmpty) ...<Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Recent Searches',
                style: TextStyle(
                  color: shell.onChrome,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () async {
                  final currentUser = fa.FirebaseAuth.instance.currentUser;
                  if (currentUser != null) {
                    try {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser.uid)
                          .update({'recentSearches': <String>[]});
                      setState(() {
                        _recentSearches = <String>[];
                      });
                    } catch (e) {
                      // Handle error
                    }
                  }
                },
                child: Text(
                  'Clear all',
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches.map((String search) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: shell.chipUnselectedBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: shell.chipUnselectedBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    GestureDetector(
                      onTap: () {
                        _searchController.text = search;
                        setState(() {
                          _searchQuery = search;
                        });
                        _performSearch();
                      },
                      child: Text(
                        search,
                        style: TextStyle(
                          color: shell.chipUnselectedFg,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _deleteRecentSearch(search),
                      child: Icon(
                        Icons.close_rounded,
                        color: shell.iconDim,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        // Things You May Like
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Things You May Like',
              style: TextStyle(
                color: shell.onChrome,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  : Icon(Icons.refresh_rounded, color: shell.onChrome),
              onPressed: _loadThingsYouMayLike,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoading)
          Center(
            child: CircularProgressIndicator(color: cs.primary),
          )
        else if (_thingsYouMayLike.isEmpty)
          Center(
            child: Text(
              'Nothing to show yet',
              style: TextStyle(color: shell.muted),
            ),
          )
        else
          ..._thingsYouMayLike.map(
            (Map<String, dynamic> item) =>
                _buildRecommendationCard(item, cs, shell),
          ),
      ],
    );
  }

  Widget _buildRecommendationCard(
    Map<String, dynamic> item,
    ColorScheme cs,
    StSupportShellStyle shell,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: shell.surfaceCardBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          item['type'] == 'hashtag'
              ? Icons.tag_rounded
              : Icons.video_library_rounded,
          color: cs.primary,
        ),
        title: Text(
          item['title'] ?? '',
          style: TextStyle(
            color: shell.onChrome,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          item['subtitle'] ?? '',
          style: TextStyle(
            color: shell.muted,
            fontSize: 14,
          ),
        ),
        onTap: () {
          if (item['type'] == 'hashtag') {
            _searchController.text = item['title'] as String? ?? '';
            setState(() {
              _searchQuery = item['title'] as String? ?? '';
            });
            _performSearch();
          }
        },
      ),
    );
  }

  Widget _buildSearchResults(ColorScheme cs, StSupportShellStyle shell) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: cs.primary),
      );
    }

    if (_allResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: shell.iconDim,
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                color: shell.muted,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _allResults.map((SearchResult result) {
        if (result.type == SearchResultType.user) {
          return _buildUserCard(result, cs, shell);
        }
        if (result.type == SearchResultType.video) {
          return _buildVideoCard(result, cs, shell);
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }

  Widget _buildUserCard(
    SearchResult result,
    ColorScheme cs,
    StSupportShellStyle shell,
  ) {
    return InkWell(
      onTap: () {
        AppNavigator.openStreamerCard(
          context,
          userId: result.userId ?? '',
          initialCreator: CreatorProfileSnapshot(
            creatorId: result.userId ?? '',
            displayName: result.displayName ?? result.title,
            username: result.username ?? result.subtitle,
            avatarUrl: result.avatarUrl ?? result.imageURL,
            followersCount: result.followerCount,
          ),
          currentUserId: fa.FirebaseAuth.instance.currentUser?.uid,
          onDismiss: () => Navigator.of(context).pop(),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: shell.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: shell.surfaceCardBorder),
        ),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 28,
              backgroundColor: cs.surfaceContainerHighest,
              backgroundImage:
                  result.avatarUrl != null && result.avatarUrl!.isNotEmpty
                      ? NetworkImage(result.avatarUrl!)
                      : null,
              child: result.avatarUrl == null || result.avatarUrl!.isEmpty
                  ? Text(
                      result.title.isNotEmpty
                          ? result.title[0].toUpperCase()
                          : '?',
                      style: TextStyle(color: cs.onSurface),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    result.title,
                    style: TextStyle(
                      color: shell.onChrome,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    result.subtitle,
                    style: TextStyle(
                      color: shell.muted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (result.followerCount > 0)
              Text(
                '${result.followerCount} followers',
                style: TextStyle(
                  color: shell.mutedStrong,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(
    SearchResult result,
    ColorScheme cs,
    StSupportShellStyle shell,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 120,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: cs.surfaceContainerHighest,
              border: Border.all(color: shell.surfaceCardBorder),
            ),
            child: result.imageURL != null && result.imageURL!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      result.imageURL!,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (BuildContext context, Object error, StackTrace? st) {
                        return Center(
                          child: Icon(
                            Icons.video_library_rounded,
                            color: shell.iconDim,
                          ),
                        );
                      },
                    ),
                  )
                : Center(
                    child: Icon(
                      Icons.video_library_rounded,
                      color: shell.iconDim,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  result.title,
                  style: TextStyle(
                    color: shell.onChrome,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  result.subtitle,
                  style: TextStyle(
                    color: shell.muted,
                    fontSize: 14,
                  ),
                ),
                if (result.viewCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${result.viewCount} views',
                      style: TextStyle(
                        color: shell.mutedStrong,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
