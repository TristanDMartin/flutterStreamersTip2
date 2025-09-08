import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import '../models/user.dart';
import '../services/connection_service.dart';
import '../services/chat_service.dart';
import 'chat_view.dart';

class StartGroupView extends ConsumerStatefulWidget {
  const StartGroupView({super.key});

  @override
  ConsumerState<StartGroupView> createState() => _StartGroupViewState();
}

class _StartGroupViewState extends ConsumerState<StartGroupView> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  String _searchQuery = '';
  List<User> _connections = [];
  final Set<String> _selectedUserIds = {};
  bool _isLoading = true;
  bool _isCreating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _loadConnections() async {
    final currentUser = fa.FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _error = 'Please sign in to view connections';
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final connections = await ConnectionService.shared.getConnections(currentUser.uid);
      
      setState(() {
        _connections = connections.cast<User>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load connections: $e';
        _isLoading = false;
      });
    }
  }

  List<User> get _filteredConnections {
    if (_searchQuery.isEmpty) {
      return _connections;
    }
    
    return _connections.where((user) {
      final searchLower = _searchQuery.toLowerCase();
      return user.displayName.toLowerCase().contains(searchLower) ||
             user.username.toLowerCase().contains(searchLower);
    }).toList();
  }

  void _toggleUserSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _createGroup() async {
    if (_selectedUserIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 2 people for the group'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final currentUser = fa.FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get selected users
      final selectedUsers = _connections.where((user) => _selectedUserIds.contains(user.id)).toList();
      
      // Create group name if not provided
      String groupName = _groupNameController.text.trim();
      if (groupName.isEmpty) {
        if (selectedUsers.length <= 3) {
          groupName = selectedUsers.map((user) => user.displayName).join(', ');
        } else {
          groupName = '${selectedUsers.take(2).map((user) => user.displayName).join(', ')} and ${selectedUsers.length - 2} others';
        }
      }

      // Create group chat
      final chatService = ChatService.shared;
      final chat = await chatService.createGroupChat(
        groupName: groupName,
        participantIds: [currentUser.uid, ..._selectedUserIds],
      );

      if (chat != null && mounted) {
        // Navigate to chat view
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ChatView(
              chat: chat,
              otherUserName: groupName,
              otherUserAvatarURL: null,
              otherUserIsOnline: false,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
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
              
              // Selected Users Chips
              if (_selectedUserIds.isNotEmpty) _buildSelectedUsers(),
              
              // Group Name Input
              if (_selectedUserIds.isNotEmpty) _buildGroupNameInput(),
              
              const Divider(color: Colors.white24, height: 1),
              
              // Content
              Expanded(
                child: _buildContent(),
              ),
              
              // Continue Button
              if (_selectedUserIds.isNotEmpty) _buildContinueButton(),
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
              'New Group',
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
        color: Colors.white.withOpacity(0.1),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: Colors.white.withOpacity(0.7),
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
              },
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search connections...',
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
                });
              },
              icon: Icon(
                Icons.close,
                color: Colors.white.withOpacity(0.7),
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedUsers() {
    final selectedUsers = _connections.where((user) => _selectedUserIds.contains(user.id)).toList();
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected (${selectedUsers.length})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedUsers.map((user) => _buildUserChip(user)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUserChip(User user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipOval(
              child: user.avatarURL != null
                  ? Image.network(
                      user.avatarURL!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.withOpacity(0.3),
                          child: Icon(
                            Icons.person,
                            color: Colors.white.withOpacity(0.6),
                            size: 12,
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey.withOpacity(0.3),
                      child: Icon(
                        Icons.person,
                        color: Colors.white.withOpacity(0.6),
                        size: 12,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            user.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _toggleUserSelection(user.id),
            child: Icon(
              Icons.close,
              color: Colors.white.withOpacity(0.7),
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupNameInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _groupNameController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Group name (optional)',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildContent() {
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
              onPressed: _loadConnections,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filteredConnections = _filteredConnections;

    if (filteredConnections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline,
              color: Colors.white.withOpacity(0.5),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'No connections found for "$_searchQuery"'
                  : 'No connections yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Connect with friends to create groups',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredConnections.length,
      itemBuilder: (context, index) {
        final connection = filteredConnections[index];
        return _buildConnectionRow(connection);
      },
    );
  }

  Widget _buildConnectionRow(User connection) {
    final isSelected = _selectedUserIds.contains(connection.id);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleUserSelection(connection.id),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isSelected 
                      ? Colors.white.withOpacity(0.2)
                      : Colors.white.withOpacity(0.1),
                  isSelected 
                      ? Colors.white.withOpacity(0.15)
                      : Colors.white.withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: isSelected 
                    ? Colors.white.withOpacity(0.3)
                    : Colors.white.withOpacity(0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Selection checkbox
                Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    color: isSelected ? Colors.white : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Color(0xFF1C135D),
                          size: 16,
                        )
                      : null,
                ),
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: connection.avatarURL != null
                        ? Image.network(
                            connection.avatarURL!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.withOpacity(0.3),
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white.withOpacity(0.6),
                                  size: 20,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey.withOpacity(0.3),
                            child: Icon(
                              Icons.person,
                              color: Colors.white.withOpacity(0.6),
                              size: 20,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                // Connection info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connection.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${connection.username}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isCreating ? null : _createGroup,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Create Group (${_selectedUserIds.length + 1})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
