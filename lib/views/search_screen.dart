import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../services/search_api_service.dart';
import '../widgets/streamer_card_view.dart';
import '../services/logging_service.dart';
import '../providers/follows_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:cloud_firestore/cloud_firestore.dart';

/// TikTok-style search screen with unified results feed
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6633CC), // Purple
            Color(0xFF1A1A4D), // Dark blue
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: _buildSearchBar(),
        ),
        body: _searchQuery.isEmpty
            ? _buildTrendingAndRecent()
            : _buildSearchResults(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            Icons.search,
            color: Colors.white.withValues(alpha: 0.7),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              autofocus: false,
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                _searchFocusNode.unfocus();
                setState(() {
                  _searchQuery = '';
                  _allResults = [];
                });
              },
              child: Icon(
                Icons.clear,
                color: Colors.white.withValues(alpha: 0.7),
                size: 20,
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildTrendingAndRecent() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Recent Searches
        if (_recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Searches',
                style: TextStyle(
                  color: Colors.white,
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
                          .update({'recentSearches': []});
                      setState(() {
                        _recentSearches = [];
                      });
                    } catch (e) {
                      // Handle error
                    }
                  }
                },
                child: const Text(
                  'Clear all',
                  style: TextStyle(color: Colors.pink, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches.map((search) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _deleteRecentSearch(search),
                      child: Icon(
                        Icons.close,
                        color: Colors.white.withValues(alpha: 0.7),
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
          children: [
            const Text(
              'Things You May Like',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadThingsYouMayLike,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        else if (_thingsYouMayLike.isEmpty)
          const Center(
            child: Text(
              'Nothing to show yet',
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          ..._thingsYouMayLike.map((item) => _buildRecommendationCard(item)),
      ],
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          item['type'] == 'hashtag' ? Icons.tag : Icons.video_library,
          color: Colors.pink,
        ),
        title: Text(
          item['title'] ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          item['subtitle'] ?? '',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
        onTap: () {
          if (item['type'] == 'hashtag') {
            _searchController.text = item['title'];
            setState(() {
              _searchQuery = item['title'];
            });
            _performSearch();
          }
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (_allResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _allResults.map((result) {
        if (result.type == SearchResultType.user) {
          return _buildUserCard(result);
        } else if (result.type == SearchResultType.video) {
          return _buildVideoCard(result);
        } else {
          return const SizedBox.shrink();
        }
      }).toList(),
    );
  }

  Widget _buildUserCard(SearchResult result) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StreamerCardView(
              userId: result.userId ?? '',
              currentUserId: fa.FirebaseAuth.instance.currentUser?.uid,
              onDismiss: () => Navigator.of(context).pop(),
              onFollow: (userId) async {
                // Use FollowsService to actually follow the user
                final followsService = ref.read(followsServiceProvider);
                final success = await followsService.followUser(userId);
                if (success) {
                  debugPrint('✅ Successfully followed user: $userId');
                } else {
                  debugPrint('❌ Failed to follow user: $userId');
                }
              },
              onMessage: (userId) {},
              onNavigateToTab: (tabName) {},
              onShare: (userId) {},
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage:
                  result.avatarUrl != null && result.avatarUrl!.isNotEmpty
                      ? NetworkImage(result.avatarUrl!)
                      : null,
              child: result.avatarUrl == null || result.avatarUrl!.isEmpty
                  ? Text(
                      result.title.isNotEmpty
                          ? result.title[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    result.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
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
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(SearchResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 120,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[900],
            ),
            child: result.imageURL != null && result.imageURL!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      result.imageURL!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child:
                              Icon(Icons.video_library, color: Colors.white54),
                        );
                      },
                    ),
                  )
                : const Center(
                    child: Icon(Icons.video_library, color: Colors.white54),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.title,
                  style: const TextStyle(
                    color: Colors.white,
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
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
                if (result.viewCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${result.viewCount} views',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
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
