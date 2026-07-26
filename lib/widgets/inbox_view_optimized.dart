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
import '../utils/user_facing_error.dart';
import '../providers/unread_messages_provider.dart';
import '../providers/main_tab_provider.dart';
import '../routing/app_navigator.dart';
import 'new_message_view.dart';
import 'draft_feedback_view.dart';
import 'screen_feedback_state.dart';
// import 'draft_creation_view.dart'; // Removed - unused

class InboxViewOptimized extends ConsumerStatefulWidget {
  const InboxViewOptimized({super.key});

  @override
  ConsumerState<InboxViewOptimized> createState() => _InboxViewOptimizedState();
}

class _InboxViewOptimizedState extends ConsumerState<InboxViewOptimized>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
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
  static const Color _inboxDarkBackground = Color(0xFF071120);
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
  // Cap concurrent profile doc listeners. Unread comes from the chats stream.
  static const int _maxProfileListeners = 20;
  final Map<String, StreamSubscription<DocumentSnapshot>>
      _userProfileSubscriptions = {};
  Timer? _profileRebuildDebouncer;
  ProviderSubscription<int>? _mainTabVisibilitySubscription;
  bool _inboxListenersActive = false;

  // State
  bool _isLoading = false;
  String? _error;
  String? _actionError;
  bool _isSyncingInbox = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedItems = {};
  ProviderSubscription<int>? _tabBackgroundRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _showSharedDraftsTab ? 2 : 1,
      vsync: this,
    );

    _applyOfflineSnapshot(_offlineService.peekMemory());
    unawaited(_hydrateAndStartInbox());

    _blockingService.blockListRevision.addListener(_handleBlockListChanged);
    _mainTabVisibilitySubscription = ref.listenManual<int>(
      mainTabActiveIndexProvider,
      (int? previous, int next) {
        if (!mounted) {
          return;
        }
        if (isMainTabInboxVisible(next)) {
          if (!_inboxListenersActive) {
            _initializeRealTimeUpdates();
          }
          if (_chats.isEmpty) {
            unawaited(_refreshDataInBackground());
          }
          return;
        }
        _pauseInboxListeners();
      },
    );
    _tabBackgroundRefreshSubscription = ref.listenManual<int>(
      inboxTabBackgroundRefreshProvider,
      (int? previous, int next) {
        if (!mounted) {
          return;
        }
        if (!isMainTabInboxVisible(ref.read(mainTabActiveIndexProvider))) {
          return;
        }
        unawaited(_refreshDataInBackground());
      },
    );
  }

  void _applyOfflineSnapshot(InboxOfflineSnapshot? snapshot) {
    if (snapshot == null || !snapshot.hasChats) {
      return;
    }
    _chats = snapshot.chats;
    _sharedDrafts = snapshot.drafts;
    _filteredChats = snapshot.chats;
    _filteredDrafts = snapshot.drafts;
    _userProfiles
      ..clear()
      ..addAll(snapshot.userProfiles);
    _unreadCounts
      ..clear()
      ..addAll(snapshot.unreadCounts);
    _onlineStatus
      ..clear()
      ..addAll(snapshot.onlineStatus);
    _isLoading = false;
    _error = null;
  }

  Future<void> _hydrateAndStartInbox() async {
    final InboxOfflineSnapshot disk = await _offlineService.loadSnapshot();
    if (!mounted) {
      return;
    }
    if (_chats.isEmpty && disk.hasChats) {
      final List<app_chat.Chat> visible =
          await _filterVisibleChats(disk.chats);
      if (!mounted) {
        return;
      }
      if (visible.isNotEmpty) {
        setState(() {
          _applyOfflineSnapshot(
            InboxOfflineSnapshot(
              chats: visible,
              drafts: disk.drafts,
              userProfiles: disk.userProfiles,
              unreadCounts: disk.unreadCounts,
              onlineStatus: disk.onlineStatus,
            ),
          );
        });
      } else {
        setState(() {
          _isLoading = true;
        });
      }
    } else if (_chats.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }

    if (isMainTabInboxVisible(ref.read(mainTabActiveIndexProvider))) {
      _initializeRealTimeUpdates();
    } else {
      unawaited(_prefetchInboxInBackground());
    }
  }

  Future<void> _prefetchInboxInBackground() async {
    if (_isSyncingInbox) {
      return;
    }
    try {
      await _refreshDataInBackground();
    } catch (e) {
      LoggingService.instance.error('Inbox prefetch failed: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _profileRebuildDebouncer?.cancel();
    _pauseInboxListeners();
    _blockingService.blockListRevision.removeListener(_handleBlockListChanged);
    _mainTabVisibilitySubscription?.close();
    _tabBackgroundRefreshSubscription?.close();
    super.dispose();
  }

  void _pauseInboxListeners() {
    _inboxService.stopRealTimeListeners();
    _inboxListenersActive = false;
    _profileRebuildDebouncer?.cancel();
    for (final StreamSubscription<DocumentSnapshot> subscription
        in _userProfileSubscriptions.values) {
      subscription.cancel();
    }
    _userProfileSubscriptions.clear();
  }

  void _syncUnreadFromChatStream(List<app_chat.Chat> chats) {
    final Map<String, int> cached = _inboxService.snapshotUnreadCounts();
    for (final app_chat.Chat chat in chats) {
      final String chatId = chat.id ?? '';
      if (chatId.isEmpty) {
        continue;
      }
      if (cached.containsKey(chatId)) {
        _unreadCounts[chatId] = cached[chatId]!;
      }
    }
  }

  void _initializeRealTimeUpdates() async {
    if (_inboxListenersActive) {
      return;
    }
    _inboxListenersActive = true;
    if (_chats.isEmpty && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    // Start real-time listeners
    _inboxService.startRealTimeListeners(
      onChatsUpdate: (chats) async {
        // Filter out invalid chats (with empty participant IDs)
        final validChats = await _filterVisibleChats(chats);

        _syncUnreadFromChatStream(validChats);
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

  void _scheduleProfileRebuild() {
    _profileRebuildDebouncer?.cancel();
    _profileRebuildDebouncer = Timer(const Duration(milliseconds: 120), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _setupUserProfileListeners(List<app_chat.Chat> chats) {
    final currentUser = _inboxService.auth.currentUser;
    if (currentUser == null) return;

    final List<String> orderedUserIds = <String>[];
    final Set<String> seen = <String>{};
    for (final app_chat.Chat chat in chats) {
      for (final String id in chat.participants) {
        if (id.isEmpty || id == currentUser.uid || seen.contains(id)) {
          continue;
        }
        seen.add(id);
        orderedUserIds.add(id);
        if (orderedUserIds.length >= _maxProfileListeners) {
          break;
        }
      }
      if (orderedUserIds.length >= _maxProfileListeners) {
        break;
      }
    }
    final Set<String> nextUserIds = orderedUserIds.toSet();
    final subscriptionsToCancel = _userProfileSubscriptions.keys
        .where((id) => !nextUserIds.contains(id))
        .toList();
    for (final userId in subscriptionsToCancel) {
      _userProfileSubscriptions[userId]?.cancel();
      _userProfileSubscriptions.remove(userId);
    }

    for (final String otherUserId in orderedUserIds) {
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

          _userProfiles[otherUserId] = updatedUser;
          _scheduleProfileRebuild();
        }
      });
      _userProfileSubscriptions[otherUserId] = subscription;
    }
  }

  Future<void> _loadData() async {
    final bool showLoading = _chats.isEmpty;
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

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

      // Sync unread from chat stream cache; cap profile listeners.
      _syncUnreadFromChatStream(validChats);
      _setupUserProfileListeners(validChats);
      await _loadUserDataForChats(validChats);
      await _offlineService.cacheChats(validChats);
      await _offlineService.cacheDrafts(drafts);

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
        _error = UserFacingError.message(e);
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

    _syncUnreadFromChatStream(chats);

    final futures = <Future>[];
    for (final chat in chats) {
      final validParticipants = chat.participants
          .where((id) => id.isNotEmpty && id != currentUser.uid)
          .toList();
      if (validParticipants.isEmpty) continue;
      final otherUserId = validParticipants.first;
      futures.add(_inboxService.getUserProfile(otherUserId).then((user) {
        if (user != null) {
          _userProfiles[otherUserId] = user;
        }
      }));
      futures.add(_inboxService.isUserOnline(otherUserId).then((isOnline) {
        _onlineStatus[otherUserId] = isOnline;
      }));
    }

    await Future.wait(futures);
    await _offlineService.cacheUserProfiles(_userProfiles);
    await _offlineService.cacheUnreadCounts(_unreadCounts);
    await _offlineService.cacheOnlineStatus(_onlineStatus);
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  /// Silent sync when returning to Inbox; keeps cached UI unless first load.
  Future<void> _refreshDataInBackground() async {
    if (_isSyncingInbox) {
      return;
    }
    _isSyncingInbox = true;
    final bool isFirstLoad = _chats.isEmpty;
    if (isFirstLoad && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final List<Object> results = await Future.wait(<Future<Object>>[
        _inboxService.getChats(),
        _inboxService.getSharedDrafts(),
      ]);
      final List<app_chat.Chat> allChats =
          results[0] as List<app_chat.Chat>;
      final List<SharedDraft> drafts = results[1] as List<SharedDraft>;
      final List<app_chat.Chat> validChats =
          await _filterVisibleChats(allChats);
      _syncUnreadFromChatStream(validChats);
      if (isMainTabInboxVisible(ref.read(mainTabActiveIndexProvider))) {
        _setupUserProfileListeners(validChats);
      }
      await _loadUserDataForChats(validChats);
      await _offlineService.cacheChats(validChats);
      await _offlineService.cacheDrafts(drafts);
      if (!mounted) {
        return;
      }
      setState(() {
        _chats = validChats;
        _sharedDrafts = drafts;
        _filteredChats = validChats;
        _filteredDrafts = drafts;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      LoggingService.instance.error('Error background inbox refresh: $e');
      if (!mounted) {
        return;
      }
      if (isFirstLoad) {
        setState(() {
          _error = UserFacingError.message(e);
          _isLoading = false;
        });
      }
    } finally {
      _isSyncingInbox = false;
    }
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
    super.build(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark
          ? _inboxDarkBackground
          : Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1.08),
            radius: 1.15,
            colors: dark
                ? <Color>[
                    _primaryColor.withValues(alpha: 0.12),
                    _inboxDarkBackground,
                  ]
                : <Color>[
                    _primaryColor.withValues(alpha: 0.08),
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
          ),
        ),
        child: KeyedSubtree(
          child: SafeArea(
            child: Column(
              children: <Widget>[
                _buildHeader(),
                if (_actionError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: ScreenInlineErrorBanner(
                      message: _actionError!,
                      onDismiss: () {
                        if (mounted) {
                          setState(() => _actionError = null);
                        }
                      },
                    ),
                  ),
                _buildSearchBar(),
                _buildTabBar(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
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
                    child: _isLoading && _chats.isEmpty
                        ? _buildLoadingState()
                        : _error != null && _chats.isEmpty
                            ? _buildErrorState()
                            : _buildTabContent(),
                  ),
                ),
              ],
            ),
          ),
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
        responsive.spacing(8),
        responsive.spacing(20),
        responsive.spacing(8),
      ),
      padding: EdgeInsets.fromLTRB(
        responsive.spacing(8),
        responsive.spacing(8),
        responsive.spacing(8),
        responsive.spacing(8),
      ),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(responsive.radius(18)),
        border: Border.all(
          color: on.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Messages',
                      style: TextStyle(
                        color: on,
                        fontSize: responsive.font(25),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      '${_chats.length} ${_chats.length == 1 ? 'Conversation' : 'Conversations'}',
                      style: TextStyle(
                        color: on.withValues(alpha: 0.6),
                        fontSize: responsive.font(13),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Filter messages',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _toggleSelectionMode();
                },
                icon: Icon(
                  _isSelectionMode ? Icons.close : Icons.tune_rounded,
                  color: _isSelectionMode ? _primaryColor : on,
                  size: 21,
                ),
                padding: const EdgeInsets.all(8),
              ),
              IconButton(
                tooltip: 'New message',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _createNewMessage();
                },
                icon: Icon(
                  Icons.edit_square,
                  color: on,
                  size: 21,
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
        responsive.spacing(8),
      ),
      decoration: BoxDecoration(
        color: _th.surface.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(responsive.radius(14)),
        border: Border.all(
          color: _on.withValues(alpha: 0.10),
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
            color: _on.withValues(alpha: 0.5),
            fontSize: responsive.font(14),
            fontWeight: FontWeight.w400,
          ),
          filled: false,
          border: InputBorder.none,
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.search_rounded,
              color: _on.withValues(alpha: 0.6),
              size: responsive.icon(18),
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
            vertical: responsive.spacing(11),
          ),
        ),
        style: TextStyle(
          color: _on,
          fontSize: responsive.font(14),
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final responsive = context.responsive;

    final List<_InboxSegment> segments = <_InboxSegment>[
      _InboxSegment(label: 'Chats', count: _chats.length, enabled: true),
      const _InboxSegment(label: 'Requests', count: 0, enabled: false),
      const _InboxSegment(label: 'Groups', count: 0, enabled: false),
    ];
    return Container(
      margin: EdgeInsets.fromLTRB(
        responsive.spacing(20),
        0,
        responsive.spacing(20),
        responsive.spacing(10),
      ),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _th.surface.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(responsive.radius(14)),
        border: Border.all(
          color: _on.withValues(alpha: 0.10),
          width: 1,
        ),
      ),
      child: Row(
        children: segments.map((_InboxSegment segment) {
          final bool selected = segment.label == 'Chats';
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? _primaryColor.withValues(alpha: 0.22)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(responsive.radius(11)),
                border: selected
                    ? Border.all(color: _primaryColor.withValues(alpha: 0.28))
                    : null,
              ),
              child: Text(
                segment.count > 0
                    ? '${segment.label} ${segment.count}'
                    : segment.label,
                style: TextStyle(
                  color: selected
                      ? _on
                      : _on.withValues(alpha: segment.enabled ? 0.62 : 0.38),
                  fontSize: responsive.font(13),
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }).toList(growable: false),
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
    final String chatId = chat.id ?? '';

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
    final unreadCount = _unreadCounts[chatId] ?? 0;
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

    final Widget tile = Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? _primaryColor.withValues(alpha: 0.12)
            : hasUnread
                ? _on.withValues(alpha: 0.045)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _isSelectionMode
              ? () => _toggleSelection(chat.id ?? '')
              : () => _openChat(chat),
          onLongPress: () {
            HapticFeedback.lightImpact();
            _toggleSelectionMode();
            _toggleSelection(chat.id ?? '');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                // Avatar with selection indicator and online status
                Stack(
                  children: [
                    StatusAwareAvatar(
                      userId: otherUserId,
                      avatarURL: userProfile?.avatarURL,
                      radius: 20,
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
                const SizedBox(width: 12),
                // Chat content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              participantName,
                              style: TextStyle(
                                color: _on,
                                fontSize: 15.5,
                                fontWeight: hasUnread
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                letterSpacing: -0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _formatTime(chat.lastTimestamp),
                            style: TextStyle(
                              color: _on.withValues(alpha: 0.48),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (hasUnread) ...<Widget>[
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: _primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              (chat.lastMessage ?? secondaryLabel)
                                      .trim()
                                      .isEmpty
                                  ? secondaryLabel
                                  : (chat.lastMessage ?? secondaryLabel),
                              style: TextStyle(
                                color: _on.withValues(
                                  alpha: hasUnread ? 0.82 : 0.56,
                                ),
                                fontSize: 13,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
              ],
            ),
          ),
        ),
      ),
    );
    if (_isSelectionMode || chatId.isEmpty) {
      return tile;
    }
    return Dismissible(
      key: ValueKey<String>('chat-swipe-$chatId'),
      confirmDismiss: (DismissDirection direction) async {
        if (direction == DismissDirection.endToStart) {
          await _showChatQuickActions(chat);
        } else {
          await _showChatPriorityActions(chat);
        }
        return false;
      },
      background: _SwipeActionBackground(
        alignment: Alignment.centerLeft,
        color: _primaryColor.withValues(alpha: 0.18),
        icon: Icons.push_pin_outlined,
        label: 'Pin / Unread',
      ),
      secondaryBackground: _SwipeActionBackground(
        alignment: Alignment.centerRight,
        color: Colors.redAccent.withValues(alpha: 0.16),
        icon: Icons.archive_outlined,
        label: 'Archive / Delete',
      ),
      child: tile,
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
              'Loading messages...',
              style: TextStyle(
                color: _on,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return ScreenErrorState(
      key: const ValueKey('error-state'),
      title: 'We couldn’t load your inbox',
      message: _error ?? 'Something went wrong. Please try again.',
      onRetry: _loadData,
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

  Future<void> _showChatQuickActions(app_chat.Chat chat) async {
    final String chatId = chat.id ?? '';
    final String? userId = _inboxService.auth.currentUser?.uid;
    if (chatId.isEmpty || userId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final ColorScheme c = Theme.of(context).colorScheme;
        return _InboxActionSheet(
          title: 'Conversation actions',
          actions: <_InboxSheetAction>[
            _InboxSheetAction(
              icon: Icons.archive_outlined,
              label: 'Archive',
              onTap: () async {
                Navigator.of(context).pop();
                await ChatService.shared.archiveChat(chatId, userId);
                if (!mounted) return;
                setState(() {
                  _chats.removeWhere((app_chat.Chat c) => c.id == chatId);
                  _filteredChats
                      .removeWhere((app_chat.Chat c) => c.id == chatId);
                });
                _showSnackBar('Conversation archived', _primaryColor);
              },
            ),
            _InboxSheetAction(
              icon: Icons.notifications_off_outlined,
              label: chat.mutedBy.contains(userId) ? 'Unmute' : 'Mute',
              onTap: () async {
                Navigator.of(context).pop();
                if (chat.mutedBy.contains(userId)) {
                  await ChatService.shared.unmuteChat(chatId, userId);
                } else {
                  await ChatService.shared.muteChat(chatId, userId);
                }
                await _refreshData();
              },
            ),
            _InboxSheetAction(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: Colors.redAccent,
              onTap: () async {
                Navigator.of(context).pop();
                final bool confirmed = await _confirmSingleDelete();
                if (!confirmed) return;
                await _inboxService.deleteChat(chatId);
                await _refreshData();
              },
            ),
          ],
          surface: c.surface,
          border: c.outline.withValues(alpha: 0.22),
        );
      },
    );
  }

  Future<void> _showChatPriorityActions(app_chat.Chat chat) async {
    final String chatId = chat.id ?? '';
    final String? userId = _inboxService.auth.currentUser?.uid;
    if (chatId.isEmpty || userId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final ColorScheme c = Theme.of(context).colorScheme;
        return _InboxActionSheet(
          title: 'Priority actions',
          actions: <_InboxSheetAction>[
            _InboxSheetAction(
              icon: Icons.mark_email_unread_outlined,
              label: 'Mark unread',
              onTap: () async {
                Navigator.of(context).pop();
                await FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId)
                    .set(<String, Object?>{
                  'unreadCount_$userId': 1,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                if (!mounted) return;
                setState(() => _unreadCounts[chatId] = 1);
                ref.invalidate(unreadMessagesProvider);
              },
            ),
            _InboxSheetAction(
              icon: Icons.push_pin_outlined,
              label: 'Pin',
              onTap: () async {
                Navigator.of(context).pop();
                await FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId)
                    .set(<String, Object?>{
                  'pinnedBy': FieldValue.arrayUnion(<String>[userId]),
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                _showSnackBar('Conversation pinned', _primaryColor);
              },
            ),
          ],
          surface: c.surface,
          border: c.outline.withValues(alpha: 0.22),
        );
      },
    );
  }

  Future<bool> _confirmSingleDelete() async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            final ColorScheme c = Theme.of(context).colorScheme;
            return AlertDialog(
              backgroundColor: c.surface,
              title: Text('Delete conversation',
                  style: TextStyle(color: c.onSurface)),
              content: Text(
                'Delete this conversation from your inbox?',
                style: TextStyle(color: c.onSurface.withValues(alpha: 0.7)),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;
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

  // Failures stay on-screen; successes remain ephemeral.
  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) {
      return;
    }
    final bool isError = backgroundColor == Colors.red;
    if (isError) {
      setState(() => _actionError = message);
      return;
    }
    if (_actionError != null) {
      setState(() => _actionError = null);
    }
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

class _InboxSegment {
  const _InboxSegment({
    required this.label,
    required this.count,
    required this.enabled,
  });

  final String label;
  final int count;
  final bool enabled;
}

class _SwipeActionBackground extends StatelessWidget {
  const _SwipeActionBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme c = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.outline.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: c.onSurface.withValues(alpha: 0.78), size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: c.onSurface.withValues(alpha: 0.78),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxSheetAction {
  const _InboxSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final FutureOr<void> Function() onTap;
  final Color? color;
}

class _InboxActionSheet extends StatelessWidget {
  const _InboxActionSheet({
    required this.title,
    required this.actions,
    required this.surface,
    required this.border,
  });

  final String title;
  final List<_InboxSheetAction> actions;
  final Color surface;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final ColorScheme c = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
              child: Text(
                title,
                style: TextStyle(
                  color: c.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ...actions.map((_InboxSheetAction action) {
              final Color fg = action.color ?? c.onSurface;
              return ListTile(
                dense: true,
                leading: Icon(action.icon, color: fg),
                title: Text(
                  action.label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onTap: () => action.onTap(),
              );
            }),
          ],
        ),
      ),
    );
  }
}
