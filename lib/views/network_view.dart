import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../models/user_model.dart' as user_model;
import '../models/network_models.dart' as network_models;
import '../models/user_status.dart';
import '../services/follows_service.dart';
import '../services/migration_service.dart';
import '../services/performance_monitoring_service.dart';
import '../services/global_playback_manager.dart';
import '../widgets/streamer_card_view.dart';
import '../widgets/status_aware_avatar.dart';
import '../providers/status_provider.dart';

class NetworkView extends ConsumerStatefulWidget {
  final String? initialTab;

  const NetworkView({super.key, this.initialTab});

  @override
  ConsumerState<NetworkView> createState() => _NetworkViewState();
}

class _NetworkViewState extends ConsumerState<NetworkView>
    with AutomaticKeepAliveClientMixin {
  network_models.NetworkTab _selectedTab =
      network_models.NetworkTab.connections;
  final ScrollController _listController = ScrollController();
  final GlobalPlaybackManager _playbackManager = GlobalPlaybackManager.instance;
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
  StreamSubscription<QuerySnapshot>? _scopedFollowsSubscription;

  // Error state
  bool _hasShownPermissionError = false;

  @override
  bool get wantKeepAlive => false; // Don't keep alive when not visible

  @override
  void initState() {
    super.initState();

    // 🔊 AUDIO FIX: Block playback IMMEDIATELY (synchronously) when NetworkView opens
    // This prevents audio bleeding from HomeView - must happen before any widgets build
    // CRITICAL: This must be synchronous, not in postFrameCallback, to prevent any audio
    _playbackManager.block(reason: 'networkViewOpened');

    // Step 2: Aggressively mute and pause ALL videos synchronously
    _playbackManager.pauseAll();

    _listController.addListener(_maybeLoadMore);

    if (kDebugMode) {
      debugPrint(
          '🔇 NetworkView: Blocked playback and paused all videos IMMEDIATELY');
    }

    // Set initial tab if provided
    if (widget.initialTab != null) {
      _selectedTab = _getTabFromString(widget.initialTab!);
      if (kDebugMode) {
        debugPrint(
            "🔵 NetworkView: Initialized with tab: ${widget.initialTab} -> ${_selectedTab.name}");
      }
    }

    // ❌ REMOVED: Global error handler override - now handled at app level

    // Initialize network connectivity monitoring
    _initializeConnectivityMonitoring();

    // Load users from clean relationship service
    _loadUsersFromFollowsService();

    // Start monitoring when view initializes
    PerformanceMonitoringService().startMonitoring();

    // Initialize real-time relationship listeners
    _initializeRelationshipListeners();
  }

  void _logDriftIfAny({
    int? followersCountDoc,
    int? followingCountDoc,
  }) {
    if (followersCountDoc != null &&
        followersCountDoc != _followersUsers.length) {
      debugPrint(
          '⚠️ NetworkView: Drift detected - followers doc $followersCountDoc vs list ${_followersUsers.length}');
    }
    if (followingCountDoc != null &&
        followingCountDoc != _followingUsers.length) {
      debugPrint(
          '⚠️ NetworkView: Drift detected - following doc $followingCountDoc vs list ${_followingUsers.length}');
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _followersSubscription?.cancel();
    _followingSubscription?.cancel();
    _scopedFollowsSubscription?.cancel();

    // Stop performance monitoring
    PerformanceMonitoringService().stopMonitoring();

    // Dispose controllers
    _listController.removeListener(_maybeLoadMore);
    _listController.dispose();
    _searchController.dispose();
    // Dispose timers
    _searchTimer?.cancel();

    _playbackManager.unblock();

    super.dispose();
  }

  /// Initialize network connectivity monitoring
  void _initializeConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final hasConnection = results.contains(ConnectivityResult.mobile) ||
            results.contains(ConnectivityResult.wifi) ||
            results.contains(ConnectivityResult.ethernet);

        // Connection status is now handled by the status provider

        if (!hasConnection && mounted) {
          _showNetworkError();
        }
      },
    );
  }

  /// Initialize real-time relationship listeners for instant updates (OPTIMIZED)
  void _initializeRelationshipListeners() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      debugPrint(
          '❌ NetworkView: No current user ID, cannot initialize listeners');
      return;
    }

    debugPrint(
        '🔄 NetworkView: Initializing real-time listeners for user: $currentUserId');

    Timer? debounceTimer;

    bool _isRelevantFollow(Map<String, dynamic> data) {
      final followerId = data['followerUserId'] ??
          data['followerId'] ??
          data['follower'] ??
          data['follower_id'];
      final targetId = data['targetUserId'] ??
          data['followingId'] ??
          data['followedId'] ??
          data['target_user_id'];
      return followerId == currentUserId || targetId == currentUserId;
    }

    _scopedFollowsSubscription = FirebaseFirestore.instance
        .collection('follows')
        .snapshots()
        .listen((snapshot) {
      final relevantChanges = snapshot.docChanges.where((change) {
        final data = change.doc.data() ?? <String, dynamic>{};
        return _isRelevantFollow(data);
      }).toList();

      if (kDebugMode && relevantChanges.isNotEmpty) {
        debugPrint(
            '🔄 NetworkView: Relevant follows changes: ${relevantChanges.length}');
      }

      if (relevantChanges.isEmpty) return;

      debounceTimer?.cancel();
      debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _refreshDataInstantly();
      });
    }, onError: (error) {
      if (kDebugMode) {
        debugPrint('❌ NetworkView: Error in scoped follows listener: $error');
      }
      final isPermissionDenied =
          error.toString().toLowerCase().contains('permission');
      if (mounted && (!_hasShownPermissionError || !isPermissionDenied)) {
        _hasShownPermissionError =
            _hasShownPermissionError || isPermissionDenied;
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
    });

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
          content:
              const Text('No internet connection. Please check your network.'),
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
          '🔄 NetworkView: Starting to load users from FollowsService...');

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      // Check if migration is needed and run it
      await _runMigrationIfNeeded();

      final followsSvc = FollowsService();

      // Load all three lists in parallel using the correct tab logic
      debugPrint(
          '🔄 NetworkView: Loading connections, followers, and following...');
      final results = await Future.wait([
        followsSvc.getUsersForTab('connections'),
        followsSvc.getUsersForTab('followers'),
        followsSvc.getUsersForTab('following'),
      ]);

      debugPrint(
          '📊 NetworkView: Raw results - Connections: ${results[0].length}, Followers: ${results[1].length}, Following: ${results[2].length}');

      int? followersCountDoc;
      int? followingCountDoc;
      if (currentUserId != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .get();
          final data = userDoc.data();
          followersCountDoc =
              data != null ? data['followersCount'] as int? : null;
          followingCountDoc =
              data != null ? data['followingCount'] as int? : null;
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
          '🎯 NetworkView: Final state - Connections: ${_connectionsUsers.length}, Followers: ${_followersUsers.length}, Following: ${_followingUsers.length}');

      _logDriftIfAny(
        followersCountDoc: followersCountDoc,
        followingCountDoc: followingCountDoc,
      );

      // Debug: Print user details with clear section headers
      debugPrint('🔗 CONNECTIONS (Mutual Follows):');
      for (int i = 0; i < _connectionsUsers.length; i++) {
        debugPrint(
            '  $i: ${_connectionsUsers[i].displayName} (${_connectionsUsers[i].id})');
      }

      debugPrint('👥 FOLLOWERS (They follow you):');
      for (int i = 0; i < _followersUsers.length; i++) {
        debugPrint(
            '  $i: ${_followersUsers[i].displayName} (${_followersUsers[i].id})');
      }

      debugPrint('➡️ FOLLOWING (You follow them):');
      for (int i = 0; i < _followingUsers.length; i++) {
        debugPrint(
            '  $i: ${_followingUsers[i].displayName} (${_followingUsers[i].id})');
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
            content:
                const Text('Failed to load network data. Please try again.'),
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
            '🔄 NetworkView: No follows data found, running migration...');
        final migrationSuccess = await MigrationService.runCompleteMigration();
        if (migrationSuccess) {
          debugPrint('✅ NetworkView: Migration completed successfully');
        } else {
          debugPrint(
              '❌ NetworkView: Migration failed, continuing with empty data');
        }
      } else {
        debugPrint(
            '✅ NetworkView: Follows data already exists, skipping migration');
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
        return user.username
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
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

    const bg = LinearGradient(
      colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return WillPopScope(
      onWillPop: () async {
        debugPrint(
            '🔄 NetworkView: WillPop triggered - resuming HomeView video');
        // 🔊 AUDIO FIX: Unblock playback when returning to HomeView
        // This allows HomeView videos to resume playing
        try {
          final playbackManager = GlobalPlaybackManager.instance;
          playbackManager.unblock();
          // Schedule resume for after the pop completes
          Future.delayed(const Duration(milliseconds: 150), () {
            debugPrint('▶️ NetworkView: Calling resumeAfterTabSwitch()');
            playbackManager.resumeAfterTabSwitch();
          });
        } catch (e) {
          debugPrint('❌ NetworkView: Error resuming video: $e');
        }
        return true; // Allow the pop to proceed
      },
      child: Container(
        decoration: const BoxDecoration(gradient: bg),
        child: SafeArea(
          child: Column(
            children: [
              // Top row with network status, search and sort icons
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // User status indicator - sync with ProfileView
                    Consumer(
                      builder: (context, ref, child) {
                        final statusAsync = ref.watch(statusNotifierProvider);

                        return statusAsync.when(
                          data: (presence) {
                            final statusColor =
                                _getStatusColor(presence.status);
                            final statusText = presence.status.displayName;
                            final statusIcon = _getStatusIcon(presence.status);

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    statusIcon,
                                    color: statusColor,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          loading: () => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.grey),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Loading...',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          error: (error, stack) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error,
                                  color: Colors.red,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Error',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    // Search and sort icons
                    Row(
                      children: [
                        // Manual refresh button
                        GestureDetector(
                          onTap: () {
                            debugPrint('🔄 Manual refresh triggered');
                            _refreshDataInstantly();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.4)),
                            ),
                            child: const Icon(
                              Icons.refresh,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                        ),
                        // Debug button
                        GestureDetector(
                          onTap: () async {
                            debugPrint('🔧 Debug: Testing FollowsService...');
                            final followsSvc = FollowsService();

                            // Test all three tabs
                            final connections =
                                await followsSvc.getUsersForTab('connections');
                            final followers =
                                await followsSvc.getUsersForTab('followers');
                            final following =
                                await followsSvc.getUsersForTab('following');

                            debugPrint('🔧 Debug Results:');
                            debugPrint('  Connections: ${connections.length}');
                            debugPrint('  Followers: ${followers.length}');
                            debugPrint('  Following: ${following.length}');

                            // Show results in UI
                            if (mounted && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Debug: C:${connections.length} F:${followers.length} Fo:${following.length}'),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }

                            // Force refresh
                            _refreshDataInstantly();

                            // Also test the real-time listeners
                            debugPrint(
                                '🔧 Debug: Testing real-time listeners...');
                            _initializeRelationshipListeners();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.4)),
                            ),
                            child: const Icon(
                              Icons.bug_report,
                              color: Colors.orange,
                              size: 20,
                            ),
                          ),
                        ),
                        // Sort button
                        GestureDetector(
                          onTap: _showSortOptions,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.sort,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        // Search button
                        GestureDetector(
                          onTap: _toggleSearch,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              _isSearchVisible ? Icons.close : Icons.search,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Search bar (conditional)
              if (_isSearchVisible) _buildSearchBar(),

              // Tab buttons with swipe functionality
              _buildTabButtons(),

              // Main content area
              Expanded(
                child: _buildMainContent(),
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
        height: 160,
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
        width: 190,
        height: 150,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with gradient when selected
            if (isSelected)
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFF6137EB),
                    Color(0xFF1C135D),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Icon(
                  icon,
                  size: 40,
                  color: Colors.white,
                ),
              )
            else
              Icon(
                icon,
                size: 40,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.7),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
    debugPrint(
        '🎯 NetworkView: _buildMainContent - currentList.length: ${currentList.length}');
    debugPrint(
        '🎯 NetworkView: _buildMainContent - _selectedTab: $_selectedTab');
    debugPrint(
        '🎯 NetworkView: _buildMainContent - _connectionsUsers.length: ${_connectionsUsers.length}');
    debugPrint(
        '🎯 NetworkView: _buildMainContent - _followersUsers.length: ${_followersUsers.length}');
    debugPrint(
        '🎯 NetworkView: _buildMainContent - _followingUsers.length: ${_followingUsers.length}');

    if (currentList.isEmpty) {
      debugPrint('⚠️ NetworkView: currentList is empty, showing empty state');
      return _buildEmptyState();
    }

    debugPrint(
        '✅ NetworkView: Building ListView with ${currentList.length} users');
    return RefreshIndicator(
      onRefresh: _handlePullToRefresh,
      color: Colors.white,
      child: ListView.builder(
        controller: _listController,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: currentList.length,
        itemBuilder: (context, index) {
          final user = currentList[index];
          debugPrint(
              '🔨 NetworkView: Building user card $index: ${user.displayName} (${user.id})');
          return _buildUserCard(user); // User cards now match search bar width
        },
      ),
    );
  }

  void _navigateToStreamerCard(user_model.User user) {
    debugPrint(
        '🔵 NetworkView: _navigateToStreamerCard called for user: ${user.displayName}');
    debugPrint('🔵 NetworkView: User ID being passed: ${user.id}');
    debugPrint('🔵 NetworkView: User username: ${user.username}');
    debugPrint('🔵 NetworkView: User displayName: ${user.displayName}');

    Future.microtask(() async {
      if (mounted) {
        final userId = await _resolveUserDocumentId(user);
        debugPrint(
            '🔵 NetworkView: Resolved userId for StreamerCardView: $userId');
        if (userId == null) {
          debugPrint(
              '❌ NetworkView: Unable to resolve user document for ${user.displayName} (${user.username})');
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

        // Force the app to stay in foreground with multiple approaches
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

        // Use push instead of pushReplacement to maintain navigation stack
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StreamerCardView(
              userId: userId,
              currentUserId: FirebaseAuth.instance.currentUser?.uid,
              onDismiss: () => Navigator.of(context).pop(),
              onFollow: (userId) async {
                // Handle follow action - just refresh data since StreamerCardView handles the actual follow
                HapticFeedback.lightImpact();
                debugPrint(
                    '🔵 NetworkView: Follow action triggered for user: $userId - refreshing data');

                // Just refresh the data to reflect any changes made by StreamerCardView
                _refreshDataInstantly();
              },
              onMessage: (userId) {
                // Handle message action
                HapticFeedback.lightImpact();
                debugPrint(
                    '🔵 NetworkView: Message action triggered for user: $userId');
                // The StreamerCardView will handle the actual messaging logic
                // This callback is just for tracking/logging purposes
              },
              onShare: (userId) {
                // Handle share action
                HapticFeedback.lightImpact();
                debugPrint(
                    '🔵 NetworkView: Share action triggered for user: $userId');
                // Share functionality implementation
                // This would involve sharing user profile or content
                // Currently not implemented - would require share service integration
              },
              onNavigateToTab: (tabName) {
                // Handle tab navigation from StreamerCardView
                HapticFeedback.lightImpact();
                debugPrint(
                    '🔵 NetworkView: Tab navigation requested: $tabName');
                _navigateToTab(tabName);

                // Close the StreamerCardView and return to NetworkView
                Navigator.of(context).pop();
              },
            ),
          ),
        );
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
    debugPrint(
        '🎨 NetworkView: _buildUserCard called for user: ${user.displayName} (${user.id})');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey('network_user_${user.id}_${_selectedTab.name}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _handleSwipeAction(user),
        background: _buildSwipeBackground(),
        child: GestureDetector(
          onTap: () {
            debugPrint(
                '🔵 NetworkView: User card tapped for user: ${user.displayName}');
            HapticFeedback.lightImpact();
            _navigateToStreamerCard(user);
          },
          child: Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  StatusAwareAvatar(
                    userId: user.id,
                    avatarURL: user.avatarURL,
                    radius: 20,
                    showOnlineIndicator: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                        const SizedBox(height: 2),
                        Text(
                          '@${user.username}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 20,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 20),
          Text(
            _selectedTab == network_models.NetworkTab.followers
                ? 'No followers yet'
                : _selectedTab == network_models.NetworkTab.following
                    ? 'You are not following anyone'
                    : 'No connections yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedTab == network_models.NetworkTab.followers
                ? 'Share your profile to grow your audience.'
                : _selectedTab == network_models.NetworkTab.following
                    ? 'Discover people to follow from Home or Search.'
                    : 'Follow back people who follow you to connect.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshDataInstantly,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
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
                ],
              ),
            ),
            const SizedBox(width: 12),
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
        color: Colors.red.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, color: Colors.white),
          SizedBox(width: 8),
          Icon(Icons.delete_forever, color: Colors.white),
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
            '⚠️ No follower docs found to remove for ${user.id}, skipping.');
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
          "🔵 NetworkView: Navigating to tab: $tabName (${targetTab.name})");
    }

    _selectTab(targetTab);

    // Also refresh data to show the updated relationships
    _refreshDataInstantly();
  }

  void _nextTab() {
    setState(() {
      switch (_selectedTab) {
        case network_models.NetworkTab.connections:
          _selectedTab = network_models.NetworkTab.followers;
          break;
        case network_models.NetworkTab.followers:
          _selectedTab = network_models.NetworkTab.following;
          break;
        case network_models.NetworkTab.following:
          _selectedTab = network_models.NetworkTab.connections;
          break;
      }
    });
  }

  void _previousTab() {
    setState(() {
      switch (_selectedTab) {
        case network_models.NetworkTab.connections:
          _selectedTab = network_models.NetworkTab.following;
          break;
        case network_models.NetworkTab.followers:
          _selectedTab = network_models.NetworkTab.connections;
          break;
        case network_models.NetworkTab.following:
          _selectedTab = network_models.NetworkTab.followers;
          break;
      }
    });
  }

  /// Refresh data instantly without showing loading indicator
  Future<void> _refreshDataInstantly() async {
    try {
      debugPrint('🔄 NetworkView: Starting instant data refresh...');
      final followsSvc = FollowsService();

      // Load all three lists in parallel using the correct tab logic
      debugPrint(
          '🔄 NetworkView: Loading connections, followers, and following...');
      final results = await Future.wait([
        followsSvc.getUsersForTab('connections'),
        followsSvc.getUsersForTab('followers'),
        followsSvc.getUsersForTab('following'),
      ]);

      debugPrint(
          '📊 NetworkView: Data loaded - Connections: ${results[0].length}, Followers: ${results[1].length}, Following: ${results[2].length}');

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
