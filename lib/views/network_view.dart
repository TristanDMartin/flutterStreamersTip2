import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../models/user_model.dart' as user_model;
import '../models/network_models.dart' as network_models;
import '../services/clean_relationship_service.dart';
import '../services/performance_monitoring_service.dart';
import '../services/network_analytics_service.dart';
import '../widgets/streamer_card_view.dart';

class NetworkView extends StatefulWidget {
  const NetworkView({super.key});

  @override
  State<NetworkView> createState() => _NetworkViewState();
}

class _NetworkViewState extends State<NetworkView> {
  network_models.NetworkTab _selectedTab = network_models.NetworkTab.connections;
  final ScrollController _listController = ScrollController();
  
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
  
  // Clean relationship service data
  List<user_model.User> _connectionsUsers = [];
  List<user_model.User> _followersUsers = [];
  List<user_model.User> _followingUsers = [];
  bool _isLoadingUsers = false;
  
  // Network connectivity
  bool _hasInternetConnection = true;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  // Real-time relationship listeners
  StreamSubscription<QuerySnapshot>? _relationshipsSubscription;

  @override
  void initState() {
    super.initState();
    
    // Set up global error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      try {
        NetworkAnalyticsService.trackError('flutter_error', details.exception.toString());
      } catch (e) {
        debugPrint('❌ Error tracking error: $e');
      }
    };
    
    // Initialize performance monitoring
    PerformanceMonitoringService().startMonitoring();
    
    // Initialize network connectivity monitoring
    _initializeConnectivityMonitoring();
    
    // Initialize real-time relationship listeners
    _initializeRelationshipListeners();
    
    // Load users from clean relationship service
    _loadUsersFromCleanService();
  }
  
  /// Initialize network connectivity monitoring
  void _initializeConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (ConnectivityResult result) {
        final hasConnection = result == ConnectivityResult.mobile || 
                             result == ConnectivityResult.wifi ||
                             result == ConnectivityResult.ethernet;
        
        if (mounted) {
          setState(() {
            _hasInternetConnection = hasConnection;
          });
        }
        
        if (!hasConnection && mounted) {
          _showNetworkError();
        }
      },
    );
  }

  /// Initialize real-time relationship listeners for instant updates (OPTIMIZED)
  void _initializeRelationshipListeners() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // Use a more efficient listener with debouncing to prevent excessive refreshes
    Timer? _debounceTimer;
    _relationshipsSubscription = FirebaseFirestore.instance
        .collection('relationships')
        .where('followerId', isEqualTo: currentUserId)
        .snapshots()
        .listen((snapshot) {
      // Only refresh if there are actual changes
      if (snapshot.docChanges.isNotEmpty) {
        // Debounce to prevent excessive calls
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 500), () {
          _refreshDataInstantly();
        });
      }
    });
  }
  
  /// Check network connectivity before API calls
  Future<bool> _checkNetworkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult == ConnectivityResult.mobile || 
                           connectivityResult == ConnectivityResult.wifi ||
                           connectivityResult == ConnectivityResult.ethernet;
      
      if (mounted) {
        setState(() {
          _hasInternetConnection = hasConnection;
        });
      }
      
      return hasConnection;
    } catch (e) {
      print('Connectivity check error: $e');
      return false;
    }
  }
  
  /// Show network error message
  void _showNetworkError() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No internet connection. Please check your network.'),
          backgroundColor: Colors.orange.withValues(alpha: 0.8),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              _loadUsersFromCleanService();
            },
          ),
        ),
      );
    }
  }

  /// Load users from clean relationship service
  Future<void> _loadUsersFromCleanService() async {
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
      final cleanSvc = CleanRelationshipService();
      
      // Ensure service is initialized before loading data
      await cleanSvc.initialize();
      
      // Load all three lists in parallel
      final results = await Future.wait([
        cleanSvc.getUsersForSection('connections'),
        cleanSvc.getUsersForSection('followers'),
        cleanSvc.getUsersForSection('following'),
      ]);
      
      setState(() {
        _connectionsUsers = results[0];
        _followersUsers = results[1];
        _followingUsers = results[2];
        _isLoadingUsers = false;
      });
    } catch (e) {
      print('Error loading users from clean service: $e');
      setState(() {
        _isLoadingUsers = false;
      });
      
      // Show user-friendly error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load network data. Please try again.'),
            backgroundColor: Colors.red.withValues(alpha: 0.8),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadUsersFromCleanService,
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    PerformanceMonitoringService().stopMonitoring();
    _listController.dispose();
    _searchController.dispose();
    _searchTimer?.cancel(); // Cancel search timer
    _connectivitySubscription?.cancel(); // Cancel connectivity subscription
    _relationshipsSubscription?.cancel(); // Cancel relationship listeners
    super.dispose();
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
        return user.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
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
      print('Search error: $e');
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
    switch (_selectedTab) {
      case network_models.NetworkTab.connections:
        users = _connectionsUsers;
        break;
      case network_models.NetworkTab.followers:
        users = _followersUsers;
        break;
      case network_models.NetworkTab.following:
        users = _followingUsers;
        break;
    }
    
    return _sortUsers(users);
  }
  
  List<user_model.User> _sortUsers(List<user_model.User> users) {
    users.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison = a.displayName.compareTo(b.displayName);
          break;
        case 'followers':
          comparison = a.followerCount.compareTo(b.followerCount);
          break;
      }
      
      return _sortAscending ? comparison : -comparison;
    });
    
    return users;
  }

  @override
  Widget build(BuildContext context) {
    const bg = LinearGradient(
      colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      decoration: const BoxDecoration(gradient: bg),
      child: SafeArea(
        child: Column(
          children: [
            // Top row with network status, search and sort icons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Network connectivity indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _hasInternetConnection 
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _hasInternetConnection 
                            ? Colors.green.withValues(alpha: 0.4)
                            : Colors.red.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _hasInternetConnection ? Icons.wifi : Icons.wifi_off,
                          color: _hasInternetConnection ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _hasInternetConnection ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: _hasInternetConnection ? Colors.green : Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Search and sort icons
                  Row(
                    children: [
                  // Sort button
                  GestureDetector(
                    onTap: _showSortOptions,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha:0.2),
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
                        color: Colors.white.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha:0.2),
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
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: Colors.white.withValues(alpha:0.2),
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
              color: Colors.white.withValues(alpha:0.6),
              fontSize: 16,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.white.withValues(alpha:0.6),
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
              ? Colors.white.withValues(alpha:0.2)
              : Colors.white.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha:0.4)
                : Colors.white.withValues(alpha:0.2),
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
                color: Colors.white.withValues(alpha:0.7),
              ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withValues(alpha:0.7),
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withValues(alpha:0.7),
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
      return const Center(
        child: const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    final currentList = _currentList();
    
    if (currentList.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadUsersFromCleanService,
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

  Widget _buildUserCard(user_model.User user) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: StreamerCardView(
        userId: user.id,
        currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
        onFollow: _handleFollowAction, // Add callback for instant updates
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
            color: Colors.white.withValues(alpha:0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'No users found',
            style: TextStyle(
              color: Colors.white.withValues(alpha:0.7),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or check back later',
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

  void _selectTab(network_models.NetworkTab tab) {
    setState(() {
      _selectedTab = tab;
    });
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

  /// Handle follow/unfollow actions from StreamerCardView for instant updates
  void _handleFollowAction(String userId) {
    // Refresh data instantly after follow/unfollow action
    _refreshDataInstantly();
    
    // Also refresh the CleanRelationshipService state
    _refreshCleanServiceState();
  }

  /// Refresh data instantly without showing loading indicator
  Future<void> _refreshDataInstantly() async {
    try {
      final cleanSvc = CleanRelationshipService();
      
      // Ensure service is initialized
      await cleanSvc.initialize();
      
      // Load all three lists in parallel
      final results = await Future.wait([
        cleanSvc.getUsersForSection('connections'),
        cleanSvc.getUsersForSection('followers'),
        cleanSvc.getUsersForSection('following'),
      ]);
      
      if (mounted) {
        setState(() {
          _connectionsUsers = results[0];
          _followersUsers = results[1];
          _followingUsers = results[2];
        });
      }
    } catch (e) {
      print('Error refreshing data instantly: $e');
    }
  }

  /// Refresh the CleanRelationshipService state to get latest data
  Future<void> _refreshCleanServiceState() async {
    try {
      final cleanSvc = CleanRelationshipService();
      await cleanSvc.refresh(); // Refresh the service's internal state
    } catch (e) {
      print('Error refreshing clean service state: $e');
    }
  }
}
