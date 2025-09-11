import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import '../models/user.dart';
import '../services/connection_service.dart';

class InviteFriendsView extends ConsumerStatefulWidget {
  const InviteFriendsView({super.key});

  @override
  ConsumerState<InviteFriendsView> createState() => _InviteFriendsViewState();
}

class _InviteFriendsViewState extends ConsumerState<InviteFriendsView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<User> _searchResults = [];
  List<String> _outgoingInvites = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOutgoingInvites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOutgoingInvites() async {
    final currentUser = fa.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final invites = await ConnectionService.shared.getOutgoingInvites();
      setState(() {
        _outgoingInvites = invites.map((invite) => invite['toUid'] as String).toList();
      });
    } catch (e) {
    // print('Error loading outgoing invites: $e');
    }
  }

  Future<void> _searchUsers() async {
    if (_searchQuery.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await ConnectionService.shared.searchUsers(_searchQuery.trim());
      
      // Filter out users we're already connected to
      final currentUser = fa.FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final connections = await ConnectionService.shared.getConnections(currentUser.uid);
        final connectionIds = connections.map((user) => user.id).toSet();
        
        setState(() {
          _searchResults = results.where((user) => !connectionIds.contains(user.id)).cast<User>().toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _searchResults = results.cast<User>();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to search users: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _sendInvite(User user) async {
    try {
      final success = await ConnectionService.shared.sendConnectionRequest(user.id);
      
      if (success) {
        setState(() {
          _outgoingInvites.add(user.id);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invite sent to ${user.displayName}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send invite to ${user.displayName}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending invite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _hasInvited(String userId) {
    return _outgoingInvites.contains(userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              
              // Search Bar
              _buildSearchBar(),
              
              const Divider(color: Colors.white24, height: 1),
              
              // Content
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const Expanded(
            child: Text(
              'Invite Friends',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha:0.1),
        border: Border.all(
          color: Colors.white.withValues(alpha:0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: Colors.white.withValues(alpha:0.7),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                // Debounce search
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_searchQuery == value) {
                    _searchUsers();
                  }
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search users by username...',
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _searchResults = [];
                });
              },
              icon: Icon(
                Icons.close,
                color: Colors.white.withValues(alpha:0.7),
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              color: Colors.white.withValues(alpha:0.5),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Search for friends to invite',
              style: TextStyle(
                color: Colors.white.withValues(alpha:0.7),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter a username to find and invite friends',
              style: TextStyle(
                color: Colors.white.withValues(alpha:0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _searchUsers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              color: Colors.white.withValues(alpha:0.5),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'No users found for "$_searchQuery"',
              style: TextStyle(
                color: Colors.white.withValues(alpha:0.7),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different username',
              style: TextStyle(
                color: Colors.white.withValues(alpha:0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildUserRow(user);
      },
    );
  }

  Widget _buildUserRow(User user) {
    final hasInvited = _hasInvited(user.id);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha:0.1),
                Colors.white.withValues(alpha:0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha:0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha:0.2),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: user.avatarURL != null
                      ? Image.network(
                          user.avatarURL!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.withValues(alpha:0.3),
                              child: Icon(
                                Icons.person,
                                color: Colors.white.withValues(alpha:0.6),
                                size: 24,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey.withValues(alpha:0.3),
                          child: Icon(
                            Icons.person,
                            color: Colors.white.withValues(alpha:0.6),
                            size: 24,
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha:0.7),
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Invite button
              if (hasInvited)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha:0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.green.withValues(alpha:0.3),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'Invited',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: () => _sendInvite(user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha:0.1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Invite',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
