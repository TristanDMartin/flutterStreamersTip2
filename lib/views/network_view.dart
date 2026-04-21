import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../models/user_model.dart' as user_model;
import '../models/network_models.dart' as network_models;
import '../models/user_count_fields.dart';
import '../models/user_status.dart';
import '../services/follows_service.dart';
import '../services/migration_service.dart';
import '../services/performance_monitoring_service.dart';
import '../widgets/status_aware_avatar.dart';
import '../providers/status_provider.dart';
import '../routing/app_navigator.dart';
import '../providers/follow_refresh_provider.dart';
import '../constants/app_colors.dart';

class NetworkView extends ConsumerStatefulWidget {
  final String? initialTab;

  const NetworkView({super.key, this.initialTab});

  @override
  ConsumerState<NetworkView> createState() => _NetworkViewState();
}

class _NetworkViewState extends ConsumerState<NetworkView>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
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

  // Network connectivity (kept for network error handling)
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Real-time relationship listeners
  StreamSubscription<QuerySnapshot>? _followersSubscription;
  StreamSubscription<QuerySnapshot>? _followingSubscription;
  StreamSubscription<QuerySnapshot>? _scopedFollowsSubscription1;
  StreamSubscription<QuerySnapshot>? _scopedFollowsSubscription2;

  // Error state
  bool _hasShownPermissionError = false;
  DateTime? _lastFollowListenerErrorSnackAt;

  bool get _isFirebaseReady => Firebase.apps.isNotEmpty;

  @override
  bool get wantKeepAlive => false; // Don't keep alive when not visible

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

    // Load users from clean relationship service
    if (_isFirebaseReady) {
      _loadUsersFromFollowsService();
    }

    // Start monitoring when view initializes
    PerformanceMonitoringService().startMonitoring();

    // Initialize real-time relationship listeners
    if (_isFirebaseReady) {
      _initializeRelationshipListeners();
    }
  }

  void _logDriftIfAny({int? followersCountDoc, int? followingCountDoc}) {
    if (followersCountDoc != null &&
        followersCountDoc != _followersUsers.length) {
      debugPrint(
        '⚠️ NetworkView: Drift detected - followers doc $followersCountDoc vs list ${_followersUsers.length}',
      );
    }
    if (followingCountDoc != null &&
        followingCountDoc != _followingUsers.length) {
      debugPrint(
        '⚠️ NetworkView: Drift detected - following doc $followingCountDoc vs list ${_followingUsers.length}',
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

    super.dispose();
  }

  /// Initialize network connectivity monitoring
  void _initializeConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final hasConnection =
          results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);

      // Connection status is now handled by the status provider

      if (!hasConnection && mounted) {
        _showNetworkError();
      }
    });
  }

  /// Initialize real-time relationship listeners for instant updates (OPTIMIZED)
  void _initializeRelationshipListeners() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      debugPrint(
        '❌ NetworkView: No current user ID, cannot initialize listeners',
      );
      return;
    }

    debugPrint(
      '🔄 NetworkView: Initializing real-time listeners for user: $currentUserId',
    );

    Timer? debounceTimer;

    void onFollowsUpdate(QuerySnapshot _) {
      debounceTimer?.cancel();
      debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _refreshDataInstantly();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPermissionDenied
                ? 'Cannot load network: missing permissions.'
                : 'Network updates failed. Check connection.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No internet connection. Please check your network.',
          ),
          backgroundColor: Colors.orange.withValues(alpha: 0.8),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              _loadUsersFromFollowsService();
            },
          ),
        ),
      );
    }
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

      final followsSvc = FollowsService();

      // Load all three lists in parallel using the correct tab logic
      debugPrint(
        '🔄 NetworkView: Loading connections, followers, and following...',
      );
      final results = await Future.wait([
        followsSvc.getUsersForTab('connections'),
        followsSvc.getUsersForTab('followers'),
        followsSvc.getUsersForTab('following'),
      ]);

      debugPrint(
        '📊 NetworkView: Raw results - Connections: ${results[0].length}, Followers: ${results[1].length}, Following: ${results[2].length}',
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

      _resetPagination();

      setState(() {
        _connectionsUsers = results[0];
        _followersUsers = results[1];
        _followingUsers = results[2];
        _isLoadingUsers = false;
      });

      _logDriftIfAny(
        followersCountDoc: followersCountDoc,
        followingCountDoc: followingCountDoc,
      );

      debugPrint(
        '🎯 NetworkView: Final state - Connections: ${_connectionsUsers.length}, Followers: ${_followersUsers.length}, Following: ${_followingUsers.length}',
      );

      _logDriftIfAny(
        followersCountDoc: followersCountDoc,
        followingCountDoc: followingCountDoc,
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
      setState(() {
        _isLoadingUsers = false;
      });

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
      final followsSnapshot = await FirebaseFirestore.instance
          .collection('follows')
          .limit(1)
          .get();

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
      child: Container(
        color: AppColors.supportBackground,
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
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (_) => _onSearchChanged(),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search users...',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Network',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isSearchVisible
                            ? 'Search across your connections, followers, and following.'
                            : 'Keep track of your people and move between lists quickly.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildStatusChip(),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildHeaderAction(
                    icon: Icons.refresh_rounded,
                    label: 'Refresh',
                    onTap: _refreshDataInstantly,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildHeaderAction(
                    icon: Icons.swap_vert_rounded,
                    label: 'Sort',
                    onTap: _showSortOptions,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildHeaderAction(
                    icon: _isSearchVisible
                        ? Icons.close_rounded
                        : Icons.search_rounded,
                    label: _isSearchVisible ? 'Close' : 'Search',
                    isPrimary: true,
                    onTap: _toggleSearch,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

  Widget _buildHeaderAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: AppColors.supportAccentGradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isPrimary ? null : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isPrimary
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
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
        height: 148,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            spacing: 16,
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

    return GestureDetector(
      onTap: () => _selectTab(tab),
      child: Container(
        width: 178,
        height: 132,
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: AppColors.supportAccentGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.24)
                : Colors.white.withValues(alpha: 0.16),
            width: 1.4,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: isSelected ? 0.20 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: isSelected ? 0.18 : 0.12,
                    ),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: Colors.white.withValues(alpha: isSelected ? 1 : 0.82),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: isSelected ? 1 : 0.82),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'people',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.74),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
        color: Colors.white,
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
      color: Colors.white,
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
    Future.microtask(() async {
      if (mounted) {
        final userId = await _resolveUserDocumentId(user);
        if (userId == null) {
          debugPrint(
            '❌ NetworkView: Unable to resolve user document for ${user.displayName} (${user.username})',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to load profile. User record missing.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

        if (!mounted) return;
        AppNavigator.openStreamerCard(
          context,
          userId: userId,
          currentUserId: FirebaseAuth.instance.currentUser?.uid,
          onDismiss: () => Navigator.of(context).pop(),
          onNavigateToTab: (tabName) {
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
    });
  }

  Future<String?> _resolveUserDocumentId(user_model.User user) async {
    // If the provided ID already looks like a Firestore UID, use it directly
    if (user.id.isNotEmpty && user.id.length >= 20) {
      return user.id;
    }

    try {
      // Try looking up by username first
      if (user.username.isNotEmpty) {
        final usernameQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: user.username)
            .limit(1)
            .get();

        if (usernameQuery.docs.isNotEmpty) {
          return usernameQuery.docs.first.id;
        }
      }

      // Fallback to display name (exact match)
      if (user.displayName.isNotEmpty) {
        final displayNameQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('displayName', isEqualTo: user.displayName)
            .limit(1)
            .get();

        if (displayNameQuery.docs.isNotEmpty) {
          return displayNameQuery.docs.first.id;
        }
      }
    } catch (e) {
      debugPrint('❌ NetworkView: Error resolving user document: $e');
    }

    return null;
  }

  Widget _buildUserCard(user_model.User user) {
    final subtitle = user.bio?.trim().isNotEmpty == true
        ? user.bio!.trim()
        : '@${user.username}';
    final statsLabel = _selectedTab == network_models.NetworkTab.followers
        ? '${user.followerCount} followers'
        : _selectedTab == network_models.NetworkTab.following
        ? '${user.followingCount} following'
        : '${user.postCount} posts';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey('network_user_${user.id}_${_selectedTab.name}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _handleSwipeAction(user),
        background: _buildSwipeBackground(),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _navigateToStreamerCard(user);
          },
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 88),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  StatusAwareAvatar(
                    userId: user.id,
                    avatarURL: user.avatarURL,
                    radius: 24,
                    showOnlineIndicator: true,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.70),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          statsLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.54),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.72),
                      size: 20,
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
    final title = _selectedTab == network_models.NetworkTab.followers
        ? 'No followers yet'
        : _selectedTab == network_models.NetworkTab.following
        ? 'You are not following anyone yet'
        : 'No connections yet';
    final subtitle = _selectedTab == network_models.NetworkTab.followers
        ? 'Share your profile and keep posting to grow your audience.'
        : _selectedTab == network_models.NetworkTab.following
        ? 'Find creators and friends from Home or Search, then follow them here.'
        : 'Follow back people who follow you to turn one-way relationships into connections.';

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.supportAccentGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.70),
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _refreshDataInstantly();
              },
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.supportAccentGradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Refresh network',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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

  Widget _buildSkeletonCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        height: 86,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
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
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 90,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10,
                    width: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
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
                color: Colors.white.withValues(alpha: 0.08),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withValues(alpha: 0.58),
            Colors.red.withValues(alpha: 0.88),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block_rounded, color: Colors.white),
          SizedBox(width: 8),
          Icon(Icons.delete_forever_rounded, color: Colors.white),
        ],
      ),
    );
  }

  Future<bool> _handleSwipeAction(user_model.User user) async {
    HapticFeedback.mediumImpact();
    final tab = _selectedTab;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return false;

    try {
      if (tab == network_models.NetworkTab.following ||
          tab == network_models.NetworkTab.connections) {
        final ok = await FollowsService().unfollowUser(user.id);
        if (ok) {
          _refreshDataInstantly();
          return true;
        }
        return false;
      }

      final batch = FirebaseFirestore.instance.batch();
      final follows = FirebaseFirestore.instance.collection('follows');

      final legacyDocs = await follows
          .where('followerId', isEqualTo: user.id)
          .where('followedId', isEqualTo: currentUserId)
          .get();
      for (final doc in legacyDocs.docs) {
        batch.delete(doc.reference);
      }

      final primaryDocs = await follows
          .where('targetUserId', isEqualTo: currentUserId)
          .where('followerUserId', isEqualTo: user.id)
          .get();
      for (final doc in primaryDocs.docs) {
        batch.delete(doc.reference);
      }

      if (legacyDocs.docs.isEmpty && primaryDocs.docs.isEmpty) {
        debugPrint(
          '⚠️ No follower docs found to remove for ${user.id}, skipping.',
        );
        return false;
      }

      await batch.commit();
      _refreshDataInstantly();
      return true;
    } catch (e) {
      debugPrint('❌ Swipe action failed: $e');
      return false;
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
  Future<void> _refreshDataInstantly() async {
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

    try {
      debugPrint('🔄 NetworkView: Starting instant data refresh...');
      final followsSvc = FollowsService();

      // Load all three lists in parallel using the correct tab logic
      debugPrint(
        '🔄 NetworkView: Loading connections, followers, and following...',
      );
      final results = await Future.wait([
        followsSvc.getUsersForTab('connections'),
        followsSvc.getUsersForTab('followers'),
        followsSvc.getUsersForTab('following'),
      ]);

      debugPrint(
        '📊 NetworkView: Data loaded - Connections: ${results[0].length}, Followers: ${results[1].length}, Following: ${results[2].length}',
      );

      // Debug: Print user details
      debugPrint('🔗 CONNECTIONS (Mutual Follows):');
      for (int i = 0; i < results[0].length; i++) {
        debugPrint('  $i: ${results[0][i].displayName} (${results[0][i].id})');
      }

      debugPrint('👥 FOLLOWERS (They follow you):');
      for (int i = 0; i < results[1].length; i++) {
        debugPrint('  $i: ${results[1][i].displayName} (${results[1][i].id})');
      }

      debugPrint('➡️ FOLLOWING (You follow them):');
      for (int i = 0; i < results[2].length; i++) {
        debugPrint('  $i: ${results[2][i].displayName} (${results[2][i].id})');
      }

      if (mounted) {
        setState(() {
          _connectionsUsers = results[0];
          _followersUsers = results[1];
          _followingUsers = results[2];
        });
        debugPrint('✅ NetworkView: UI updated with new data');
      }
    } catch (e) {
      debugPrint('❌ NetworkView: Error refreshing data instantly: $e');
    }
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
      case UserStatus.dnd:
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
      case UserStatus.dnd:
        return Icons.block;
      case UserStatus.streaming:
        return Icons.play_circle;
    }
  }
}
