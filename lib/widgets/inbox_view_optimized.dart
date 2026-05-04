import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../models/chat.dart' as app_chat;
import '../models/shared_draft.dart';
import '../models/user.dart' as app_user;
import '../services/inbox_service_optimized.dart';
import '../services/logging_service.dart';
import '../services/offline_inbox_service.dart';
import '../services/chat_service.dart';
import '../services/draft_sharing_service.dart';
import '../services/local_draft_service.dart';
import '../services/user_blocking_service.dart';
import 'status_aware_avatar.dart';
import '../utils/avatar_url_resolver.dart';
import '../utils/responsive_layout.dart';
import '../providers/unread_messages_provider.dart';
import '../routing/app_navigator.dart';
import 'new_message_view.dart';
import 'draft_feedback_view.dart';
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
  final UserBlockingService _blockingService = UserBlockingService();
  final TextEditingController _searchController = TextEditingController();
  bool _isNavigating = false;

  // Constants
  static const Color _primaryColor = Color(0xFF9248D2);
  static const Color _secondaryColor = Color(0xFF7768DF);
  static const Color _accentColor = Color(0xFF1670DE);
  static const Color _successColor = Color(0xFF4CAF50);
  static const bool _showSharedDraftsTab = false;

  ColorScheme get _th => Theme.of(context).colorScheme;
  Color get _on => _th.onSurface;
  Color get _onP => _th.onPrimary;

  // Data
  List<app_chat.Chat> _chats = [];
  List<SharedDraft> _sharedDrafts = [];
  List<app_chat.Chat> _filteredChats = [];
  List<SharedDraft> _filteredDrafts = [];
  final Map<String, app_user.User> _userProfiles = {};
  final Map<String, int> _unreadCounts = {};
  final Map<String, bool> _onlineStatus = {};
  final Map<String, StreamSubscription<DocumentSnapshot>>
      _unreadCountSubscriptions = {};
  final Map<String, StreamSubscription<DocumentSnapshot>>
      _userProfileSubscriptions = {};

  // State
  bool _isLoading = true;
  String? _error;
  bool _isSelectionMode = false;
  final Set<String> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _showSharedDraftsTab ? 2 : 1,
      vsync: this,
    );

    _initializeRealTimeUpdates();
    _blockingService.blockListRevision.addListener(_handleBlockListChanged);

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
    _blockingService.blockListRevision.removeListener(_handleBlockListChanged);
    // Cancel all unread count subscriptions
    for (final subscription in _unreadCountSubscriptions.values) {
      subscription.cancel();
    }
    _unreadCountSubscriptions.clear();
    for (final subscription in _userProfileSubscriptions.values) {
      subscription.cancel();
    }
    _userProfileSubscriptions.clear();
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
        // Filter out invalid chats (with empty participant IDs)
        final validChats = await _filterVisibleChats(chats);

        // Set up real-time unread count listeners for each chat
        _setupUnreadCountListeners(validChats);
        _setupUserProfileListeners(validChats);

        await _loadUserDataForChats(validChats);
        await _offlineService.cacheChats(validChats);
        if (mounted) {
          setState(() {
            _chats = validChats;
            _filteredChats = validChats;
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
  }

  /// Set up real-time listeners for unread counts per chat
  void _setupUnreadCountListeners(List<app_chat.Chat> chats) {
    final currentUser = _inboxService.auth.currentUser;
    if (currentUser == null) return;

    // Cancel subscriptions for chats that no longer exist
    final currentChatIds =
        chats.map((c) => c.id ?? '').where((id) => id.isNotEmpty).toSet();
    final subscriptionsToCancel = <String>[];
    _unreadCountSubscriptions.forEach((chatId, subscription) {
      if (!currentChatIds.contains(chatId)) {
        subscriptionsToCancel.add(chatId);
      }
    });
    for (final chatId in subscriptionsToCancel) {
      _unreadCountSubscriptions[chatId]?.cancel();
      _unreadCountSubscriptions.remove(chatId);
    }

    // Set up listeners for each chat
    for (final chat in chats) {
      final chatId = chat.id ?? '';
      if (chatId.isEmpty || _unreadCountSubscriptions.containsKey(chatId)) {
        continue; // Already listening or invalid chat ID
      }

      // Listen to chat document for unread count changes
      final subscription = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .snapshots()
          .listen((snapshot) {
        if (!snapshot.exists || !mounted) return;

        final data = snapshot.data()!;
        final unreadField = 'unreadCount_${currentUser.uid}';
        final dynamic unreadValue = data[unreadField];
        final unreadCount = unreadValue != null
            ? (unreadValue is int ? unreadValue : (unreadValue as num).toInt())
            : 0;

        if (mounted) {
          setState(() {
            _unreadCounts[chatId] = unreadCount;
          });
        }
      });

      _unreadCountSubscriptions[chatId] = subscription;
    }
  }

  void _setupUserProfileListeners(List<app_chat.Chat> chats) {
    final currentUser = _inboxService.auth.currentUser;
    if (currentUser == null) return;

    final nextUserIds = chats
        .expand((chat) => chat.participants)
        .where((id) => id.isNotEmpty && id != currentUser.uid)
        .toSet();
    final subscriptionsToCancel = _userProfileSubscriptions.keys
        .where((id) => !nextUserIds.contains(id))
        .toList();
    for (final userId in subscriptionsToCancel) {
      _userProfileSubscriptions[userId]?.cancel();
      _userProfileSubscriptions.remove(userId);
    }

    for (final chat in chats) {
      // Filter out empty IDs and current user
      final validParticipants = chat.participants
          .where((id) => id.isNotEmpty && id != currentUser.uid)
          .toList();

      if (validParticipants.isEmpty) continue;

      final otherUserId = validParticipants.first;
      if (_userProfileSubscriptions.containsKey(otherUserId)) continue;

      // Listen to user profile changes
      final subscription = FirebaseFirestore.instance
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
            avatarURL: resolveAvatarUrl(data),
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
        }
      });
      _userProfileSubscriptions[otherUserId] = subscription;
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

        // Filter out invalid chats (with empty participant IDs)
        final validCachedChats = await _filterVisibleChats(cachedChats);

        if (mounted) {
          setState(() {
            _chats = validCachedChats;
            _sharedDrafts = cachedDrafts;
            _filteredChats = validCachedChats;
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

      final allChats = results[0] as List<app_chat.Chat>;
      final drafts = results[1] as List<SharedDraft>;

      // Filter out invalid chats (with empty participant IDs)
      final validChats = await _filterVisibleChats(allChats);

      // Load user profiles and unread counts for each chat
      _setupUnreadCountListeners(validChats);
      _setupUserProfileListeners(validChats);
      await _loadUserDataForChats(validChats);

      setState(() {
        _chats = validChats;
        _sharedDrafts = drafts;
        _filteredChats = validChats;
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

  /// Filter out chats with invalid participants (empty IDs or only current user)
  List<app_chat.Chat> _filterValidChats(List<app_chat.Chat> chats) {
    final currentUser = _inboxService.auth.currentUser;
    if (currentUser == null) return chats;

    return chats.where((chat) {
      final validParticipants = chat.participants
          .where((id) => id.isNotEmpty && id != currentUser.uid)
          .toList();
      return validParticipants.isNotEmpty;
    }).toList();
  }

  Future<List<app_chat.Chat>> _filterVisibleChats(
      List<app_chat.Chat> chats) async {
    final validChats = _filterValidChats(chats);
    final blockedUserIds = (await _blockingService.getBlockedUsers()).toSet();
    if (blockedUserIds.isEmpty) {
      return validChats;
    }

    final currentUser = _inboxService.auth.currentUser;
    if (currentUser == null) return validChats;

    return validChats.where((chat) {
      final otherUserId = chat.participants.firstWhere(
        (id) => id.isNotEmpty && id != currentUser.uid,
        orElse: () => '',
      );
      return otherUserId.isNotEmpty && !blockedUserIds.contains(otherUserId);
    }).toList();
  }

  Future<void> _loadUserDataForChats(List<app_chat.Chat> chats) async {
    final currentUser = _inboxService.auth.currentUser;
    if (currentUser == null) return;

    // Load user profiles and unread counts in parallel
    final futures = <Future>[];

    for (final chat in chats) {
      // Filter out empty IDs and current user
      final validParticipants = chat.participants
          .where((id) => id.isNotEmpty && id != currentUser.uid)
          .toList();

      if (validParticipants.isEmpty) continue;

      final otherUserId = validParticipants.first;

      // Load user profile
      futures.add(_inboxService.getUserProfile(otherUserId).then((user) {
        if (user != null) {
          _userProfiles[otherUserId] = user;
        }
      }));

      // Load initial unread count from chat document (real-time updates handled by listener)
      final chatId = chat.id ?? '';
      if (chatId.isNotEmpty) {
        // Get unread count from chat document directly
        futures.add(
          FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .get()
              .then((doc) {
            if (doc.exists) {
              final data = doc.data()!;
              final currentUser = _inboxService.auth.currentUser;
              if (currentUser != null) {
                final unreadField = 'unreadCount_${currentUser.uid}';
                final dynamic unreadValue = data[unreadField];
                final unreadCount = unreadValue != null
                    ? (unreadValue is int
                        ? unreadValue
                        : (unreadValue as num).toInt())
                    : 0;
                _unreadCounts[chatId] = unreadCount;
              }
            }
          }),
        );
      }

      // Load online status
      futures.add(_inboxService.isUserOnline(otherUserId).then((isOnline) {
        _onlineStatus[otherUserId] = isOnline;
      }));
    }

    await Future.wait(futures);
    // Cache user data offline
    await _offlineService.cacheUserProfiles(_userProfiles);
    await _offlineService.cacheUnreadCounts(_unreadCounts);
    await _offlineService.cacheOnlineStatus(_onlineStatus);
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  void _handleBlockListChanged() {
    unawaited(_refreshData());
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        // _chats is already filtered, so we can use it directly
        _filteredChats = _chats;
        _filteredDrafts = _sharedDrafts;
      } else {
        final lowerQuery = query.toLowerCase();

        // Enhanced chat filtering with user names
        _filteredChats = _chats.where((chat) {
          final currentUser = _inboxService.auth.currentUser;
          if (currentUser == null) return false;

          // Filter out empty IDs and current user
          final validParticipants = chat.participants
              .where((id) => id.isNotEmpty && id != currentUser.uid)
              .toList();

          if (validParticipants.isEmpty) return false;

          final otherUserId = validParticipants.first;

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildTabBar(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.02),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _isLoading
                    ? _buildLoadingState()
                    : _error != null
                        ? _buildErrorState()
                        : _buildTabContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final responsive = context.responsive;
    final ColorScheme c = Theme.of(context).colorScheme;
    final Color on = c.onSurface;
    return Container(
      margin: EdgeInsets.fromLTRB(
        responsive.spacing(20),
        responsive.spacing(12),
        responsive.spacing(20),
        responsive.spacing(12),
      ),
      padding: EdgeInsets.fromLTRB(
        responsive.spacing(20),
        responsive.spacing(18),
        responsive.spacing(20),
        responsive.spacing(18),
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(responsive.radius(28)),
        border: Border.all(
          color: on.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: c.shadow.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
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
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  color: on,
                  size: 20,
                ),
                padding: const EdgeInsets.all(8),
              ),
              SizedBox(width: responsive.spacing(16)),
              // Title with better typography
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Messages',
                      style: TextStyle(
                        color: on,
                        fontSize: responsive.font(28),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      '${_chats.length} conversations',
                      style: TextStyle(
                        color: on.withValues(alpha: 0.6),
                        fontSize: responsive.font(14),
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
                  color: _isSelectionMode ? _primaryColor : on,
                  size: 20,
                ),
                padding: const EdgeInsets.all(8),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _isSelectionMode
                  ? Padding(
                      key: const ValueKey('selection-controls'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
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
                                          _on.withValues(alpha: 0.1),
                                      foregroundColor: on,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_tabController.index == 0) ...[
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _markAsRead,
                                      icon: const Icon(Icons.mark_email_read,
                                          size: 16),
                                      label: const Text(
                                        'Mark Read',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _successColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
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
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox(
                      key: ValueKey('selection-placeholder'),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final responsive = context.responsive;

    return Container(
      margin: EdgeInsets.fromLTRB(
        responsive.spacing(20),
        0,
        responsive.spacing(20),
        responsive.spacing(10),
      ),
      decoration: BoxDecoration(
        color: _on.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(responsive.radius(22)),
        border: Border.all(
          color: _on.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: _tabController.index == 0
              ? 'Search conversations...'
              : 'Search drafts...',
          hintStyle: TextStyle(
            color: _on.withValues(alpha: 0.5),
            fontSize: responsive.font(16),
            fontWeight: FontWeight.w400,
          ),
          filled: false,
          border: InputBorder.none,
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.search_rounded,
              color: _on.withValues(alpha: 0.6),
              size: responsive.icon(20),
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
                    color: _on.withValues(alpha: 0.6),
                    size: 18,
                  ),
                )
              : null,
          contentPadding: EdgeInsets.symmetric(
            horizontal: responsive.spacing(8),
            vertical: responsive.spacing(16),
          ),
        ),
        style: TextStyle(
          color: _on,
          fontSize: responsive.font(16),
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final responsive = context.responsive;

    return Container(
      margin: EdgeInsets.fromLTRB(
        responsive.spacing(20),
        0,
        responsive.spacing(20),
        responsive.spacing(12),
      ),
      decoration: BoxDecoration(
        color: _on.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(responsive.radius(22)),
        border: Border.all(
          color: _on.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (_) => setState(() {}),
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primaryColor, _secondaryColor],
          ),
          borderRadius: BorderRadius.circular(responsive.radius(20)),
        ),
        labelColor: _onP,
        unselectedLabelColor: _on.withValues(alpha: 0.6),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: responsive.font(16),
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: responsive.font(16),
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
                Text('Chats (${_chats.length})'),
              ],
            ),
          ),
          if (_showSharedDraftsTab)
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.drafts_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text('Shared Drafts (${_sharedDrafts.length})'),
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
      backgroundColor: _on.withValues(alpha: 0.1),
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildChatList(),
          if (_showSharedDraftsTab) _buildDraftsList(),
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
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
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
        'Shared draft feedback will appear here once someone sends you one.',
        'Refresh',
        _refreshData,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
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

    // Filter out empty IDs and current user
    final validParticipants = chat.participants
        .where((id) =>
            id.isNotEmpty && (currentUser == null || id != currentUser.uid))
        .toList();

    if (validParticipants.isEmpty) {
      // Show a placeholder for invalid chats
      return ListTile(
        leading: const CircleAvatar(child: Icon(Icons.error)),
        title: const Text('Invalid chat'),
        subtitle: const Text('Missing participant information'),
      );
    }

    final otherUserId = validParticipants.first;

    final userProfile = _userProfiles[otherUserId];
    final participantName =
        userProfile?.displayName ?? userProfile?.username ?? 'Loading...';
    final unreadCount = _unreadCounts[chat.id ?? ''] ?? 0;
    final bool isOnline = (_onlineStatus[otherUserId] ?? false) ||
        userProfile?.onlineStatus.toLowerCase() == 'online';
    final secondaryLabel = isOnline
        ? 'Online now'
        : ((userProfile?.username.isNotEmpty) ?? false)
            ? '@${userProfile!.username}'
            : 'Conversation';
    final bool isMuted =
        currentUser != null && chat.mutedBy.contains(currentUser.uid);
    final bool hasUnread = unreadCount > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? _primaryColor.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? _primaryColor.withValues(alpha: 0.55)
              : Colors.transparent,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _isSelectionMode
              ? () => _toggleSelection(chat.id ?? '')
              : () => _openChat(chat),
          onLongPress: () {
            HapticFeedback.lightImpact();
            _toggleSelectionMode();
            _toggleSelection(chat.id ?? '');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                // Avatar with selection indicator and online status
                Stack(
                  children: [
                    StatusAwareAvatar(
                      userId: otherUserId,
                      avatarURL: userProfile?.avatarURL,
                      radius: 27,
                      showOnlineIndicator: true,
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
                          child: Icon(
                            Icons.check,
                            color: _onP,
                            size: 10,
                          ),
                        ),
                      ),
                    // Unread count badge
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: _primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    // Mute indicator
                    if (isMuted)
                      Positioned(
                        left: -4,
                        top: -4,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _th.surface,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.volume_off,
                            color: _onP,
                            size: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                // Chat content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        participantName,
                        style: TextStyle(
                          color: _on,
                          fontSize: 19,
                          fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (chat.lastMessage ?? secondaryLabel).trim().isEmpty
                                  ? secondaryLabel
                                  : (chat.lastMessage ?? secondaryLabel),
                              style: TextStyle(
                                color: _on.withValues(alpha: 0.66),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatTime(chat.lastTimestamp),
                            style: TextStyle(
                              color: _on.withValues(alpha: 0.58),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isMuted) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.volume_off_rounded,
                              size: 14,
                              color: _on.withValues(alpha: 0.55),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow indicator
                if (!_isSelectionMode)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: _on.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: _on.withValues(alpha: 0.62),
                      size: 18,
                    ),
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
    final draftSubtitle = draft.senderName.isNotEmpty
        ? 'From ${draft.senderName}'
        : 'Shared draft';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? _primaryColor.withValues(alpha: 0.15)
            : _on.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSelected
              ? _primaryColor.withValues(alpha: 0.5)
              : _on.withValues(alpha: 0.10),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: _isSelectionMode
              ? () => _toggleSelection(draft.id)
              : () => _openDraft(draft),
          onLongPress: () {
            HapticFeedback.lightImpact();
            _toggleSelectionMode();
            _toggleSelection(draft.id);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                      child: Center(
                        child: Icon(
                          Icons.drafts_rounded,
                          color: _onP,
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
                          child: Icon(
                            Icons.check,
                            color: _onP,
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
                          child: Center(
                            child: Icon(
                              Icons.circle,
                              color: _onP,
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  draft.draftTitle,
                                  style: TextStyle(
                                    color: _on,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  draftSubtitle,
                                  style: TextStyle(
                                    color: _on.withValues(alpha: 0.52),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isUnread
                                  ? _primaryColor.withValues(alpha: 0.2)
                                  : _on.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isUnread ? 'New' : 'Viewed',
                              style: TextStyle(
                                color: isUnread
                                    ? _primaryColor
                                    : _on.withValues(alpha: 0.6),
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
                          color: _on.withValues(alpha: 0.7),
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
                    color: _on.withValues(alpha: 0.4),
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
      String buttonText, VoidCallback onPressed,
      {IconData actionIcon = Icons.add_rounded}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          key: ValueKey('empty-$title'),
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
          decoration: BoxDecoration(
            color: _on.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _on.withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.supportAccentGradient,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withValues(alpha: 0.30),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        size: 40,
                        color: _onP,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  color: _on,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: TextStyle(
                  color: _on.withValues(alpha: 0.64),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.supportAccentGradient,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withValues(alpha: 0.36),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        actionIcon,
                        color: _onP,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        buttonText,
                        style: TextStyle(
                          color: _onP,
                          fontSize: 15,
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
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        key: const ValueKey('loading-state'),
        constraints: const BoxConstraints(maxWidth: 420),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
        decoration: BoxDecoration(
          color: _on.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _on.withValues(alpha: 0.10),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.88 + (0.12 * value),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: _on.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _on.withValues(alpha: 0.14),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _primaryColor.withValues(alpha: 0.9),
                        ),
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 22),
            Text(
              'Loading your inbox',
              style: TextStyle(
                color: _on,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We’re gathering your latest conversations and shared drafts.',
              style: TextStyle(
                color: _on.withValues(alpha: 0.62),
                fontSize: 14,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          key: const ValueKey('error-state'),
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
          decoration: BoxDecoration(
            color: _on.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _on.withValues(alpha: 0.10),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.28),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Colors.red[300],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'We couldn’t load your inbox',
                style: TextStyle(
                  color: _on,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Unknown error',
                style: TextStyle(
                  color: _on.withValues(alpha: 0.64),
                  fontSize: 14,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 26),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.supportAccentGradient,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ElevatedButton(
                  onPressed: _loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Try Again',
                    style: TextStyle(
                      color: _onP,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
    final int deletedCount = _selectedItems.length;

    try {
      if (_tabController.index == 0) {
        // Delete selected chats
        await _inboxService.deleteMultipleChats(_selectedItems.toList());
        await _loadData(); // Reload data
      } else {
        // Delete selected drafts
        final selectedDrafts = _sharedDrafts
            .where((draft) => _selectedItems.contains(draft.id))
            .toList();
        for (final draft in selectedDrafts) {
          final draftDocId = await _resolveSharedDraftDocumentId(draft);
          await _inboxService.deleteSharedDraft(draftDocId);
        }
        await _loadData(); // Reload data
      }

      setState(() {
        _selectedItems.clear();
        _isSelectionMode = false;
      });

      _showSnackBar('$deletedCount items deleted', _primaryColor);
    } catch (e) {
      _showSnackBar('Error deleting items', Colors.red);
    }
  }

  Future<String> _resolveSharedDraftDocumentId(SharedDraft draft) async {
    if (draft.id.isEmpty) return draft.id;

    try {
      final directDoc = await FirebaseFirestore.instance
          .collection('shared_drafts')
          .doc(draft.id)
          .get();
      if (directDoc.exists) {
        return draft.id;
      }

      final matchingDrafts = await FirebaseFirestore.instance
          .collection('shared_drafts')
          .where('originalDraftId', isEqualTo: draft.draftId)
          .where('sharerId', isEqualTo: draft.senderId)
          .where('recipients', arrayContains: draft.receiverId)
          .limit(1)
          .get();

      if (matchingDrafts.docs.isNotEmpty) {
        return matchingDrafts.docs.first.id;
      }
    } catch (e) {
      debugPrint('❌ Error resolving shared draft document ID: $e');
    }

    return draft.id;
  }

  void _markAsRead() async {
    if (_selectedItems.isEmpty) return;
    final int markedCount = _selectedItems.length;

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

      _showSnackBar('$markedCount chats marked as read', _primaryColor);
    } catch (e) {
      _showSnackBar('Error marking as read', Colors.red);
    }
  }

  Future<bool> _showDeleteConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            final ColorScheme c = Theme.of(context).colorScheme;
            return AlertDialog(
            backgroundColor: c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Delete Items',
              style: TextStyle(color: c.onSurface),
            ),
            content: Text(
              'Are you sure you want to delete ${_selectedItems.length} selected items? This action cannot be undone.',
              style: TextStyle(color: c.onSurface.withValues(alpha: 0.7)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: c.onSurface.withValues(alpha: 0.6)),
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
            );
          },
        ) ??
        false;
  }

  void _createNewMessage() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      _createSlideTransition(page: const NewMessageView()),
    );
  }

  void _openChat(app_chat.Chat chat) async {
    HapticFeedback.lightImpact();

    // Prevent multiple simultaneous taps
    if (_isNavigating) return;
    _isNavigating = true;

    try {
      // Get current user
      final currentUser = _inboxService.auth.currentUser;
      if (currentUser == null) {
        _isNavigating = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to open chats'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Debug: Log chat information
      debugPrint('🔍 InboxView: Chat ID: ${chat.id}');
      debugPrint('🔍 InboxView: Chat participants: ${chat.participants}');
      debugPrint('🔍 InboxView: Current user: ${currentUser.uid}');

      // Try to get other user ID from participants
      String? otherUserId;

      if (chat.participants.isNotEmpty) {
        // Get other user ID - filter out empty IDs and current user
        final validParticipants = chat.participants
            .where((id) => id.isNotEmpty && id != currentUser.uid)
            .toList();

        if (validParticipants.isNotEmpty) {
          otherUserId = validParticipants.first;
          debugPrint(
              '✅ InboxView: Found other user from participants: $otherUserId');
        } else {
          debugPrint(
              '⚠️ InboxView: No valid other participant in participants list');
        }
      } else {
        debugPrint('⚠️ InboxView: Chat has no participants list');
      }

      // If we couldn't determine other user from participants, try to fetch from Firestore
      if (otherUserId == null && chat.id != null && chat.id!.isNotEmpty) {
        debugPrint(
            '🔄 InboxView: Attempting to fetch chat from Firestore: ${chat.id}');
        try {
          final chatDoc = await FirebaseFirestore.instance
              .collection('chats')
              .doc(chat.id!)
              .get();

          if (chatDoc.exists) {
            final data = chatDoc.data();
            final participants = List<String>.from(data?['participants'] ?? []);
            debugPrint(
                '🔄 InboxView: Fetched participants from Firestore: $participants');

            // Update the chat object with fresh data from Firestore
            final firestoreChat = app_chat.Chat.fromJson(data!);
            final updatedChat = firestoreChat.copyWith(id: chat.id);

            // Try to find other user from fresh participants
            final validParticipants = participants
                .where((id) => id.isNotEmpty && id != currentUser.uid)
                .toList();

            if (validParticipants.isNotEmpty) {
              final foundOtherUserId = validParticipants.first;
              debugPrint(
                  '✅ InboxView: Found other user from Firestore: $foundOtherUserId');

              // Use the updated chat from Firestore if it has valid participants
              final validChatId = updatedChat.id;
              if (validChatId != null && validChatId.isNotEmpty) {
                // Mark messages as read
                _inboxService.markAsRead(validChatId).catchError((error) {
                  debugPrint('InboxView: Error marking as read: $error');
                });

                // Update unread count
                if (mounted) {
                  setState(() {
                    _unreadCounts[validChatId] = 0;
                  });
                }

                // Force refresh
                ref.invalidate(unreadMessagesProvider);

                final userProfile = _userProfiles[foundOtherUserId];

                if (mounted) {
                  AppNavigator.openChat(
                    context,
                    chat: updatedChat,
                    otherUserId: foundOtherUserId,
                    otherUserName: userProfile?.displayName ??
                        userProfile?.username ??
                        'User',
                    otherUserAvatarUrl: userProfile?.avatarURL,
                    otherUserIsOnline: _onlineStatus[foundOtherUserId] ?? false,
                  );
                }
                _isNavigating = false;
                return;
              }

              // Set otherUserId for fallback to normal flow
              otherUserId = foundOtherUserId;
            } else {
              debugPrint(
                  '⚠️ InboxView: Firestore participants also invalid: $participants');
            }
          } else {
            debugPrint(
                '⚠️ InboxView: Chat document does not exist in Firestore: ${chat.id}');
          }
        } catch (e) {
          debugPrint('❌ InboxView: Error fetching chat from Firestore: $e');
        }
      }

      // If still no other user ID, we can't proceed
      if (otherUserId == null || otherUserId.isEmpty) {
        _isNavigating = false;
        debugPrint('❌ InboxView: Unable to determine other user ID');
        debugPrint('❌ InboxView: Chat ID: ${chat.id}');
        debugPrint('❌ InboxView: Chat participants: ${chat.participants}');
        debugPrint('❌ InboxView: Current user ID: ${currentUser.uid}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Unable to open chat: missing participant information'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Store in non-nullable variable for type safety
      final validOtherUserId = otherUserId;
      debugPrint('✅ InboxView: Opening chat with user: $validOtherUserId');

      // Ensure chat document exists in Firestore BEFORE opening ChatView
      // This is the Instagram/TikTok pattern - create chat proactively
      final chatService = ChatService.shared;

      app_chat.Chat? ensuredChat;
      try {
        ensuredChat = await chatService.fetchOrCreateChat(validOtherUserId);
      } catch (e) {
        _isNavigating = false;
        debugPrint('❌ InboxView: Exception while fetching/creating chat: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error opening chat: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (ensuredChat == null) {
        _isNavigating = false;
        debugPrint(
            '❌ InboxView: fetchOrCreateChat returned null for user: $otherUserId');
        debugPrint('❌ InboxView: Chat participants: ${chat.participants}');
        debugPrint('❌ InboxView: Current user: ${currentUser.uid}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Unable to open chat. The chat may not exist or you may not have permission.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Store in a non-nullable variable for type safety
      final validChat = ensuredChat;

      // Validate validChat has a valid ID
      final validChatId = validChat.id;
      if (validChatId == null || validChatId.isEmpty) {
        _isNavigating = false;
        debugPrint('❌ InboxView: Ensured chat has no ID');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid chat: chat ID is missing'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Mark messages as read when opening chat (non-blocking)
      _inboxService.markAsRead(validChatId).catchError((error) {
        debugPrint('InboxView: Error marking as read: $error');
      });

      // Update unread count
      if (mounted) {
        setState(() {
          _unreadCounts[validChatId] = 0;
        });
      }

      // Force refresh the unread messages provider
      ref.invalidate(unreadMessagesProvider);

      final userProfile = _userProfiles[validOtherUserId];

      if (mounted) {
        AppNavigator.openChat(
          context,
          chat: validChat,
          otherUserId: validOtherUserId,
          otherUserName:
              userProfile?.displayName ?? userProfile?.username ?? 'User',
          otherUserAvatarUrl: userProfile?.avatarURL,
          otherUserIsOnline: _onlineStatus[validOtherUserId] ?? false,
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

    // Prevent multiple simultaneous taps
    if (_isNavigating) return;
    _isNavigating = true;

    try {
      // Validate draft ID
      if (draft.id.isEmpty) {
        _isNavigating = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid draft ID'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Mark the canonical shared draft document as viewed, not a synthetic inbox ID.
      final sharedDraftDocId = await _resolveSharedDraftDocumentId(draft);
      await _inboxService.markSharedDraftViewed(sharedDraftDocId);

      // Get current user to determine if we're the sender or receiver
      final currentUser = _inboxService.auth.currentUser;
      if (currentUser == null) {
        _isNavigating = false;
        return;
      }

      // Determine the other user ID (if we're the sender, use receiverId; if receiver, use senderId)
      final isSender = draft.senderId == currentUser.uid;
      final otherUserId = isSender ? draft.receiverId : draft.senderId;

      if (otherUserId.isEmpty) {
        if (!mounted) return;
        _isNavigating = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open draft feedback'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get or create chat
      final chatService = ChatService.shared;
      final chat = await chatService.fetchOrCreateChat(otherUserId);

      if (chat == null || chat.id == null || chat.id!.isEmpty) {
        if (!mounted) return;
        _isNavigating = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open draft feedback'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get user profile
      final userProfile = _userProfiles[otherUserId];
      final otherUserName = userProfile?.displayName ?? draft.senderName;
      final otherUserAvatarURL = userProfile?.avatarURL ?? draft.senderAvatar;

      // Get shared draft data from Firestore
      final draftSharingService = DraftSharingService();
      final sharedDrafts = await draftSharingService.getSharedDraftsWithMe();
      final sharedDraftsByMe = await draftSharingService.getDraftsSharedByMe();

      // Find the shared draft document that matches this sender/recipient pair.
      final allDrafts = [...sharedDrafts, ...sharedDraftsByMe];
      final foundDraft = allDrafts.firstWhere(
        (d) =>
            d['id'] == draft.id ||
            (d['originalDraftId'] == draft.draftId &&
                d['sharerId'] == draft.senderId &&
                (d['recipients'] as List<dynamic>? ?? const <dynamic>[])
                    .contains(draft.receiverId)),
        orElse: () => <String, dynamic>{},
      );

      Map<String, dynamic> sharedDraftData;
      if (foundDraft.isNotEmpty) {
        sharedDraftData = Map<String, dynamic>.from(foundDraft);
      } else {
        // Fallback: create shared draft data from SharedDraft model
        sharedDraftData = {
          'id': draft.id,
          'originalDraftId': draft.draftId,
          'caption': draft.draftTitle,
          'hashtags': [],
          'sharerId': draft.senderId,
          'recipients': [draft.receiverId],
          'draftThumbnailUrl': draft.draftThumbnailUrl,
        };
      }

      // Prefer canonical Firestore/storage assets. Only enrich from local cache
      // when durable asset fields are missing.
      final hasCanonicalVideo =
          (sharedDraftData['videoUrl'] as String?)?.isNotEmpty == true;
      final hasCanonicalThumbnail =
          (sharedDraftData['thumbnailUrl'] as String?)?.isNotEmpty == true ||
              (sharedDraftData['draftThumbnailUrl'] as String?)?.isNotEmpty ==
                  true;

      if (!hasCanonicalVideo || !hasCanonicalThumbnail) {
        try {
          final localDraftService = LocalDraftService();
          final localDrafts = await localDraftService.getAllDrafts();
          final localDraft = localDrafts.firstWhere(
            (d) => d['id'] == draft.draftId,
            orElse: () => <String, dynamic>{},
          );

          if (localDraft.isNotEmpty) {
            sharedDraftData['videoPath'] = localDraft['videoPath'];
            sharedDraftData['thumbnailPath'] = localDraft['thumbnailPath'];
          }
        } catch (e) {
          debugPrint('⚠️ Could not load local draft data: $e');
        }
      }

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DraftFeedbackView(
              sharedDraft: sharedDraftData,
              chat: chat,
              otherUserId: otherUserId,
              otherUserName: otherUserName,
              otherUserAvatarURL: otherUserAvatarURL,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error opening draft: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening draft: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isNavigating = false;
    }
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
