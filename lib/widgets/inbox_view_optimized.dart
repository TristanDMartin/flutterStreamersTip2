import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat.dart' as app_chat;
import '../models/shared_draft.dart';
import '../models/user.dart' as app_user;
import '../services/inbox_service_optimized.dart';
import '../services/logging_service.dart';
import '../services/offline_inbox_service.dart';
import '../providers/unread_messages_provider.dart';
import 'chat_view.dart';
import 'new_message_view.dart';
// import 'draft_creation_view.dart'; // Removed - unused

class InboxViewOptimized extends ConsumerStatefulWidget {
  const InboxViewOptimized({super.key});

  @override
  ConsumerState<InboxViewOptimized> createState() => _InboxViewOptimizedState();
}

class _InboxViewOptimizedState extends ConsumerState<InboxViewOptimized>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final InboxServiceOptimized _inboxService = InboxServiceOptimized();
  final OfflineInboxService _offlineService = OfflineInboxService();
  final TextEditingController _searchController = TextEditingController();
  bool _isNavigating = false;

  // Constants
  static const Color _primaryColor = Color(0xFF9248D2);
  static const Color _secondaryColor = Color(0xFF7768DF);
  static const Color _accentColor = Color(0xFF1670DE);
  static const Color _successColor = Color(0xFF4CAF50);
  static const Color _backgroundDark = Color(0xFF6137EB);
  static const Color _backgroundMedium = Color(0xFF1C135D);

  // Data
  List<app_chat.Chat> _chats = [];
  List<SharedDraft> _sharedDrafts = [];
  List<app_chat.Chat> _filteredChats = [];
  List<SharedDraft> _filteredDrafts = [];
  final Map<String, app_user.User> _userProfiles = {};
  final Map<String, int> _unreadCounts = {};
  final Map<String, bool> _onlineStatus = {};

  // State
  bool _isLoading = true;
  String? _error;
  bool _isSelectionMode = false;
  final Set<String> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _initializeRealTimeUpdates();

    // Mark all messages as read when InboxView is opened
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await UnreadMessagesService.markAllVisibleAsRead();
      // Force refresh the unread messages provider
      ref.invalidate(unreadMessagesProvider);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _inboxService.stopRealTimeListeners();
    super.dispose();
  }

  void _initializeRealTimeUpdates() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Load offline data first
    await _loadOfflineData();

    // Start real-time listeners
    _inboxService.startRealTimeListeners(
      onChatsUpdate: (chats) async {
        await _loadUserDataForChats(chats);
        await _offlineService.cacheChats(chats);
        if (mounted) {
          setState(() {
            _chats = chats;
            _filteredChats = chats;
            _isLoading = false;
          });
        }
      },
      onDraftsUpdate: (drafts) async {
        await _offlineService.cacheDrafts(drafts);
        if (mounted) {
          setState(() {
            _sharedDrafts = drafts;
            _filteredDrafts = drafts;
          });
        }
      },
    );

    // Set up real-time user profile listeners for existing chats
    _setupUserProfileListeners();
  }

  void _setupUserProfileListeners() {
    final currentUser = _inboxService.auth.currentUser;
    if (currentUser == null) return;

    for (final chat in _chats) {
      final otherUserId = chat.participants.firstWhere(
        (id) => id != currentUser.uid,
        orElse: () => chat.participants.first,
      );

      // Listen to user profile changes
      FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && mounted) {
          final data = snapshot.data()!;
          final updatedUser = app_user.User(
            id: snapshot.id,
            displayName: data['displayName'] ?? 'User',
            username: data['username'] ?? 'user',
            bio: data['bio'],
            avatarURL: data['avatarURL'],
            onlineStatus: data['onlineStatus'] ?? 'offline',
            hashtags: data['hashtags'] is List
                ? List<String>.from(data['hashtags'])
                : [],
            aiSelf: data['aiSelf'] ?? '',
            postCount: data['postCount'] ?? 0,
            followerCount: data['followerCount'] ?? 0,
            followingCount: data['followingCount'] ?? 0,
            calendarEvents: [],
          );

          setState(() {
            _userProfiles[otherUserId] = updatedUser;
          });

          debugPrint(
              'InboxView: Updated user profile for $otherUserId - displayName: ${updatedUser.displayName}, username: ${updatedUser.username}');
        }
      });
    }
  }

  Future<void> _loadOfflineData() async {
    try {
      // Check if data is stale
      final isStale = await _offlineService.isDataStale();

      if (!isStale) {
        // Load cached data
        final cachedChats = await _offlineService.getCachedChats();
        final cachedDrafts = await _offlineService.getCachedDrafts();
        final cachedUserProfiles =
            await _offlineService.getCachedUserProfiles();
        final cachedUnreadCounts =
            await _offlineService.getCachedUnreadCounts();
        final cachedOnlineStatus =
            await _offlineService.getCachedOnlineStatus();

        if (mounted) {
          setState(() {
            _chats = cachedChats;
            _sharedDrafts = cachedDrafts;
            _filteredChats = cachedChats;
            _filteredDrafts = cachedDrafts;
            _userProfiles.addAll(cachedUserProfiles);
            _unreadCounts.addAll(cachedUnreadCounts);
            _onlineStatus.addAll(cachedOnlineStatus);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      LoggingService.instance.error('Error loading offline data: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      LoggingService.instance.info('Loading inbox data');

      // Load chats and drafts in parallel
      final results = await Future.wait([
        _inboxService.getChats(),
        _inboxService.getSharedDrafts(),
      ]);

      final chats = results[0] as List<app_chat.Chat>;
      final drafts = results[1] as List<SharedDraft>;

      // Load user profiles and unread counts for each chat
      await _loadUserDataForChats(chats);

      setState(() {
        _chats = chats;
        _sharedDrafts = drafts;
        _filteredChats = chats;
        _filteredDrafts = drafts;
        _isLoading = false;
      });

      LoggingService.instance.info(
          'Inbox data loaded successfully: ${_chats.length} chats, ${_sharedDrafts.length} drafts');
    } catch (e) {
      LoggingService.instance.error('Error loading inbox data: $e');
      setState(() {
        _error = 'Failed to load inbox data. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserDataForChats(List<app_chat.Chat> chats) async {
    final currentUser = _inboxService.auth.currentUser;
    if (currentUser == null) return;

    debugPrint('InboxView: Loading user data for ${chats.length} chats');

    // Load user profiles and unread counts in parallel
    final futures = <Future>[];

    for (final chat in chats) {
      // Get other user ID
      final otherUserId = chat.participants.firstWhere(
        (id) => id != currentUser.uid,
        orElse: () => chat.participants.first,
      );

      debugPrint('InboxView: Loading data for other user: $otherUserId');

      // Load user profile
      futures.add(_inboxService.getUserProfile(otherUserId).then((user) {
        if (user != null) {
          debugPrint(
              'InboxView: Loaded user profile - displayName: ${user.displayName}, username: ${user.username}, avatarURL: ${user.avatarURL}');
          _userProfiles[otherUserId] = user;
        } else {
          debugPrint('InboxView: Failed to load user profile for $otherUserId');
        }
      }));

      // Load unread count
      futures
          .add(_inboxService.getUnreadCount(chat.id ?? '').then((unreadCount) {
        _unreadCounts[chat.id ?? ''] = unreadCount;
      }));

      // Load online status
      futures.add(_inboxService.isUserOnline(otherUserId).then((isOnline) {
        _onlineStatus[otherUserId] = isOnline;
      }));
    }

    await Future.wait(futures);

    debugPrint('InboxView: Loaded ${_userProfiles.length} user profiles');

    // Cache user data offline
    await _offlineService.cacheUserProfiles(_userProfiles);
    await _offlineService.cacheUnreadCounts(_unreadCounts);
    await _offlineService.cacheOnlineStatus(_onlineStatus);
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredChats = _chats;
        _filteredDrafts = _sharedDrafts;
      } else {
        final lowerQuery = query.toLowerCase();

        // Enhanced chat filtering with user names
        _filteredChats = _chats.where((chat) {
          final currentUser = _inboxService.auth.currentUser;
          if (currentUser == null) return false;

          final otherUserId = chat.participants.firstWhere(
            (id) => id != currentUser.uid,
            orElse: () => chat.participants.first,
          );

          final userProfile = _userProfiles[otherUserId];
          final userName =
              userProfile?.displayName ?? userProfile?.username ?? '';
          final lastMessage = chat.lastMessage ?? '';

          return userName.toLowerCase().contains(lowerQuery) ||
              lastMessage.toLowerCase().contains(lowerQuery) ||
              otherUserId.toLowerCase().contains(lowerQuery);
        }).toList();

        // Enhanced draft filtering
        _filteredDrafts = _sharedDrafts.where((draft) {
          return draft.draftTitle.toLowerCase().contains(lowerQuery) ||
              (draft.message?.toLowerCase().contains(lowerQuery) ?? false) ||
              draft.senderName.toLowerCase().contains(lowerQuery) ||
              draft.receiverId.toLowerCase().contains(lowerQuery);
        }).toList();
      }
    });
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
            colors: [
              _backgroundDark,
              _backgroundMedium,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              _buildTabBar(),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _error != null
                        ? _buildErrorState()
                        : _buildTabContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          Row(
            children: [
              // Back button - clean design
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 20),
                padding: const EdgeInsets.all(8),
              ),
              const SizedBox(width: 16),
              // Title with better typography
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Messages',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      '${_chats.length} conversations',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Selection mode button - clean design
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _toggleSelectionMode();
                },
                icon: Icon(
                  _isSelectionMode ? Icons.close : Icons.checklist_rtl,
                  color: _isSelectionMode ? _primaryColor : Colors.white,
                  size: 20,
                ),
                padding: const EdgeInsets.all(8),
              ),
            ],
          ),
          if (_isSelectionMode) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: _primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedItems.length} selected',
                        style: const TextStyle(
                          color: _primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedItems.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedItems.clear();
                            });
                          },
                          child: const Text(
                            'Clear',
                            style: TextStyle(
                              color: _primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_selectedItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _selectedItems.length ==
                                    (_tabController.index == 0
                                        ? _filteredChats.length
                                        : _filteredDrafts.length)
                                ? () {
                                    setState(() {
                                      _selectedItems.clear();
                                    });
                                  }
                                : _selectAll,
                            icon: Icon(
                              _selectedItems.length ==
                                      (_tabController.index == 0
                                          ? _filteredChats.length
                                          : _filteredDrafts.length)
                                  ? Icons.deselect
                                  : Icons.select_all,
                              size: 16,
                            ),
                            label: Text(
                              _selectedItems.length ==
                                      (_tabController.index == 0
                                          ? _filteredChats.length
                                          : _filteredDrafts.length)
                                  ? 'Deselect All'
                                  : 'Select All',
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_tabController.index == 0) ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _markAsRead,
                              icon: const Icon(Icons.mark_email_read, size: 16),
                              label: const Text(
                                'Mark Read',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _successColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _deleteSelected,
                            icon: const Icon(Icons.delete, size: 16),
                            label: const Text(
                              'Delete',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
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
        decoration: InputDecoration(
          hintText: _tabController.index == 0
              ? 'Search conversations...'
              : 'Search drafts...',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          filled: false,
          border: InputBorder.none,
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.search_rounded,
              color: Colors.white.withValues(alpha: 0.6),
              size: 20,
            ),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                  icon: Icon(
                    Icons.clear_rounded,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 18,
                  ),
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        ),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildTabBar() {
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
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primaryColor, _secondaryColor],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chat_bubble_outline, size: 18),
                const SizedBox(width: 8),
                Text('Messages (${_chats.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.drafts_outlined, size: 18),
                const SizedBox(width: 8),
                Text('Drafts (${_sharedDrafts.length})'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: _primaryColor,
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildChatList(),
          _buildDraftsList(),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    if (_filteredChats.isEmpty) {
      return _buildEmptyState(
        'No messages yet',
        Icons.chat_bubble_outline,
        'Start a conversation with someone!',
        'New Message',
        _createNewMessage,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filteredChats.length,
      itemBuilder: (context, index) {
        final chat = _filteredChats[index];
        return _buildChatTile(chat);
      },
    );
  }

  Widget _buildDraftsList() {
    if (_filteredDrafts.isEmpty) {
      return _buildEmptyState(
        'No shared drafts yet',
        Icons.drafts,
        'Create a draft to share with others!',
        'Create Draft',
        _createNewDraft,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filteredDrafts.length,
      itemBuilder: (context, index) {
        final draft = _filteredDrafts[index];
        return _buildDraftTile(draft);
      },
    );
  }

  Widget _buildChatTile(app_chat.Chat chat) {
    final isSelected = _selectedItems.contains(chat.id);
    final currentUser = _inboxService.auth.currentUser;
    final otherUserId = currentUser != null
        ? chat.participants.firstWhere(
            (id) => id != currentUser.uid,
            orElse: () => chat.participants.first,
          )
        : chat.participants.first;

    final userProfile = _userProfiles[otherUserId];
    final participantName =
        userProfile?.displayName ?? userProfile?.username ?? 'Loading...';
    final initials =
        participantName.isNotEmpty && participantName != 'Loading...'
            ? participantName[0].toUpperCase()
            : 'L';
    final unreadCount = _unreadCounts[chat.id ?? ''] ?? 0;
    final isOnline = _onlineStatus[otherUserId] ?? false;

    debugPrint(
        'InboxView: Building chat tile for $otherUserId - userProfile: ${userProfile != null ? 'loaded' : 'null'}, name: $participantName');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? _primaryColor.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? _primaryColor.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.08),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _isSelectionMode
              ? () => _toggleSelection(chat.id ?? '')
              : () => _openChat(chat),
          onLongPress: () {
            HapticFeedback.lightImpact();
            _toggleSelectionMode();
            _toggleSelection(chat.id ?? '');
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar with selection indicator and online status
                Stack(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: userProfile?.avatarURL != null
                            ? null
                            : const LinearGradient(
                                colors: [_primaryColor, _secondaryColor],
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: userProfile?.avatarURL != null
                          ? ClipOval(
                              child: Image.network(
                                userProfile!.avatarURL!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Text(
                                      initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          : Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                    // Online status indicator
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: _successColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    // Selection indicator
                    if (isSelected)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: _primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                    // Unread count badge
                    if (unreadCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: const BoxDecoration(
                            color: _primaryColor,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Chat content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              participantName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatTime(chat.lastTimestamp),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _buildMessageStatusIndicator(chat),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chat.lastMessage ?? 'No messages yet',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Arrow indicator
                if (!_isSelectionMode)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraftTile(SharedDraft draft) {
    final isSelected = _selectedItems.contains(draft.id);
    final isUnread = draft.status != SharedDraftStatus.viewed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? _primaryColor.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? _primaryColor.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.08),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _isSelectionMode
              ? () => _toggleSelection(draft.id)
              : () => _openDraft(draft),
          onLongPress: () {
            HapticFeedback.lightImpact();
            _toggleSelectionMode();
            _toggleSelection(draft.id);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Draft icon with selection indicator
                Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [_accentColor, _secondaryColor],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _accentColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.drafts_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: _primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    if (isUnread)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: _primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.circle,
                              color: Colors.white,
                              size: 8,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Draft content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              draft.draftTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isUnread
                                  ? _primaryColor.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isUnread ? 'New' : 'Viewed',
                              style: TextStyle(
                                color: isUnread
                                    ? _primaryColor
                                    : Colors.white.withValues(alpha: 0.6),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        draft.message ?? 'No message',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Arrow indicator
                if (!_isSelectionMode)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, IconData icon, String subtitle,
      String buttonText, VoidCallback onPressed) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon container
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.1),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            // Title with better typography
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Subtitle with better styling
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            // Enhanced button design
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primaryColor, _secondaryColor],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      buttonText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated loading indicator
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _primaryColor.withValues(alpha: 0.8),
                    ),
                    strokeWidth: 3,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Loading conversations...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a moment',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Error loading inbox',
              style: TextStyle(
                color: Colors.red[400],
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedItems.clear();
      }
    });
  }

  void _toggleSelection(String itemId) {
    setState(() {
      if (_selectedItems.contains(itemId)) {
        _selectedItems.remove(itemId);
      } else {
        _selectedItems.add(itemId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_tabController.index == 0) {
        _selectedItems.clear();
        _selectedItems.addAll(_filteredChats
            .map((chat) => chat.id ?? '')
            .where((id) => id.isNotEmpty));
      } else {
        _selectedItems.clear();
        _selectedItems.addAll(_filteredDrafts.map((draft) => draft.id));
      }
    });
  }

  void _deleteSelected() async {
    if (_selectedItems.isEmpty) return;

    final confirmed = await _showDeleteConfirmation();
    if (!confirmed) return;

    try {
      if (_tabController.index == 0) {
        // Delete selected chats
        await _inboxService.deleteMultipleChats(_selectedItems.toList());
        await _loadData(); // Reload data
      } else {
        // Delete selected drafts
        for (final draftId in _selectedItems) {
          await _inboxService.deleteSharedDraft(draftId);
        }
        await _loadData(); // Reload data
      }

      setState(() {
        _selectedItems.clear();
        _isSelectionMode = false;
      });

      _showSnackBar('${_selectedItems.length} items deleted', _primaryColor);
    } catch (e) {
      _showSnackBar('Error deleting items', Colors.red);
    }
  }

  void _markAsRead() async {
    if (_selectedItems.isEmpty) return;

    try {
      for (final chatId in _selectedItems) {
        await _inboxService.markAsRead(chatId);
      }

      setState(() {
        for (final chatId in _selectedItems) {
          _unreadCounts[chatId] = 0;
        }
        _selectedItems.clear();
        _isSelectionMode = false;
      });

      _showSnackBar(
          '${_selectedItems.length} chats marked as read', _primaryColor);
    } catch (e) {
      _showSnackBar('Error marking as read', Colors.red);
    }
  }

  Future<bool> _showDeleteConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _backgroundMedium,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Delete Items',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Are you sure you want to delete ${_selectedItems.length} selected items? This action cannot be undone.',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _createNewMessage() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      _createSlideTransition(page: const NewMessageView()),
    );
  }

  void _createNewDraft() async {
    HapticFeedback.lightImpact();

    if (mounted) {
      // final result = await Navigator.of(context).push(
      //   _createSlideTransition(page: const DraftCreationView()),
      // );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft creation feature coming soon!')),
      );
      final result = null;

      // Refresh data if draft was created
      if (result == true) {
        _refreshData();
      }
    }
  }

  void _openChat(app_chat.Chat chat) async {
    HapticFeedback.lightImpact();

    // Prevent multiple simultaneous taps
    if (_isNavigating) return;
    _isNavigating = true;

    try {
      // Get other user ID
      final currentUser = _inboxService.auth.currentUser;
      if (currentUser == null) return;

      final otherUserId = chat.participants.firstWhere(
        (id) => id != currentUser.uid,
        orElse: () => chat.participants.first,
      );

      debugPrint('InboxView: Opening chat with user: $otherUserId');

      // Mark messages as read when opening chat (non-blocking)
      _inboxService.markAsRead(chat.id ?? '').catchError((error) {
        debugPrint('InboxView: Error marking as read: $error');
      });

      // Update unread count
      if (mounted) {
        setState(() {
          _unreadCounts[chat.id ?? ''] = 0;
        });
      }

      // Force refresh the unread messages provider
      ref.invalidate(unreadMessagesProvider);

      final userProfile = _userProfiles[otherUserId];

      if (mounted) {
        // Use a simpler navigation without complex transitions
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatView(
              chat: chat,
              otherUserId: otherUserId,
              otherUserName:
                  userProfile?.displayName ?? userProfile?.username ?? 'User',
              otherUserAvatarURL: userProfile?.avatarURL,
              otherUserIsOnline: _onlineStatus[otherUserId] ?? false,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('InboxView: Error opening chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open chat: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      _isNavigating = false;
    }
  }

  void _openDraft(SharedDraft draft) async {
    HapticFeedback.lightImpact();

    // Mark draft as viewed
    await _inboxService.markAsRead(draft.id);

    // Navigate to draft creation view for editing
    if (mounted) {
      // final result = await Navigator.of(context).push(
      //   _createSlideTransition(
      //     page: DraftCreationView(existingDraft: draft),
      //   ),
      // );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft editing feature coming soon!')),
      );
      final result = null;

      // Refresh data if draft was modified
      if (result == true) {
        _refreshData();
      }
    }
  }

  Widget _buildMessageStatusIndicator(app_chat.Chat chat) {
    final currentUser = _inboxService.auth.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    // Check if the last message was sent by current user
    final isLastMessageFromCurrentUser =
        chat.participants.contains(currentUser.uid);

    if (!isLastMessageFromCurrentUser) {
      return const SizedBox.shrink();
    }

    // For now, show a simple sent indicator
    // In a real app, this would check actual message status from Firestore
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: _successColor,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check,
        color: Colors.white,
        size: 10,
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  // Helper method for creating slide transitions
  PageRouteBuilder _createSlideTransition({
    required Widget page,
    Offset begin = const Offset(0.0, 1.0),
    bool fullscreenDialog = true,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        return SlideTransition(position: offsetAnimation, child: child);
      },
      fullscreenDialog: fullscreenDialog,
    );
  }

  // Helper method for showing SnackBars
  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
