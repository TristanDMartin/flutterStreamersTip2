import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../models/creator_profile_snapshot.dart';
import '../models/home_video.dart';
import '../models/user_model.dart' as user_model;
import '../models/network_models.dart' as network_models;
import '../models/user_count_fields.dart';
import '../models/user_status.dart';
import '../utils/post_count_rules.dart';
import '../services/follows_service.dart';
import '../services/migration_service.dart';
import '../services/performance_monitoring_service.dart';
import '../services/user_blocking_service.dart';
import '../widgets/status_aware_avatar.dart';
import '../providers/status_provider.dart';
import '../routing/app_navigator.dart';
import '../routing/app_routes.dart';
import '../widgets/share_profile_view.dart';
import '../providers/follow_refresh_provider.dart';
import '../providers/main_tab_provider.dart';
import '../providers/video_service_provider.dart' as video_providers;
import '../constants/app_colors.dart';
import '../models/creator_activity.dart';
import '../services/creator_activity_service.dart';
import '../widgets/creator_activity_badge.dart';

class NetworkView extends ConsumerStatefulWidget {
  final String? initialTab;

  const NetworkView({super.key, this.initialTab});

  @override
  ConsumerState<NetworkView> createState() => _NetworkViewState();
}

class _NetworkViewState extends ConsumerState<NetworkView>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  ColorScheme get _th => Theme.of(context).colorScheme;
  network_models.NetworkTab _selectedTab =
      network_models.NetworkTab.connections;
  final ScrollController _listController = ScrollController();
  late final AnimationController _contentTransitionController;
  late final Animation<double> _contentFadeAnimation;
  late final Animation<Offset> _contentSlideAnimation;
  static const int _pageSize = 20;
  int _connectionsPage = 1;
  int _followersPage = 1;
  int _followingPage = 1;

  // Search functionality
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<user_model.User> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchTimer;

  // Sort options
  String _sortBy = 'name';
  bool _sortAscending = true;

  // FollowsService data
  List<user_model.User> _connectionsUsers = [];
  List<user_model.User> _followersUsers = [];
  List<user_model.User> _followingUsers = [];
  bool _isLoadingUsers = false;

  void _resetPagination() {
    _connectionsPage = 1;
    _followersPage = 1;
    _followingPage = 1;
  }

  void _maybeLoadMore() {
    if (!_listController.hasClients) return;
    final position = _listController.position;
    if (!position.hasPixels || !position.hasContentDimensions) return;
    final threshold = position.maxScrollExtent * 0.85;
    if (position.pixels >= threshold) {
      final List<user_model.User> fullList = _fullListForSelectedTab();
      final List<user_model.User> displayed = _currentList();
      if (displayed.length >= fullList.length && _hasMoreFollowGraph) {
        unawaited(_loadMoreFollowGraph());
        return;
      }
      setState(() {
        switch (_selectedTab) {
          case network_models.NetworkTab.connections:
            _connectionsPage++;
            break;
          case network_models.NetworkTab.followers:
            _followersPage++;
            break;
          case network_models.NetworkTab.following:
            _followingPage++;
            break;
        }
      });
    }
  }

  List<user_model.User> _fullListForSelectedTab() {
    switch (_selectedTab) {
      case network_models.NetworkTab.connections:
        return _connectionsUsers;
      case network_models.NetworkTab.followers:
        return _followersUsers;
      case network_models.NetworkTab.following:
        return _followingUsers;
    }
  }

  Future<void> _loadMoreFollowGraph() async {
    if (_isLoadingMoreFollowGraph || !_hasMoreFollowGraph) {
      return;
    }
    _isLoadingMoreFollowGraph = true;
    try {
      final NetworkTabUsers bundle =
          await FollowsService().loadMoreNetworkTabUsers();
      if (!mounted) {
        return;
      }
      setState(() {
        _connectionsUsers = bundle.connections;
        _followersUsers = bundle.followers;
        _followingUsers = bundle.following;
        _hasMoreFollowGraph = bundle.hasMoreFollowGraph;
      });
    } finally {
      _isLoadingMoreFollowGraph = false;
    }
  }

  // Network connectivity (kept for network error handling)
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Real-time relationship listeners
  StreamSubscription<QuerySnapshot>? _followersSubscription;
  StreamSubscription<QuerySnapshot>? _followingSubscription;
  StreamSubscription<QuerySnapshot>? _scopedFollowsSubscription1;
  StreamSubscription<QuerySnapshot>? _scopedFollowsSubscription2;
  bool _listenersInitialized = false;
  bool _listenersPaused = false;
  bool _isRefreshingNetworkData = false;
  bool _isLoadingMoreFollowGraph = false;
  bool _hasMoreFollowGraph = false;
  bool _hasInitialNetworkLoad = false;
  Timer? _followsDebounceTimer;
  ProviderSubscription<int>? _tabBackgroundRefreshSubscription;
  ProviderSubscription<int>? _mainTabVisibilitySubscription;

  // Error state
  bool _hasShownPermissionError = false;
  DateTime? _lastFollowListenerErrorSnackAt;
  String? _networkErrorMessage;
  final Set<String> _swipeHapticShown = <String>{};

  bool get _isFirebaseReady => Firebase.apps.isNotEmpty;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _contentTransitionController = AnimationController(
      duration: const Duration(milliseconds: 260),
      vsync: this,
    );
    _contentFadeAnimation = CurvedAnimation(
      parent: _contentTransitionController,
      curve: Curves.easeOutCubic,
    );
    _contentSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.025), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _contentTransitionController,
        curve: Curves.easeOutCubic,
      ),
    );
    _contentTransitionController.value = 1;

    _listController.addListener(_maybeLoadMore);

    // Set initial tab if provided
    if (widget.initialTab != null) {
      _selectedTab = _getTabFromString(widget.initialTab!);
      if (kDebugMode) {
        debugPrint(
          "🔵 NetworkView: Initialized with tab: ${widget.initialTab} -> ${_selectedTab.name}",
        );
      }
    }

    // ❌ REMOVED: Global error handler override - now handled at app level

    // Initialize network connectivity monitoring
    _initializeConnectivityMonitoring();

    PerformanceMonitoringService().startMonitoring();

    if (_isFirebaseReady) {
      if (isMainTabNetworkVisible(ref.read(mainTabActiveIndexProvider))) {
        unawaited(_bootstrapNetworkData());
      } else {
        _listenersPaused = true;
      }
    }

    _tabBackgroundRefreshSubscription = ref.listenManual<int>(
      networkTabBackgroundRefreshProvider,
      (int? previous, int next) {
        if (!mounted) {
          return;
        }
        if (!isMainTabNetworkVisible(ref.read(mainTabActiveIndexProvider))) {
          return;
        }
        unawaited(_refreshDataInstantly());
      },
    );
    _mainTabVisibilitySubscription = ref.listenManual<int>(
      mainTabActiveIndexProvider,
      (int? previous, int next) {
        if (!mounted) {
          return;
        }
        if (isMainTabNetworkVisible(next)) {
          _resumeRelationshipListenersIfNeeded();
        } else {
          _pauseRelationshipListeners();
        }
      },
    );
  }

  Future<void> _bootstrapNetworkData() async {
    if (mounted) {
      setState(() {
        _isLoadingUsers = true;
      });
    }
    await _runMigrationIfNeeded();
    _initializeRelationshipListeners();
    await _loadUsersFromFollowsService();
  }

  bool get _isNetworkCompletelyEmpty =>
      _connectionsUsers.isEmpty &&
      _followersUsers.isEmpty &&
      _followingUsers.isEmpty;

  void _logDriftIfAny({
    required int actualFollowersCount,
    required int actualFollowingCount,
    int? followersCountDoc,
    int? followingCountDoc,
  }) {
    if (followersCountDoc != null &&
        followersCountDoc != actualFollowersCount) {
      debugPrint(
        '⚠️ NetworkView: Drift detected - followers doc $followersCountDoc '
        'vs follows collection $actualFollowersCount',
      );
    }
    if (followingCountDoc != null &&
        followingCountDoc != actualFollowingCount) {
      debugPrint(
        '⚠️ NetworkView: Drift detected - following doc $followingCountDoc '
        'vs follows collection $actualFollowingCount',
      );
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _followersSubscription?.cancel();
    _followingSubscription?.cancel();
    _scopedFollowsSubscription1?.cancel();
    _scopedFollowsSubscription2?.cancel();

    // Stop performance monitoring
    PerformanceMonitoringService().stopMonitoring();

    // Dispose controllers
    _listController.removeListener(_maybeLoadMore);
    _listController.dispose();
    _searchController.dispose();
    _contentTransitionController.dispose();
    // Dispose timers
    _searchTimer?.cancel();
    _followsDebounceTimer?.cancel();
    _tabBackgroundRefreshSubscription?.close();
    _mainTabVisibilitySubscription?.close();

    super.dispose();
  }

  /// Initialize network connectivity monitoring
  void _initializeConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final hasConnection = results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);

      // Connection status is now handled by the status provider

      if (!hasConnection && mounted) {
        _showNetworkError();
      }
    });
  }

  void _pauseRelationshipListeners() {
    if (_listenersPaused) {
      return;
    }
    _listenersPaused = true;
    _followsDebounceTimer?.cancel();
    _scopedFollowsSubscription1?.cancel();
    _scopedFollowsSubscription2?.cancel();
    _scopedFollowsSubscription1 = null;
    _scopedFollowsSubscription2 = null;
    _listenersInitialized = false;
    PerformanceMonitoringService().stopMonitoring();
  }

  void _resumeRelationshipListenersIfNeeded() {
    if (!_listenersPaused || _listenersInitialized || !_isFirebaseReady) {
      return;
    }
    if (!isMainTabNetworkVisible(ref.read(mainTabActiveIndexProvider))) {
      return;
    }
    _listenersPaused = false;
    PerformanceMonitoringService().startMonitoring();
    _initializeRelationshipListeners();
    if (!_hasInitialNetworkLoad) {
      unawaited(_refreshDataInstantly(forceRefresh: true));
    }
  }

  /// Initialize real-time relationship listeners for instant updates (OPTIMIZED)
  void _initializeRelationshipListeners() {
    if (_listenersInitialized || _listenersPaused) {
      return;
    }
    if (!isMainTabNetworkVisible(ref.read(mainTabActiveIndexProvider))) {
      _listenersPaused = true;
      return;
    }
    _listenersInitialized = true;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      debugPrint(
        '❌ NetworkView: No current user ID, cannot initialize listeners',
      );
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
        });
      }
      return;
    }

    debugPrint(
      '🔄 NetworkView: Initializing real-time listeners for user: $currentUserId',
    );

    void onFollowsUpdate(QuerySnapshot _) {
      if (!isMainTabNetworkVisible(ref.read(mainTabActiveIndexProvider))) {
        return;
      }
      FollowsService().invalidateFollowIdSetsCache();
      if (!_hasInitialNetworkLoad) {
        _hasInitialNetworkLoad = true;
        unawaited(_refreshDataInstantly(forceRefresh: true));
        return;
      }
      _followsDebounceTimer?.cancel();
      _followsDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (!mounted ||
            !isMainTabNetworkVisible(ref.read(mainTabActiveIndexProvider))) {
          return;
        }
        unawaited(_refreshDataInstantly(forceRefresh: true));
      });
    }

    void onError(Object error) {
      if (kDebugMode) {
        debugPrint('❌ NetworkView: Error in scoped follows listener: $error');
      }
      if (!mounted) return;
      final bool isPermissionDenied = error.toString().toLowerCase().contains(
            'permission',
          );
      if (isPermissionDenied) {
        if (_hasShownPermissionError) return;
        _hasShownPermissionError = true;
      } else {
        final DateTime now = DateTime.now();
        if (_lastFollowListenerErrorSnackAt != null &&
            now.difference(_lastFollowListenerErrorSnackAt!) <
                const Duration(seconds: 4)) {
          return;
        }
        _lastFollowListenerErrorSnackAt = now;
      }
      setState(() {
        _networkErrorMessage = isPermissionDenied
            ? 'Cannot load network: missing permissions.'
            : 'Network updates failed. Check connection.';
      });
    }

    _scopedFollowsSubscription1 = FirebaseFirestore.instance
        .collection('follows')
        .where('followerUserId', isEqualTo: currentUserId)
        .snapshots()
        .listen(onFollowsUpdate, onError: onError);

    _scopedFollowsSubscription2 = FirebaseFirestore.instance
        .collection('follows')
        .where('targetUserId', isEqualTo: currentUserId)
        .snapshots()
        .listen(onFollowsUpdate, onError: onError);

    debugPrint('✅ NetworkView: Real-time listeners initialized (scoped)');
  }

  /// Check network connectivity before API calls
  Future<bool> _checkNetworkConnectivity() async {
    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      final hasConnection =
          connectivityResults.contains(ConnectivityResult.mobile) ||
              connectivityResults.contains(ConnectivityResult.wifi) ||
              connectivityResults.contains(ConnectivityResult.ethernet);

      // Connection status is now handled by the status provider

      return hasConnection;
    } catch (e) {
      debugPrint('Connectivity check error: $e');
      return false;
    }
  }

  /// Show network error message
  void _showNetworkError() {
    if (!mounted) return;
    setState(() {
      _networkErrorMessage =
          'No internet connection. Please check your network.';
    });
  }

  /// Load users from clean relationship service
  Future<void> _loadUsersFromFollowsService() async {
    if (!_isFirebaseReady) {
      if (mounted) {
        setState(() {
          _connectionsUsers = [];
          _followersUsers = [];
          _followingUsers = [];
          _isLoadingUsers = false;
        });
      }
      return;
    }

    // Check network connectivity first
    final hasConnection = await _checkNetworkConnectivity();
    if (!hasConnection) {
      _showNetworkError();
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
        });
      }
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingUsers = true;
    });

    try {
      debugPrint(
        '🔄 NetworkView: Starting to load users from FollowsService...',
      );

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      // Check if migration is needed and run it
      await _runMigrationIfNeeded();
      if (!mounted) {
        return;
      }

      final followsSvc = FollowsService();
      final NetworkTabUsers bundle =
          await followsSvc.loadNetworkTabUsers();
      if (!mounted) {
        return;
      }

      debugPrint(
        '📊 NetworkView: Raw results - Connections: ${bundle.connections.length}, '
        'Followers: ${bundle.followers.length}, Following: ${bundle.following.length}',
      );

      int? followersCountDoc;
      int? followingCountDoc;
      if (currentUserId != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .get();
          final data = userDoc.data();
          if (data != null) {
            followersCountDoc = UserCountFields.readFollowersCount(data);
            followingCountDoc = UserCountFields.readFollowingCount(data);
          }
        } catch (e) {
          debugPrint('⚠️ NetworkView: Unable to read doc counters: $e');
        }
      }
      if (!mounted) {
        return;
      }

      _resetPagination();

      setState(() {
        _connectionsUsers = bundle.connections;
        _followersUsers = bundle.followers;
        _followingUsers = bundle.following;
        _isLoadingUsers = false;
        _networkErrorMessage = null;
        _hasMoreFollowGraph = bundle.hasMoreFollowGraph;
      });

      _logDriftIfAny(
        actualFollowersCount: bundle.counts.followersCount,
        actualFollowingCount: bundle.counts.followingCount,
        followersCountDoc: followersCountDoc,
        followingCountDoc: followingCountDoc,
      );
      if (currentUserId != null &&
          ((followersCountDoc != null &&
                  followersCountDoc != bundle.counts.followersCount) ||
              (followingCountDoc != null &&
                  followingCountDoc != bundle.counts.followingCount))) {
        unawaited(followsSvc.repairFollowCountersForUser(currentUserId));
      }

      debugPrint(
        '🎯 NetworkView: Final state - Connections: ${_connectionsUsers.length}, Followers: ${_followersUsers.length}, Following: ${_followingUsers.length}',
      );

      // Debug: Print user details with clear section headers
      debugPrint('🔗 CONNECTIONS (Mutual Follows):');
      for (int i = 0; i < _connectionsUsers.length; i++) {
        debugPrint(
          '  $i: ${_connectionsUsers[i].displayName} (${_connectionsUsers[i].id})',
        );
      }

      debugPrint('👥 FOLLOWERS (They follow you):');
      for (int i = 0; i < _followersUsers.length; i++) {
        debugPrint(
          '  $i: ${_followersUsers[i].displayName} (${_followersUsers[i].id})',
        );
      }

      debugPrint('➡️ FOLLOWING (You follow them):');
      for (int i = 0; i < _followingUsers.length; i++) {
        debugPrint(
          '  $i: ${_followingUsers[i].displayName} (${_followingUsers[i].id})',
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading users from follows service: $e');
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
        });
      }

      // Show user-friendly error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Failed to load network data. Please try again.',
            ),
            backgroundColor: Colors.red.withValues(alpha: 0.8),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadUsersFromFollowsService,
            ),
          ),
        );
      }
    }
  }

  /// Run migration if needed (check if follows collection is empty)
  Future<void> _runMigrationIfNeeded() async {
    try {
      // Check if follows collection has any data
      final followsSnapshot =
          await FirebaseFirestore.instance.collection('follows').limit(1).get();

      if (followsSnapshot.docs.isEmpty) {
        debugPrint(
          '🔄 NetworkView: No follows data found, running migration...',
        );
        final migrationSuccess = await MigrationService.runCompleteMigration();
        if (migrationSuccess) {
          debugPrint('✅ NetworkView: Migration completed successfully');
        } else {
          debugPrint(
            '❌ NetworkView: Migration failed, continuing with empty data',
          );
        }
      } else {
        debugPrint(
          '✅ NetworkView: Follows data already exists, skipping migration',
        );
      }
    } catch (e) {
      debugPrint('❌ NetworkView: Error checking migration status: $e');
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });

    // Cancel previous search timer
    _searchTimer?.cancel();

    // Start new search with debouncing
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    if (_searchQuery.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSearching = true;
      });
    }

    try {
      final allUsers = _getAllUsersForSearch();
      final results = allUsers.where((user) {
        return user.username.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
            user.displayName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();

      // Check if widget is still mounted before updating state
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  List<user_model.User> _getAllUsersForSearch() {
    final allUsers = <user_model.User>[];
    allUsers.addAll(_connectionsUsers);
    allUsers.addAll(_followersUsers);
    allUsers.addAll(_followingUsers);

    final uniqueUsers = <String, user_model.User>{};
    for (final user in allUsers) {
      uniqueUsers[user.id] = user;
    }

    return uniqueUsers.values.toList();
  }

  void _toggleSearch() {
    HapticFeedback.lightImpact();

    // Cancel any ongoing search
    _searchTimer?.cancel();

    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchController.clear();
        _searchQuery = '';
        _searchResults = [];
        _isSearching = false;
      }
    });
  }

  void _showSortOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSortOption('Name', 'name', Icons.sort_by_alpha),
            _buildSortOption('Followers', 'followers', Icons.people),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String title, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: _sortBy == value
          ? Icon(Icons.check, color: Theme.of(context).primaryColor)
          : null,
      onTap: () {
        setState(() {
          _sortBy = value;
          _sortAscending = true;
        });
        Navigator.pop(context);
      },
    );
  }

  List<user_model.User> _currentList() {
    if (_isSearchVisible && _searchQuery.isNotEmpty) {
      return _sortUsers(_searchResults);
    }

    List<user_model.User> users = [];
    int page = 1;
    switch (_selectedTab) {
      case network_models.NetworkTab.connections:
        users = _connectionsUsers;
        page = _connectionsPage;
        break;
      case network_models.NetworkTab.followers:
        users = _followersUsers;
        page = _followersPage;
        break;
      case network_models.NetworkTab.following:
        users = _followingUsers;
        page = _followingPage;
        break;
    }

    final sorted = _sortUsers([...users]);
    final end = (page * _pageSize).clamp(0, sorted.length);
    return sorted.take(end).toList();
  }

  List<user_model.User> _sortUsers(List<user_model.User> users) {
    users.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison = a.displayName.compareTo(b.displayName);
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    return users;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    ref.listen<int>(followRefreshProvider, (previous, next) {
      if (previous == next || !mounted) return;
      if (!isMainTabNetworkVisible(ref.read(mainTabActiveIndexProvider))) {
        return;
      }
      _refreshDataInstantly();
    });

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) {
          debugPrint(
            '🔄 NetworkView: Popped - letting navigation observer reactivate HomeView',
          );
        }
      },
      child: KeyedSubtree(
        child: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            child: Column(
              children: [
                _buildTopChrome(),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: _isSearchVisible
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _buildSearchBar(),
                        )
                      : const SizedBox.shrink(),
                ),
                _buildTabButtons(),
                if (_networkErrorMessage != null)
                  _buildNetworkErrorBanner(_networkErrorMessage!),
                Expanded(
                  child: FadeTransition(
                    opacity: _contentFadeAnimation,
                    child: SlideTransition(
                      position: _contentSlideAnimation,
                      child: _buildMainContent(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkErrorBanner(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: _th.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: _th.error, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: SelectableText.rich(
                  TextSpan(
                    text: message,
                    style: TextStyle(
                      color: _th.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _networkErrorMessage = null);
                  _loadUsersFromFollowsService();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final Color on = _th.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: on.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: on.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (_) => _onSearchChanged(),
          style: TextStyle(color: on),
          decoration: InputDecoration(
            hintText: 'Search users...',
            hintStyle: TextStyle(
              color: on.withValues(alpha: 0.5),
              fontSize: 16,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: on.withValues(alpha: 0.5),
            ),
            suffixIcon: _isSearching
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_th.primary),
                      ),
                    ),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopChrome() {
    final Color on = _th.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Network',
                      style: TextStyle(
                        color: on,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Build your creator circle.',
                      style: TextStyle(
                        color: on.withValues(alpha: 0.62),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildIconHeaderAction(
                icon: _isSearchVisible
                    ? Icons.close_rounded
                    : Icons.search_rounded,
                isPrimary: _isSearchVisible,
                tooltip: _isSearchVisible ? 'Close search' : 'Search network',
                onTap: _toggleSearch,
              ),
              const SizedBox(width: 8),
              _buildIconHeaderAction(
                icon: Icons.tune_rounded,
                tooltip: 'Sort and filter',
                onTap: _showSortOptions,
              ),
              const SizedBox(width: 8),
              _buildIconHeaderAction(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh network',
                onTap: _refreshDataInstantly,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildNetworkEnergyRow(),
        ],
      ),
    );
  }

  Widget _buildNetworkEnergyRow() {
    final int activeCreators = _getAllUsersForSearch()
        .where(
          (user) =>
              user.onlineStatus == user_model.OnlineStatus.online ||
              user.onlineStatus == user_model.OnlineStatus.streaming,
        )
        .length;
    final int creatorsPosting =
        _getAllUsersForSearch().where((user) => user.postCount > 0).length;
    return Row(
      children: [
        Expanded(
          child: _NetworkEnergyChip(
            icon: Icons.circle,
            label: '$activeCreators active now',
            color: activeCreators > 0 ? Colors.greenAccent : _th.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _NetworkEnergyChip(
            icon: Icons.movie_creation_outlined,
            label: '$creatorsPosting creators posted',
            color: _th.primary,
          ),
        ),
        const SizedBox(width: 8),
        _buildStatusChip(),
      ],
    );
  }

  Widget _buildStatusChip() {
    if (!_isFirebaseReady) {
      return _buildStatusPill(
        label: 'Offline',
        icon: Icons.cloud_off_rounded,
        color: Colors.grey,
      );
    }

    return Consumer(
      builder: (context, ref, child) {
        final statusAsync = ref.watch(statusNotifierProvider);
        return statusAsync.when(
          data: (presence) => _buildStatusPill(
            label: presence.status.displayName,
            icon: _getStatusIcon(presence.status),
            color: _getStatusColor(presence.status),
          ),
          loading: () => _buildStatusPill(
            label: 'Loading',
            icon: Icons.more_horiz_rounded,
            color: Colors.grey,
          ),
          error: (error, stack) => _buildStatusPill(
            label: 'Error',
            icon: Icons.error_outline_rounded,
            color: Colors.red,
          ),
        );
      },
    );
  }

  Widget _buildStatusPill({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconHeaderAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final Color fg = isPrimary ? _th.onPrimary : _th.onSurface;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color:
                isPrimary ? _th.primary : _th.onSurface.withValues(alpha: 0.06),
            shape: BoxShape.circle,
            border: Border.all(
              color: isPrimary
                  ? _th.primary.withValues(alpha: 0.34)
                  : _th.onSurface.withValues(alpha: 0.12),
            ),
          ),
          child: Icon(
            icon,
            color: fg.withValues(
              alpha: isPrimary ? 1 : 0.72,
            ),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildCreatorActivityLine(user_model.User user) {
    final CreatorActivityService activityService = CreatorActivityService();
    final CreatorActivity activity =
        activityService.effectiveActivity(<String, dynamic>{
      'creatorActivity': user.creatorActivity.toMap(),
    });
    if (!_shouldShowCreatorActivity(user, activity)) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: CreatorActivityBadge(
        activity: activity,
        compact: true,
        showPlatform: true,
      ),
    );
  }

  bool _shouldShowCreatorActivity(
    user_model.User user,
    CreatorActivity activity,
  ) {
    if (activity.isNone) return false;
    final CreatorActivityPrivacy privacy = user.activityPrivacy;
    if (privacy.hideFromEveryone || !privacy.showCreatorActivity) {
      return false;
    }
    if (privacy.connectionsOnly &&
        !_connectionsUsers.any((user_model.User u) => u.id == user.id)) {
      return false;
    }
    final CreatorActivityService svc = CreatorActivityService();
    if (svc.isLiveType(activity.type) && !privacy.showLiveStatus) {
      return false;
    }
    if (svc.isPostType(activity.type) && !privacy.showPostActivity) {
      return false;
    }
    if (svc.isCollaborationType(activity.type) &&
        !privacy.showCollaborationStatus) {
      return false;
    }
    return true;
  }

  String _creatorTypeLabel(user_model.User user) {
    if (user.hashtags.isNotEmpty) {
      return user.hashtags.first.replaceFirst('#', '');
    }
    if (user.platforms.isNotEmpty) {
      return '${user.platforms.first.type.displayName} creator';
    }
    if (user.bio?.trim().isNotEmpty == true) {
      final bio = user.bio!.trim();
      return bio.length > 36 ? '${bio.substring(0, 36)}...' : bio;
    }
    return '@${user.username}';
  }

  Widget _buildTabButtons() {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity;
        if (velocity != null) {
          if (velocity > 0) {
            _previousTab();
          } else if (velocity < 0) {
            _nextTab();
          }
        }
      },
      child: SizedBox(
        height: 106,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            spacing: 10,
            children: [
              _buildLargeNetworkButton(
                'Connections',
                Icons.people,
                network_models.NetworkTab.connections,
                _connectionsUsers.length,
              ),
              _buildLargeNetworkButton(
                'Followers',
                Icons.person_add,
                network_models.NetworkTab.followers,
                _followersUsers.length,
              ),
              _buildLargeNetworkButton(
                'Following',
                Icons.person,
                network_models.NetworkTab.following,
                _followingUsers.length,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeNetworkButton(
    String title,
    IconData icon,
    network_models.NetworkTab tab,
    int count,
  ) {
    final isSelected = _selectedTab == tab;
    final Color on = _th.onSurface;
    final Color fg = isSelected ? _th.primary : on;
    return GestureDetector(
      onTap: () => _selectTab(tab),
      child: Container(
        width: 138,
        height: 92,
        decoration: BoxDecoration(
          color: isSelected
              ? _th.primary.withValues(alpha: 0.13)
              : on.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? _th.primary.withValues(alpha: 0.30)
                : on.withValues(alpha: 0.12),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 17,
                    color: fg.withValues(alpha: isSelected ? 1 : 0.62),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _th.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  color: on.withValues(alpha: isSelected ? 0.96 : 0.68),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected ? _th.primary : on,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'people',
                    style: TextStyle(
                      color: on.withValues(alpha: 0.48),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoadingUsers) {
      return RefreshIndicator(
        onRefresh: _handlePullToRefresh,
        color: _th.primary,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          itemCount: 6,
          itemBuilder: (_, __) => _buildSkeletonCard(),
        ),
      );
    }

    final currentList = _currentList();
    if (currentList.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _handlePullToRefresh,
      color: _th.primary,
      child: ListView.builder(
        controller: _listController,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: currentList.length,
        itemBuilder: (context, index) {
          final user = currentList[index];
          return _buildUserCard(user);
        },
      ),
    );
  }

  void _navigateToStreamerCard(user_model.User user) {
    HapticFeedback.lightImpact();
    final String userId =
        user.id.isNotEmpty ? user.id : user.username;
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load profile. User record missing.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);

    AppNavigator.openStreamerCard(
      context,
      userId: userId,
      initialCreator: CreatorProfileSnapshot.fromNetworkUser(user),
      currentUserId: FirebaseAuth.instance.currentUser?.uid,
      onDismiss: () => Navigator.of(context).pop(),
      onNavigateToTab: (String tabName) {
        HapticFeedback.lightImpact();
        _navigateToTab(tabName);
        Navigator.of(context).pop();
      },
    ).then((_) {
      if (mounted) {
        _refreshDataInstantly();
      }
    });
  }

  Widget _buildUserCard(user_model.User user) {
    final Color on = _th.onSurface;
    final subtitle = _creatorTypeLabel(user);
    final TextStyle statsStyle = TextStyle(
      color: on.withValues(alpha: 0.5),
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );
    final Widget statsLine = _NetworkUserPostsStatLine(
      user: user,
      style: statsStyle,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey('network_user_${user.id}_${_selectedTab.name}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _handleSwipeAction(user),
        dismissThresholds: const {
          DismissDirection.endToStart: 0.18,
        },
        onUpdate: (details) {
          final hapticKey = '${_selectedTab.name}:${user.id}';
          if (details.direction == DismissDirection.endToStart &&
              details.progress > 0.18 &&
              _swipeHapticShown.add(hapticKey)) {
            HapticFeedback.selectionClick();
          }
          if (details.progress < 0.04) {
            _swipeHapticShown.remove(hapticKey);
          }
        },
        background: _buildSwipeBackground(),
        child: GestureDetector(
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _showNetworkActions(user);
          },
          onTap: () {
            HapticFeedback.lightImpact();
            _navigateToStreamerCard(user);
          },
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 82),
            decoration: BoxDecoration(
              color: on.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: on.withValues(alpha: 0.10)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  StatusAwareAvatar(
                    userId: user.id,
                    avatarURL: user.avatarURL,
                    radius: 22,
                    showOnlineIndicator: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.displayName,
                          style: TextStyle(
                            color: on,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: on.withValues(alpha: 0.58),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        _buildCreatorActivityLine(user),
                        const SizedBox(height: 6),
                        statsLine,
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Tooltip(
                    message: 'Message',
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _th.primary.withValues(alpha: 0.11),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _th.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: _th.primary,
                        size: 17,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final Color on = _th.onSurface;
    final bool isCompletelyEmpty = _isNetworkCompletelyEmpty;
    final String title = isCompletelyEmpty
        ? 'Build Your Creator Circle'
        : _selectedTab == network_models.NetworkTab.followers
            ? 'No followers yet'
            : _selectedTab == network_models.NetworkTab.following
                ? 'You are not following anyone yet'
                : 'No connections yet';
    final String subtitle = isCompletelyEmpty
        ? 'Connect with creators, discover collaborators, and grow together.'
        : _selectedTab == network_models.NetworkTab.followers
            ? 'Share your profile and keep posting to grow your audience.'
            : _selectedTab == network_models.NetworkTab.following
                ? 'Find creators and friends from Home or Search, then follow them here.'
                : 'Follow back people who follow you to turn one-way relationships into connections.';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          decoration: BoxDecoration(
            color: on.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: on.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.supportAccentGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.all(
                    Radius.circular(24),
                  ),
                ),
                child: Icon(
                  Icons.people_outline_rounded,
                  size: 36,
                  color: _th.onPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: on,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: TextStyle(
                  color: on.withValues(alpha: 0.64),
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              if (isCompletelyEmpty) ...[
                _buildEmptyStateCta(
                  label: 'Discover Creators',
                  icon: Icons.explore_rounded,
                  isPrimary: true,
                  onTap: _openDiscoverCreators,
                ),
                const SizedBox(height: 10),
                _buildEmptyStateCta(
                  label: 'Share Profile',
                  icon: Icons.ios_share_rounded,
                  isPrimary: false,
                  onTap: _openShareProfile,
                ),
              ] else
                _buildEmptyStateCta(
                  label: 'Refresh network',
                  icon: Icons.refresh_rounded,
                  isPrimary: true,
                  onTap: _refreshDataInstantly,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateCta({
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: AppColors.supportAccentGradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isPrimary ? null : _th.onSurface.withValues(alpha: 0.08),
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          border: isPrimary
              ? null
              : Border.all(color: _th.onSurface.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isPrimary ? _th.onPrimary : _th.onSurface,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? _th.onPrimary : _th.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDiscoverCreators() async {
    await AppNavigator.openDiscover(context);
    if (mounted) {
      await _refreshDataInstantly();
    }
  }

  Future<void> _openShareProfile() async {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      return;
    }
    Map<String, dynamic> userData = <String, dynamic>{
      'id': userId,
      'uid': userId,
    };
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
      final Map<String, dynamic>? data = doc.data();
      if (data != null) {
        userData = <String, dynamic>{
          ...data,
          'id': userId,
          'uid': userId,
        };
      }
    } catch (e) {
      debugPrint('⚠️ NetworkView: Unable to load profile for share: $e');
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.shareProfile),
        builder: (BuildContext routeContext) => ShareProfileView(
          user: userData,
          dismiss: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    final Color b = _th.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        height: 86,
        decoration: BoxDecoration(
          color: b.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: b.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: 140,
                    decoration: BoxDecoration(
                      color: b.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 90,
                    decoration: BoxDecoration(
                      color: b.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10,
                    width: 72,
                    decoration: BoxDecoration(
                      color: b.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: b.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _th.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SwipeActionDot(
              icon: Icons.person_search_rounded, color: _th.primary),
          const SizedBox(width: 8),
          _SwipeActionDot(
            icon: Icons.person_remove_rounded,
            color: Colors.orangeAccent,
          ),
          const SizedBox(width: 8),
          const _SwipeActionDot(
              icon: Icons.block_rounded, color: Colors.redAccent),
        ],
      ),
    );
  }

  Future<bool> _handleSwipeAction(user_model.User user) async {
    HapticFeedback.mediumImpact();
    await _showNetworkActions(user);
    return false;
  }

  Future<void> _showNetworkActions(user_model.User user) async {
    final tab = _selectedTab;
    if (FirebaseAuth.instance.currentUser?.uid == null) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final removeLabel = tab == network_models.NetworkTab.followers
            ? 'Remove follower'
            : 'Unfollow';
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person_search_rounded),
                  title: const Text('View Profile'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _navigateToStreamerCard(user);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_remove_rounded),
                  title: Text(removeLabel),
                  onTap: () {
                    Navigator.of(context).pop();
                    _runNetworkAction(
                      user,
                      tab == network_models.NetworkTab.followers
                          ? _NetworkAction.removeFollower
                          : _NetworkAction.unfollow,
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.block_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Block',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _runNetworkAction(user, _NetworkAction.block);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _runNetworkAction(
    user_model.User user,
    _NetworkAction action,
  ) async {
    try {
      bool ok = true;
      switch (action) {
        case _NetworkAction.unfollow:
          ok = await FollowsService().unfollowUser(user.id);
          break;
        case _NetworkAction.removeFollower:
          ok = await FollowsService().removeFollower(user.id);
          break;
        case _NetworkAction.block:
          await UserBlockingService().blockUser(targetUserId: user.id);
          ok = true;
          break;
      }
      if (!mounted) return;
      if (ok) {
        await _refreshDataInstantly();
        if (!mounted) return;
        ref.read(followRefreshProvider.notifier).state++;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? _networkActionSuccessLabel(user, action)
              : 'Unable to update ${user.displayName}.'),
          backgroundColor: ok ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('❌ Network action failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network action failed. Try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _networkActionSuccessLabel(
    user_model.User user,
    _NetworkAction action,
  ) {
    switch (action) {
      case _NetworkAction.unfollow:
        return 'Unfollowed @${user.username}';
      case _NetworkAction.removeFollower:
        return 'Removed @${user.username} from followers';
      case _NetworkAction.block:
        return 'Blocked @${user.username}';
    }
  }

  void _selectTab(network_models.NetworkTab tab) {
    if (_selectedTab == tab) return;
    setState(() {
      _selectedTab = tab;
      switch (tab) {
        case network_models.NetworkTab.connections:
          _connectionsPage = 1;
          break;
        case network_models.NetworkTab.followers:
          _followersPage = 1;
          break;
        case network_models.NetworkTab.following:
          _followingPage = 1;
          break;
      }
    });
    _contentTransitionController.forward(from: 0);
    if (_listController.hasClients) {
      _listController.jumpTo(0);
    }
  }

  network_models.NetworkTab _getTabFromString(String tabName) {
    switch (tabName.toLowerCase()) {
      case 'connections':
        return network_models.NetworkTab.connections;
      case 'followers':
        return network_models.NetworkTab.followers;
      case 'following':
        return network_models.NetworkTab.following;
      default:
        return network_models.NetworkTab.connections;
    }
  }

  void _navigateToTab(String tabName) {
    network_models.NetworkTab targetTab = _getTabFromString(tabName);

    if (kDebugMode) {
      debugPrint(
        "🔵 NetworkView: Navigating to tab: $tabName (${targetTab.name})",
      );
    }

    _selectTab(targetTab);

    // Also refresh data to show the updated relationships
    _refreshDataInstantly();
  }

  void _nextTab() {
    switch (_selectedTab) {
      case network_models.NetworkTab.connections:
        _selectTab(network_models.NetworkTab.followers);
        break;
      case network_models.NetworkTab.followers:
        _selectTab(network_models.NetworkTab.following);
        break;
      case network_models.NetworkTab.following:
        _selectTab(network_models.NetworkTab.connections);
        break;
    }
  }

  void _previousTab() {
    switch (_selectedTab) {
      case network_models.NetworkTab.connections:
        _selectTab(network_models.NetworkTab.following);
        break;
      case network_models.NetworkTab.followers:
        _selectTab(network_models.NetworkTab.connections);
        break;
      case network_models.NetworkTab.following:
        _selectTab(network_models.NetworkTab.followers);
        break;
    }
  }

  /// Refresh data instantly without showing loading indicator
  Future<void> _refreshDataInstantly({bool forceRefresh = false}) async {
    if (_isRefreshingNetworkData) {
      return;
    }
    if (!isMainTabNetworkVisible(ref.read(mainTabActiveIndexProvider))) {
      return;
    }
    _isRefreshingNetworkData = true;
    if (!_isFirebaseReady) {
      if (mounted) {
        setState(() {
          _connectionsUsers = [];
          _followersUsers = [];
          _followingUsers = [];
          _isLoadingUsers = false;
        });
      }
      _isRefreshingNetworkData = false;
      return;
    }

    try {
      debugPrint('🔄 NetworkView: Starting instant data refresh...');
      final FollowsService followsSvc = FollowsService();
      final NetworkTabUsers bundle = await followsSvc.loadNetworkTabUsers(
        forceRefresh: forceRefresh,
      );

      debugPrint(
        '📊 NetworkView: Data loaded - Connections: ${bundle.connections.length}, '
        'Followers: ${bundle.followers.length}, Following: ${bundle.following.length}',
      );

      final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
      int? followersCountDoc;
      int? followingCountDoc;
      if (currentUserId != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .get();
          final data = userDoc.data();
          if (data != null) {
            followersCountDoc = UserCountFields.readFollowersCount(data);
            followingCountDoc = UserCountFields.readFollowingCount(data);
          }
        } catch (e) {
          debugPrint('⚠️ NetworkView: Unable to read doc counters: $e');
        }
      }

      _logDriftIfAny(
        actualFollowersCount: bundle.counts.followersCount,
        actualFollowingCount: bundle.counts.followingCount,
        followersCountDoc: followersCountDoc,
        followingCountDoc: followingCountDoc,
      );
      if (currentUserId != null &&
          ((followersCountDoc != null &&
                  followersCountDoc != bundle.counts.followersCount) ||
              (followingCountDoc != null &&
                  followingCountDoc != bundle.counts.followingCount))) {
        unawaited(followsSvc.repairFollowCountersForUser(currentUserId));
      }

      if (mounted) {
        final bool listsChanged = !_networkListsEqual(
          _connectionsUsers,
          bundle.connections,
          _followersUsers,
          bundle.followers,
          _followingUsers,
          bundle.following,
        );
        setState(() {
          if (listsChanged) {
            _connectionsUsers = bundle.connections;
            _followersUsers = bundle.followers;
            _followingUsers = bundle.following;
          }
          _hasMoreFollowGraph = bundle.hasMoreFollowGraph;
          _isLoadingUsers = false;
        });
        if (listsChanged) {
          debugPrint('✅ NetworkView: UI updated with new data');
        }
      }
    } catch (e) {
      debugPrint('❌ NetworkView: Error refreshing data instantly: $e');
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
        });
      }
    } finally {
      _isRefreshingNetworkData = false;
    }
  }

  bool _networkListsEqual(
    List<user_model.User> connectionsA,
    List<user_model.User> connectionsB,
    List<user_model.User> followersA,
    List<user_model.User> followersB,
    List<user_model.User> followingA,
    List<user_model.User> followingB,
  ) {
    bool idsEqual(List<user_model.User> a, List<user_model.User> b) {
      if (a.length != b.length) {
        return false;
      }
      for (int i = 0; i < a.length; i++) {
        if (a[i].id != b[i].id) {
          return false;
        }
      }
      return true;
    }

    return idsEqual(connectionsA, connectionsB) &&
        idsEqual(followersA, followersB) &&
        idsEqual(followingA, followingB);
  }

  /// Handle pull-to-refresh action
  Future<void> _handlePullToRefresh() async {
    debugPrint('🔄 NetworkView: Pull-to-refresh triggered');
    await _refreshDataInstantly();
  }

  /// Get status color for user status indicator
  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return const Color(0xFF4CAF50); // Green
      case UserStatus.offline:
        return const Color(0xFF9E9E9E); // Grey
      case UserStatus.busy:
        return const Color(0xFFFF9800); // Orange
      case UserStatus.away:
        return const Color(0xFFF44336); // Red
      case UserStatus.streaming:
        return const Color(0xFF9C27B0); // Purple
    }
  }

  /// Get status icon for user status indicator
  IconData _getStatusIcon(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return Icons.circle;
      case UserStatus.offline:
        return Icons.circle_outlined;
      case UserStatus.busy:
        return Icons.pause_circle;
      case UserStatus.away:
        return Icons.block;
      case UserStatus.streaming:
        return Icons.play_circle;
    }
  }
}

enum _NetworkAction { unfollow, removeFollower, block }

class _NetworkEnergyChip extends StatelessWidget {
  const _NetworkEnergyChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color.withValues(alpha: 0.88), size: 11),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.68),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeActionDot extends StatelessWidget {
  const _SwipeActionDot({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Icon(icon, color: color, size: 17),
    );
  }
}

/// Matches [StreamerCardView] / [UserStatsRow] post count when feed state
/// already includes this user's videos (all Network tabs).
class _NetworkUserPostsStatLine extends ConsumerWidget {
  const _NetworkUserPostsStatLine({
    required this.user,
    required this.style,
  });

  final user_model.User user;
  final TextStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<HomeVideo> allVideos =
        ref.watch(video_providers.videoServiceStateProvider);
    final bool isVideoServiceLoading =
        ref.watch(video_providers.videoServiceLoadingProvider);
    final List<HomeVideo> userVideos =
        ref.watch(video_providers.userVideosProvider(user.id));
    final int? postsCountOverride = resolvePostsCountOverride(
      userVideos: userVideos,
      allVideos: allVideos,
      isVideoServiceLoading: isVideoServiceLoading,
    );
    final int count = postsCountOverride ?? user.postCount;
    return Text(
      '$count posts',
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
