import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';
import 'favorites_manager.dart';
import '../models/user.dart';

import '../providers/home_provider.dart';

class DataSyncService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthenticationService _authService;
  final FavoritesManager _favoritesManager;
  final HomeViewModel _homeNotifier;
  
  StreamSubscription<DocumentSnapshot>? _profileSub;
  StreamSubscription<QuerySnapshot>? _followingSub;
  StreamSubscription<QuerySnapshot>? _favoritesSub;

  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;
  
  // Getters
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;
  
  DataSyncService({
    required AuthenticationService authService,
    required FavoritesManager favoritesManager,
    required HomeViewModel homeNotifier,
  }) : _authService = authService,
       _favoritesManager = favoritesManager,
       _homeNotifier = homeNotifier;
  
  // Main data synchronization method
  Future<void> syncUserData() async {
    if (_isLoading || _hasLoaded) return;
    
    // print("🔄 Starting comprehensive data synchronization");
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }
      
    // print("👤 Syncing data for user: ${user.displayName} (${user.id})");
      
      // 1. Load user profile data (already handled by AuthService)
      await _loadUserProfileData(user);
      
      // 2. Load relationship data (following/followers)
      await _loadRelationshipData(user.id);
      
      // 3. Load video data
      await _loadVideoData();
      
      // 4. Load favorites
      await _loadFavorites(user.id);
      
      // 5. Sync video states (likes, comments, etc.)
      await _syncVideoStates();
      
      // 6. Set up real-time listeners
      _setupRealtimeListeners(user.id);
      
      _hasLoaded = true;
    // print("✅ Data synchronization completed successfully");
      
    } catch (e) {
      _errorMessage = e.toString();
    // print("❌ Data synchronization failed: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Load user profile data
  Future<void> _loadUserProfileData(User user) async {
    // print("📄 Loading user profile data");
    try {
      final userDoc = await _firestore.collection('users').doc(user.id).get();
      if (userDoc.exists) {
        // final data = userDoc.data()!;
    // print("✅ User profile data loaded: ${data['displayName']}");
      }
    } catch (e) {
    // print("❌ Error loading user profile: $e");
    }
  }
  
  // Load relationship data (following/followers)
  Future<void> _loadRelationshipData(String userId) async {
    // print("👥 Loading relationship data");
    try {
      // Load following
      // final followingQuery = await _firestore
      //     .collection('users')
      //     .doc(userId)
      //     .collection('following')
      //     .get();
      
      // final followingIds = followingQuery.docs.map((doc) => doc.id).toList();
    // print("👥 Following ${followingIds.length} users");
      
      // Load followers
      // final followersQuery = await _firestore
      //     .collection('users')
      //     .doc(userId)
      //     .collection('followers')
      //     .get();
      
      // final followerIds = followersQuery.docs.map((doc) => doc.id).toList();
    // print("👥 ${followerIds.length} followers");
      
    } catch (e) {
    // print("❌ Error loading relationship data: $e");
    }
  }
  
  // Load video data
  Future<void> _loadVideoData() async {
    // print("🎥 Loading video data");
    try {
      // Load For You videos
      await _homeNotifier.fetchForYouVideos(reset: true);
      
      // Load Following videos
      final user = _authService.currentUser;
      if (user != null) {
        // Get following IDs from relationship data
        final followingQuery = await _firestore
            .collection('users')
            .doc(user.id)
            .collection('following')
            .get();
        
        final followingIds = followingQuery.docs.map((doc) => doc.id).toList();
        await _homeNotifier.fetchFollowingVideos(followingIds: followingIds, reset: true);
      }
      
    // print("✅ Video data loaded");
    } catch (e) {
    // print("❌ Error loading video data: $e");
    }
  }
  
  // Load user favorites
  Future<void> _loadFavorites(String userId) async {
    // print("❤️ Loading user favorites");
    try {
      await _favoritesManager.initialize();
    // print("✅ Favorites loaded");
    } catch (e) {
    // print("❌ Error loading favorites: $e");
    }
  }
  
  // Sync video states (likes, comments, etc.)
  Future<void> _syncVideoStates() async {
    // print("🔄 Syncing video states");
    try {
      await _homeNotifier.syncLikeStates();
      await _homeNotifier.syncFavoriteStates();
      await _homeNotifier.syncCommentCounts();
    // print("✅ Video states synced");
    } catch (e) {
    // print("❌ Error syncing video states: $e");
    }
  }
  
  // Set up real-time listeners
  void _setupRealtimeListeners(String userId) {
    _profileSub?.cancel();
    _followingSub?.cancel();
    _favoritesSub?.cancel();

    _profileSub = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      // AuthService already handles profile sync — no-op here.
    });

    _followingSub = _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .snapshots()
        .listen((_) => _refreshFollowingVideos());

    _favoritesSub = _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .snapshots()
        .listen((_) => _favoritesManager.initialize());
  }
  
  // Refresh following videos
  Future<void> _refreshFollowingVideos() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final followingQuery = await _firestore
            .collection('users')
            .doc(user.id)
            .collection('following')
            .get();
        
        final followingIds = followingQuery.docs.map((doc) => doc.id).toList();
        await _homeNotifier.fetchFollowingVideos(followingIds: followingIds, reset: true);
      }
    } catch (e) {
    // print("❌ Error refreshing following videos: $e");
    }
  }
  
  // Force refresh all data
  Future<void> refreshAllData() async {
    // print("🔄 Force refreshing all data");
    _hasLoaded = false;
    await syncUserData();
  }
  
  // Reset sync state (for logout)
  void resetSyncState() {
    _isLoading = false;
    _hasLoaded = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _followingSub?.cancel();
    _favoritesSub?.cancel();
    super.dispose();
  }
}

// Provider for DataSyncService
final dataSyncServiceProvider = ChangeNotifierProvider<DataSyncService>((ref) {
  final authService = ref.watch(authServiceProvider);
  final favoritesManager = ref.watch(favoritesManagerProvider);
  final homeNotifier = ref.watch(homeProvider.notifier);
  
  return DataSyncService(
    authService: authService,
    favoritesManager: favoritesManager,
    homeNotifier: homeNotifier,
  );
});
