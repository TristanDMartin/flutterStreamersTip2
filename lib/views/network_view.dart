import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  
  // Sort options
  String _sortBy = 'name';
  bool _sortAscending = true;
  
  // Clean relationship service data
  List<user_model.User> _connectionsUsers = [];
  List<user_model.User> _followersUsers = [];
  List<user_model.User> _followingUsers = [];
  bool _isLoadingUsers = false;

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
    
    // Load users from clean relationship service
    _loadUsersFromCleanService();
  }
  
  /// Load users from clean relationship service
  Future<void> _loadUsersFromCleanService() async {
    setState(() {
      _isLoadingUsers = true;
    });
    
    try {
      final cleanSvc = CleanRelationshipService();
      
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
    }
  }

  @override
  void dispose() {
    PerformanceMonitoringService().stopMonitoring();
    _listController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
    _performSearch();
  }

  Future<void> _performSearch() async {
    if (_searchQuery.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    final allUsers = _getAllUsersForSearch();
    final results = allUsers.where((user) {
      return user.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             user.displayName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
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
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchController.clear();
        _searchQuery = '';
        _searchResults = [];
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
      colors: [
        Color(0xFF9248D2), // Purple
        Color(0xFF7768DF), // Another purple
        Color(0xFF1670DE), // Blue
        Color(0xFF3C8BD6), // Lighter blue
        Color(0xFF4897D2), // Lightest blue
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    return Container(
      decoration: const BoxDecoration(gradient: bg),
      child: SafeArea(
        child: Column(
          children: [
            // Top row with search and sort icons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
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
        if (details.primaryVelocity! > 0) {
          _previousTab();
        } else if (details.primaryVelocity! < 0) {
          _nextTab();
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
                    Color(0xFF9248D2), // Purple
                    Color(0xFF7768DF), // Another purple
                    Color(0xFF1670DE), // Blue
                    Color(0xFF3C8BD6), // Lighter blue
                    Color(0xFF4897D2), // Lightest blue
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
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
        ),
      );
    }

    final currentList = _currentList();
    
    if (currentList.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadUsersFromCleanService,
      color: const Color(0xFF9248D2),
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
        currentUserId: FirebaseAuth.instance.currentUser?.uid,
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
}
