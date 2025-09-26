import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../services/logging_service.dart';
import '../services/contacts_service.dart';
import '../services/search_api_service.dart';
import 'optimized_image.dart';
import 'instant_response_button.dart';

class InviteFriendsView extends ConsumerStatefulWidget {
  const InviteFriendsView({super.key});

  @override
  ConsumerState<InviteFriendsView> createState() => _InviteFriendsViewState();
}

class _InviteFriendsViewState extends ConsumerState<InviteFriendsView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;
  
  List<SearchResult> _searchResults = [];
  bool _isLoading = false;
  String? _error;
  String _currentQuery = '';
  int _currentPage = 0;
  bool _hasMoreResults = true;
  bool _isLoadingMore = false;

  // Constants matching the app's design system
  static const Color _primaryColor = Color(0xFF9248D2);
  static const Color _secondaryColor = Color(0xFF7768DF);
  static const Color _accentColor = Color(0xFF1670DE);
  static const Color _successColor = Color(0xFF4CAF50);
  static const Color _backgroundDark = Color(0xFF6137EB);
  static const Color _backgroundMedium = Color(0xFF1C135D);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _currentQuery = query.trim();
    });
    
    // Cancel previous timer
    _searchDebounceTimer?.cancel();
    
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults.clear();
        _currentPage = 0;
        _hasMoreResults = true;
      });
    } else {
      // Start new debounce timer
      _searchDebounceTimer = Timer(const Duration(milliseconds: 400), () {
        _performSearch(query.trim());
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 0;
      _hasMoreResults = true;
    });

    try {
      LoggingService.instance.debug('Searching for users: "$query"', tag: 'InviteFriendsView');
      
      // Use real search API service
      final searchService = ref.read(searchApiServiceProvider);
      final results = await searchService.searchUsers(query, limit: 20, offset: 0);
      
      setState(() {
        _searchResults = results;
        _isLoading = false;
        _currentPage = 1;
        _hasMoreResults = results.length >= 20; // Assuming 20 per page
      });
      
    } catch (e, stackTrace) {
      LoggingService.instance.error('Search failed', tag: 'InviteFriendsView', error: e, stackTrace: stackTrace);
      setState(() {
        _error = 'Search failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreResults() async {
    if (_isLoadingMore || !_hasMoreResults || _currentQuery.isEmpty) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Simulate pagination - replace with actual API call
      await Future.delayed(const Duration(milliseconds: 300));
      
      final moreResults = _generateMockSearchResults(_currentQuery, page: _currentPage + 1);
      
      setState(() {
        _searchResults.addAll(moreResults);
        _currentPage++;
        _isLoadingMore = false;
        _hasMoreResults = moreResults.length >= 20;
      });
      
    } catch (e, stackTrace) {
      LoggingService.instance.error('Load more failed', tag: 'InviteFriendsView', error: e, stackTrace: stackTrace);
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  List<SearchResult> _generateMockSearchResults(String query, {int page = 1}) {
    // Mock data for demonstration
    final mockUsers = [
      SearchResult(
        id: 'user1',
        title: 'Alex Creator',
        subtitle: '@alex_creator',
        type: SearchResultType.user,
        imageURL: 'https://via.placeholder.com/150x150/9248D2/FFFFFF?text=AC',
        metadata: {'userId': 'user1', 'username': 'alex_creator', 'displayName': 'Alex Creator', 'relation': 'mutual'},
      ),
      SearchResult(
        id: 'user2',
        title: 'Sarah Streamer',
        subtitle: '@sarah_streamer',
        type: SearchResultType.user,
        imageURL: 'https://via.placeholder.com/150x150/7768DF/FFFFFF?text=SS',
        metadata: {'userId': 'user2', 'username': 'sarah_streamer', 'displayName': 'Sarah Streamer', 'relation': 'following'},
      ),
      SearchResult(
        id: 'user3',
        title: 'Mike Gamer',
        subtitle: '@mike_gamer',
        type: SearchResultType.user,
        imageURL: 'https://via.placeholder.com/150x150/1670DE/FFFFFF?text=MG',
        metadata: {'userId': 'user3', 'username': 'mike_gamer', 'displayName': 'Mike Gamer', 'relation': 'follower'},
      ),
      SearchResult(
        id: 'user4',
        title: 'Jess Artist',
        subtitle: '@jess_artist',
        type: SearchResultType.user,
        imageURL: 'https://via.placeholder.com/150x150/4CAF50/FFFFFF?text=JA',
        metadata: {'userId': 'user4', 'username': 'jess_artist', 'displayName': 'Jess Artist', 'relation': 'none'},
      ),
    ];

    // Filter results based on query
    return mockUsers.where((user) => 
      user.metadata['username']?.toLowerCase().contains(query.toLowerCase()) == true ||
      user.title.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_backgroundDark, _backgroundMedium],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              Expanded(
                child: _buildContent(),
              ),
              _buildInviteFromContactsButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            padding: const EdgeInsets.all(8),
          ),
          const Expanded(
            child: Text(
              'Invite Friends',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Search users by username…',
          hintStyle: TextStyle(color: Colors.white70),
          prefixIcon: Icon(Icons.search, color: Colors.white70),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_currentQuery.isEmpty) {
      return _buildEmptyState();
    }

    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_searchResults.isEmpty) {
      return _buildNoResultsState();
    }

    return _buildSearchResults();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.person_search,
              color: Colors.white70,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Search for friends to invite',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a username to find and invite friends',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.white.withValues(alpha: 0.7),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          InstantElevatedButton(
            onPressed: () => _performSearch(_currentQuery),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            color: Colors.white.withValues(alpha: 0.7),
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'No users found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different username',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _searchResults.length + (_hasMoreResults ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _searchResults.length) {
          return _buildLoadMoreButton();
        }
        
        final result = _searchResults[index];
        return _buildSearchResultItem(result);
      },
    );
  }

  Widget _buildSearchResultItem(SearchResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: result.avatarUrl != null 
                  ? null
                  : const LinearGradient(
                      colors: [_primaryColor, _secondaryColor],
                    ),
            ),
            child: result.imageURL != null
                ? ClipOval(
                    child: OptimizedImage(
                      imageUrl: result.imageURL!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 28,
                  ),
          ),
          
          const SizedBox(width: 16),
          
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${result.username}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                _buildRelationBadge(UserRelation.values.firstWhere((e) => e.name == result.metadata['relation'])),
              ],
            ),
          ),
          
          // Action button
          _buildActionButton(result),
        ],
      ),
    );
  }

  Widget _buildRelationBadge(UserRelation relation) {
    String text;
    Color color;
    
    switch (relation) {
      case UserRelation.mutual:
        text = 'Mutual';
        color = _successColor;
        break;
      case UserRelation.following:
        text = 'Following';
        color = _accentColor;
        break;
      case UserRelation.follower:
        text = 'Follower';
        color = _secondaryColor;
        break;
      case UserRelation.none:
        text = 'Not connected';
        color = Colors.white.withValues(alpha: 0.5);
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActionButton(SearchResult result) {
    final relation = UserRelation.values.firstWhere((e) => e.name == result.metadata['relation']);
    switch (relation) {
      case UserRelation.mutual:
      case UserRelation.following:
      case UserRelation.follower:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Connected',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      case UserRelation.none:
        return InstantElevatedButton(
          onPressed: () => _handleConnect(result),
          child: const Text('Connect'),
        );
    }
  }

  Widget _buildLoadMoreButton() {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: InstantElevatedButton(
        onPressed: _loadMoreResults,
        child: const Text('Load More'),
      ),
    );
  }

  Widget _buildInviteFromContactsButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _handleInviteFromContacts();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF9248D2), // Primary purple
                Color(0xFF7768DF), // Secondary purple
                Color(0xFF1670DE), // Blue
                Color(0xFF3C8BD6), // Lighter blue
                Color(0xFF4897D2), // Lightest blue
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9248D2).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.contacts, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text(
                'Invite from Contacts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleConnect(SearchResult result) {
    HapticFeedback.lightImpact();
    LoggingService.instance.debug('Connecting to user: ${result.username}', tag: 'InviteFriendsView');
    
    // TODO: Implement actual connection logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connecting to ${result.displayName}...'),
        backgroundColor: _primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleInviteFromContacts() async {
    try {
      HapticFeedback.lightImpact();
      LoggingService.instance.debug('Opening contacts invite', tag: 'InviteFriendsView');
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get contacts with hashing
      final contactsService = ref.read(contactsServiceProvider);
      final hashedContacts = await contactsService.getContactsWithHashing();
      
      if (hashedContacts.isEmpty) {
        if (context.mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No contacts found or permission denied'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Upload hashed contacts
      await contactsService.uploadHashedContacts(hashedContacts);
      
      // Find matching users
      final matches = await contactsService.findMatchingUsers(hashedContacts);
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        if (matches.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No contacts found on StreamersTip'),
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          // Show contacts matches
          _showContactsMatches(matches);
        }
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error handling contacts invite', tag: 'InviteFriendsView', error: e, stackTrace: stackTrace);
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing contacts: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showContactsMatches(List<ContactMatch> matches) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: _backgroundMedium,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Contacts on StreamersTip',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // Matches list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final match = matches[index];
                  return _buildContactMatchCard(match);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactMatchCard(ContactMatch match) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundImage: match.avatarUrl != null 
                ? NetworkImage(match.avatarUrl!)
                : null,
            child: match.avatarUrl == null
                ? const Icon(Icons.person, color: Colors.white70)
                : null,
          ),
          
          const SizedBox(width: 16),
          
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '@${match.username}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Found via ${match.matchType}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Connect button
          InstantElevatedButton(
            onPressed: () => _handleConnectFromContact(match),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConnectFromContact(ContactMatch match) async {
    try {
      HapticFeedback.lightImpact();
      LoggingService.instance.debug('Connecting to contact: ${match.username}', tag: 'InviteFriendsView');
      
      // TODO: Implement actual connection logic
      // For now, just show success message
      if (context.mounted) {
        Navigator.of(context).pop(); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${match.displayName}!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error connecting to contact', tag: 'InviteFriendsView', error: e, stackTrace: stackTrace);
    }
  }
}

// Data models - using SearchResult from search_api_service.dart
enum UserRelation {
  mutual,
  following,
  follower,
  none,
}