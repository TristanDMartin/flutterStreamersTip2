import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import '../models/user_model.dart' as user_model;
import '../services/follows_service.dart';

class FriendSelectionView extends ConsumerStatefulWidget {
  final Function(user_model.User selectedUser) onUserSelected;
  final String? initialSearchQuery;

  const FriendSelectionView({
    super.key,
    required this.onUserSelected,
    this.initialSearchQuery,
  });

  @override
  ConsumerState<FriendSelectionView> createState() => _FriendSelectionViewState();
}

class _FriendSelectionViewState extends ConsumerState<FriendSelectionView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FollowsService _followsService = FollowsService();
  
  List<user_model.User> _connections = [];
  List<user_model.User> _filteredConnections = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadConnections();
    if (widget.initialSearchQuery != null) {
      _searchController.text = widget.initialSearchQuery!;
      _searchQuery = widget.initialSearchQuery!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadConnections() async {
    final currentUser = fa.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // Get connections from FollowsService
      final connections = await _followsService.getUsersForTab('connections');
      
      setState(() {
        _connections = connections;
        _filteredConnections = connections;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading connections: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterConnections(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredConnections = _connections;
      } else {
        _filteredConnections = _connections.where((user) {
          final searchLower = query.toLowerCase();
          return user.displayName.toLowerCase().contains(searchLower) ||
                 user.username.toLowerCase().contains(searchLower);
        }).toList();
      }
    });
  }

  void _selectUser(user_model.User user) {
    HapticFeedback.lightImpact();
    widget.onUserSelected(user);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
        title: const Text(
          'Select Friend',
          style: TextStyle(color: Colors.white),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search friends...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.6)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: _filterConnections,
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
        ),
      );
    }

    if (_connections.isEmpty) {
      return _buildEmptyState();
    }

    if (_filteredConnections.isEmpty && _searchQuery.isNotEmpty) {
      return _buildNoResultsState();
    }

    return _buildConnectionsList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'No Connections Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Connect with friends to share drafts',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9248D2),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Go to Network',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.search_off,
                size: 64,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'No Friends Found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No connections match "$_searchQuery"',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                _filterConnections('');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Clear Search',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredConnections.length,
      itemBuilder: (context, index) {
        final user = _filteredConnections[index];
        return _buildConnectionTile(user);
      },
    );
  }

  Widget _buildConnectionTile(user_model.User user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _selectUser(user),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: user.avatarURL != null 
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF9248D2), Color(0xFF7768DF)],
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9248D2).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: user.avatarURL != null
                      ? ClipOval(
                          child: Image.network(
                            user.avatarURL!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  user.displayName.isNotEmpty 
                                      ? user.displayName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Text(
                            user.displayName.isNotEmpty 
                                ? user.displayName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${user.username}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Selection indicator
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.4),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
