import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import '../models/user_model.dart' as user_model;
import '../services/chat_service.dart';
import '../services/draft_sharing_service.dart';
import '../services/follows_service.dart';
import '../services/user_blocking_service.dart';
import '../constants/app_colors.dart';
import 'chat_view_optimized.dart';
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
  bool _isSubmitting = false;
  String? _error;
  String? _activePersonId;
  final UserBlockingService _blockingService = UserBlockingService();

  @override
  void initState() {
    super.initState();
    _loadConnections();
    _blockingService.blockListRevision.addListener(_handleBlockListChanged);
  }

  @override
  void dispose() {
    _blockingService.blockListRevision.removeListener(_handleBlockListChanged);
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
      final blockedUserIds = (await _blockingService.getBlockedUsers()).toSet();

      // Create a combined list, prioritizing connections (mutual follows) first
      // Filter out users with invalid IDs to prevent sharing failures
      final allUsers = <user_model.User>[];
      final userIds = <String>{};

      // Add connections first (mutual follows - highest priority)
      for (final user in connectionsList) {
        if (user.id.isNotEmpty &&
            !blockedUserIds.contains(user.id) &&
            !userIds.contains(user.id)) {
          allUsers.add(user);
          userIds.add(user.id);
        }
      }

      // Add followers (they follow you)
      for (final user in followersList) {
        if (user.id.isNotEmpty &&
            !blockedUserIds.contains(user.id) &&
            !userIds.contains(user.id)) {
          allUsers.add(user);
          userIds.add(user.id);
        }
      }

      // Add following (you follow them)
      for (final user in followingList) {
        if (user.id.isNotEmpty &&
            !blockedUserIds.contains(user.id) &&
            !userIds.contains(user.id)) {
          allUsers.add(user);
          userIds.add(user.id);
        }
      }

      if (allUsers.length <
          connectionsList.length +
              followersList.length +
              followingList.length) {
        final filteredCount = (connectionsList.length +
                followersList.length +
                followingList.length) -
            allUsers.length;
        debugPrint(
            '⚠️ ChoosePersonView: Filtered out $filteredCount users with invalid IDs');
      }

      setState(() {
        _connections = allUsers;
        _isLoading = false;
      });

      debugPrint(
          '🔗 ChoosePersonView: Loaded ${allUsers.length} total users (${connectionsList.length} connections, ${followersList.length} followers, ${followingList.length} following)');
    } catch (e) {
      debugPrint('❌ ChoosePersonView: Error loading connections: $e');
      setState(() {
        _error = 'Failed to load connections: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _handleBlockListChanged() {
    _loadConnections();
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
    if (_isSubmitting) return;

    try {
      if (mounted) {
        setState(() {
          _isSubmitting = true;
          _activePersonId = person.id;
        });
      }

      if (widget.selectedDraft != null) {
        await _shareDraftWithPerson(person);
      } else {
        await _openChatWithPerson(person);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _activePersonId = null;
        });
      }
    }
  }

  Future<void> _shareDraftWithPerson(user_model.User person) async {
    final draftSharingService = DraftSharingService();
    final draftId = widget.selectedDraft!['id'] as String?;

    if (draftId == null || draftId.isEmpty) {
      _showErrorSnackBar('This draft is missing its ID and cannot be shared yet.');
      return;
    }

    if (person.id.isEmpty) {
      _showErrorSnackBar('This person is missing a valid account ID.');
      return;
    }

    debugPrint(
        '🔗 ChoosePersonView: Sharing draft $draftId with user ${person.id} (${person.displayName})');

    final result = await draftSharingService.shareDraftWithConnections(
      draftId: draftId,
      connectionIds: [person.id],
      message: 'Check out this draft and share your feedback!',
    );

    if (!result.isSuccess) {
      debugPrint('❌ ChoosePersonView: Draft sharing failed for user ${person.id}');
      _showErrorSnackBar(
        _draftShareFailureMessage(result, person.displayName),
      );
      return;
    }

    final chat = await ChatService.shared.fetchOrCreateChat(person.id);
    if (chat == null || chat.id == null || chat.id!.isEmpty) {
      debugPrint('❌ ChoosePersonView: Failed to create chat for user ${person.id}');
      _showErrorSnackBar(
        'The draft was shared, but we couldn’t open the feedback chat yet.',
      );
      return;
    }

    final sharedDrafts = await draftSharingService.getDraftsSharedByMe();
    final sharedDraft = sharedDrafts.firstWhere(
      (d) =>
          d['originalDraftId'] == draftId &&
          (d['recipients'] as List).contains(person.id),
      orElse: () => widget.selectedDraft!,
    );

    if (!mounted) return;
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
  }

  Future<void> _openChatWithPerson(user_model.User person) async {
    final chat = await ChatService.shared.fetchOrCreateChat(person.id);

    if (chat != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/inbox'),
          builder: (context) => ChatViewOptimized(
            chat: chat,
            otherUserId: person.id,
            otherUserName: person.displayName,
            otherUserAvatarURL: person.avatarURL,
            otherUserIsOnline:
                person.onlineStatus == user_model.OnlineStatus.online,
          ),
        ),
      );
      return;
    }

    if (mounted) {
      _showErrorSnackBar(
        'Couldn’t open a conversation with ${person.displayName} right now.',
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _draftShareFailureMessage(
    DraftShareResult result,
    String personName,
  ) {
    switch (result.failureReason) {
      case DraftShareFailureReason.unauthenticated:
        return 'Sign in again to share drafts.';
      case DraftShareFailureReason.missingDraftId:
        return 'This draft is missing its ID and can’t be shared yet.';
      case DraftShareFailureReason.noRecipients:
        return 'Choose someone to share this draft with.';
      case DraftShareFailureReason.recipientNotFound:
        return '$personName is not available for draft feedback yet.';
      case DraftShareFailureReason.draftNotFound:
        return 'This draft is no longer available on this device.';
      case DraftShareFailureReason.mediaPersistenceFailed:
        return 'We couldn’t prepare the draft media for sharing.';
      case DraftShareFailureReason.firestoreWriteFailed:
        return 'We couldn’t save the shared draft right now.';
      case DraftShareFailureReason.unexpected:
      case null:
        return result.message ??
            'Couldn’t share this draft with $personName right now.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090312),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Color(0xFF170726),
              Color(0xFF090312),
              Color(0xFF040106),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Search Bar
              _buildSearchBar(),

              if (widget.selectedDraft != null) _buildDraftContextCard(),

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

  Widget _buildDraftContextCard() {
    final draftCaption =
        (widget.selectedDraft?['caption'] as String?)?.trim() ?? '';
    final category = (widget.selectedDraft?['category'] as String?)?.trim();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF9248D2).withValues(alpha: 0.22),
            const Color(0xFF1670DE).withValues(alpha: 0.14),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withValues(alpha: 0.12),
            ),
            child: const Icon(
              Icons.drafts_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Share this draft for feedback',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  draftCaption.isEmpty
                      ? 'Choose someone from your network and we’ll drop the draft right into chat.'
                      : draftCaption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
                if (category != null && category.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _formatCategoryLabel(category),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
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
          onTap: _isSubmitting ? null : () => _selectPerson(connection),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.11),
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
                    if (connection.onlineStatus ==
                            user_model.OnlineStatus.online ||
                        connection.onlineStatus ==
                            user_model.OnlineStatus.streaming)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: connection.onlineStatus ==
                                    user_model.OnlineStatus.streaming
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
                  widget.selectedDraft != null
                      ? Icons.send_rounded
                      : Icons.chevron_right,
                  color: widget.selectedDraft != null
                      ? AppColors.accent
                      : Colors.white.withValues(alpha: 0.5),
                  size: 22,
                ),
                if (_isSubmitting && _activePersonId == connection.id) ...[
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCategoryLabel(String raw) {
    return raw
        .split(RegExp(r'[-_]'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
