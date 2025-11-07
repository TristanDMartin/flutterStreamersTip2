import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import '../models/user_model.dart' as user_model;
import '../services/chat_service.dart';
import '../services/draft_sharing_service.dart';
import '../services/follows_service.dart';
import 'chat_view.dart';
import 'draft_feedback_view.dart';

class ChoosePersonView extends ConsumerStatefulWidget {
  final Map<String, dynamic>? selectedDraft;

  const ChoosePersonView({super.key, this.selectedDraft});

  @override
  ConsumerState<ChoosePersonView> createState() => _ChoosePersonViewState();
}

class _ChoosePersonViewState extends ConsumerState<ChoosePersonView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<user_model.User> _connections = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  @override
  void dispose() {
    _searchController.dispose();
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

      // Use FollowsService to get all users from NetworkView (connections + followers + following)
      // This ensures consistency with the Connections tab in NetworkView
      final followsService = FollowsService();
      
      // Load all three lists in parallel (same as NetworkView)
      final results = await Future.wait([
        followsService.getUsersForTab('connections'),
        followsService.getUsersForTab('followers'),
        followsService.getUsersForTab('following'),
      ]);

      // Combine all users (connections, followers, following) for maximum sharing options
      final connectionsList = results[0];
      final followersList = results[1];
      final followingList = results[2];

      // Create a combined list, prioritizing connections (mutual follows) first
      // Filter out users with invalid IDs to prevent sharing failures
      final allUsers = <user_model.User>[];
      final userIds = <String>{};

      // Add connections first (mutual follows - highest priority)
      for (final user in connectionsList) {
        if (user.id.isNotEmpty && !userIds.contains(user.id)) {
          allUsers.add(user);
          userIds.add(user.id);
        }
      }

      // Add followers (they follow you)
      for (final user in followersList) {
        if (user.id.isNotEmpty && !userIds.contains(user.id)) {
          allUsers.add(user);
          userIds.add(user.id);
        }
      }

      // Add following (you follow them)
      for (final user in followingList) {
        if (user.id.isNotEmpty && !userIds.contains(user.id)) {
          allUsers.add(user);
          userIds.add(user.id);
        }
      }

      if (allUsers.length < connectionsList.length + followersList.length + followingList.length) {
        final filteredCount = (connectionsList.length + followersList.length + followingList.length) - allUsers.length;
        debugPrint('⚠️ ChoosePersonView: Filtered out $filteredCount users with invalid IDs');
      }

      setState(() {
        _connections = allUsers;
        _isLoading = false;
      });

      debugPrint('🔗 ChoosePersonView: Loaded ${allUsers.length} total users (${connectionsList.length} connections, ${followersList.length} followers, ${followingList.length} following)');
    } catch (e) {
      debugPrint('❌ ChoosePersonView: Error loading connections: $e');
      setState(() {
        _error = 'Failed to load connections: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  List<user_model.User> get _filteredConnections {
    if (_searchQuery.isEmpty) {
      return _connections;
    }

    return _connections.where((user) {
      final searchLower = _searchQuery.toLowerCase();
      return user.displayName.toLowerCase().contains(searchLower) ||
          user.username.toLowerCase().contains(searchLower);
    }).toList();
  }

  Future<void> _selectPerson(user_model.User person) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );

      if (widget.selectedDraft != null) {
        // Share draft via DraftSharingService
        final draftSharingService = DraftSharingService();
        final draftId = widget.selectedDraft!['id'] as String?;
        
        if (draftId != null) {
          // Validate person.id is not empty
          if (person.id.isEmpty) {
            if (mounted) Navigator.of(context).pop();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invalid user: User ID is missing'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }

          debugPrint('🔗 ChoosePersonView: Sharing draft $draftId with user ${person.id} (${person.displayName})');
          
          final success = await draftSharingService.shareDraftWithConnections(
            draftId: draftId,
            connectionIds: [person.id],
            message: 'Check out this draft and share your feedback!',
          );

          // Close loading dialog
          if (mounted) Navigator.of(context).pop();

          if (success && mounted) {
            // Create or fetch chat for feedback
            final chatService = ChatService.shared;
            final chat = await chatService.fetchOrCreateChat(person.id);

            if (chat != null && chat.id != null && chat.id!.isNotEmpty) {
              // Get shared draft data
              final sharedDrafts = await draftSharingService.getDraftsSharedByMe();
              final sharedDraft = sharedDrafts.firstWhere(
                (d) => d['originalDraftId'] == draftId && 
                       (d['recipients'] as List).contains(person.id),
                orElse: () => widget.selectedDraft!,
              );

              // Add draft metadata to shared draft
              sharedDraft['videoPath'] = widget.selectedDraft!['videoPath'];
              sharedDraft['thumbnailPath'] = widget.selectedDraft!['thumbnailPath'];

              // Navigate to draft feedback view
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => DraftFeedbackView(
                    sharedDraft: sharedDraft,
                    chat: chat,
                    otherUserId: person.id,
                    otherUserName: person.displayName,
                    otherUserAvatarURL: person.avatarURL,
                  ),
                ),
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Draft shared successfully!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } else {
              // Chat creation failed
              debugPrint('❌ ChoosePersonView: Failed to create chat for user ${person.id}');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to create chat. The user may not be verified in the system.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          } else if (mounted) {
            debugPrint('❌ ChoosePersonView: Draft sharing failed for user ${person.id}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to share draft with ${person.displayName}. They may not be verified in the system.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } else {
        // No draft selected, just open regular chat
        final chatService = ChatService.shared;
        final chat = await chatService.fetchOrCreateChat(person.id);

        // Close loading dialog
        if (mounted) Navigator.of(context).pop();

        if (chat != null && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ChatView(
              chat: chat,
              otherUserId: person.id,
              otherUserName: person.displayName,
              otherUserAvatarURL: person.avatarURL,
              otherUserIsOnline: person.onlineStatus == user_model.OnlineStatus.online,
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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
          Expanded(
            child: Text(
              widget.selectedDraft != null ? 'Share Draft' : 'New Message',
              style: const TextStyle(
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
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: Colors.white.withValues(alpha: 0.7),
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
                color: Colors.white.withValues(alpha: 0.7),
                size: 20,
              ),
            ),
        ],
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
              color: Colors.white.withValues(alpha: 0.5),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No connections found for "$_searchQuery"'
                  : 'No connections yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Connect with friends to start messaging',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
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

  Widget _buildConnectionRow(user_model.User connection) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectPerson(connection),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Avatar with online indicator
                Stack(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
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
                                    color: Colors.grey.withValues(alpha: 0.3),
                                    child: Icon(
                                      Icons.person,
                                      color:
                                          Colors.white.withValues(alpha: 0.6),
                                      size: 24,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: Colors.grey.withValues(alpha: 0.3),
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  size: 24,
                                ),
                              ),
                      ),
                    ),
                    // Online indicator
                    if (connection.onlineStatus == user_model.OnlineStatus.online ||
                        connection.onlineStatus == user_model.OnlineStatus.streaming)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: connection.onlineStatus == user_model.OnlineStatus.streaming
                                ? Colors.purple
                                : Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF1C135D),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
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
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
