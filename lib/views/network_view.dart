import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
// import '../widgets/app_bottom_nav.dart'; // Removed - using main_tab_view navigation
import '../models/user.dart';
import 'streamer_card_page.dart';
import '../services/network_analytics_service.dart';

/// ======== MODELS (swap with your real ones) ========

enum NetworkTab { connections, followers, following }

// Use OnlineStatus and helpers from models/online_status.dart

// AppUser now lives in models/app_user.dart

/// ======== RELATIONSHIP SERVICE (placeholder) ========
/// Replace with your real RelationshipService (ChangeNotifier/Riverpod/etc.)
class RelationshipService extends ChangeNotifier {
  List<User> connections = [];
  List<User> followers = [];
  List<User> following = [];

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fa.FirebaseAuth _auth = fa.FirebaseAuth.instance;

  StreamSubscription? _followersSub;
  StreamSubscription? _followingSub;

  Future<void> bindLive() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _followersSub?.cancel();
    await _followingSub?.cancel();

    _followersSub = _db
        .collection('relationships')
        .where('followingId', isEqualTo: uid)
        .snapshots()
        .listen((snap) async {
      final ids = snap.docs.map((d) => d.data()['followerId'] as String).toList();
      followers = await _fetchUsers(ids);
      _recomputeConnections();
      notifyListeners();
    });

    _followingSub = _db
        .collection('relationships')
        .where('followerId', isEqualTo: uid)
        .snapshots()
        .listen((snap) async {
      final ids = snap.docs.map((d) => d.data()['followingId'] as String).toList();
      following = await _fetchUsers(ids);
      _recomputeConnections();
      notifyListeners();
    });
  }

  Future<List<User>> _fetchUsers(List<String> ids) async {
    if (ids.isEmpty) return [];
    const int batchSize = 10;
    final List<User> result = [];
    for (int i = 0; i < ids.length; i += batchSize) {
      final batch = ids.sublist(i, (i + batchSize).clamp(0, ids.length));
      final q = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in q.docs) {
        result.add(_mapUser(doc.id, doc.data()));
      }
    }
    return result;
  }

  User _mapUser(String id, Map<String, dynamic> data) {
    return User(
      id: id,
      displayName: (data['displayName'] ?? 'User').toString(),
      username: (data['username'] ?? 'user').toString(),
      avatarURL: data['avatarURL'] as String?,
      onlineStatus: (data['onlineStatus'] ?? 'offline').toString(),
      hashtags: List<String>.from(data['hashtags'] ?? []),
      aiSelf: data['aiSelf']?.toString() ?? '',
      postCount: data['postCount'] ?? 0,
      followerCount: data['followerCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
      calendarEvents: [],
    );
  }

  void _recomputeConnections() {
    final followingIds = following.map((e) => e.id).toSet();
    final followerIds = followers.map((e) => e.id).toSet();
    final mutual = followingIds.intersection(followerIds);
    
    // Connections: Mutual follows (both users follow each other)
    connections = [
      for (final id in mutual)
        following.firstWhere(
          (u) => u.id == id,
          orElse: () => followers.firstWhere((u) => u.id == id, orElse: () => User(id: id, displayName: 'User', username: 'user')),
        )
    ];
  }

  // Get non-mutual followers only (excluding connections)
  List<User> get nonMutualFollowers {
    final connectionIds = connections.map((e) => e.id).toSet();
    return followers.where((user) => !connectionIds.contains(user.id)).toList();
  }

  // Get non-mutual following only (excluding connections)
  List<User> get nonMutualFollowing {
    final connectionIds = connections.map((e) => e.id).toSet();
    return following.where((user) => !connectionIds.contains(user.id)).toList();
  }

  Future<void> unfollowUser(User u) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    try {
      // 1. Find relationship document
      final snap = await _db
          .collection('relationships')
          .where('followerId', isEqualTo: uid)
          .where('followingId', isEqualTo: u.id)
          .get();
      
      if (snap.docs.isEmpty) {
        print('🔍 RelationshipService: Not following user ${u.id}');
        return; // Not following
      }
      
      // 2. Delete relationship from Firestore
      for (final d in snap.docs) {
        await d.reference.delete();
      }
      
      // 3. Update follower count (decrement)
      await _updateFollowerCount(u.id, -1);
      await _updateFollowingCount(uid, -1);
      
      // 4. Remove follow notification
      await _removeFollowNotification(uid, u.id);
      
      // 5. Real-time listeners update UI (handled by Firestore listeners)
      print('✅ RelationshipService: Successfully unfollowed user ${u.id}');
      
    } catch (e) {
      print('❌ RelationshipService: Error unfollowing user ${u.id}: $e');
      rethrow;
    }
  }

  Future<void> removeFollower(User u) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    try {
      // 1. Find relationship document (reverse direction)
      final snap = await _db
          .collection('relationships')
          .where('followerId', isEqualTo: u.id)
          .where('followingId', isEqualTo: uid)
          .get();
      
      if (snap.docs.isEmpty) {
        print('🔍 RelationshipService: User ${u.id} is not following current user');
        return; // Not a follower
      }
      
      // 2. Delete relationship from Firestore
      for (final d in snap.docs) {
        await d.reference.delete();
      }
      
      // 3. Update follower count (decrement)
      await _updateFollowerCount(uid, -1);
      await _updateFollowingCount(u.id, -1);
      
      // 4. Real-time listeners update UI (handled by Firestore listeners)
      print('✅ RelationshipService: Successfully removed follower ${u.id}');
      
    } catch (e) {
      print('❌ RelationshipService: Error removing follower ${u.id}: $e');
      rethrow;
    }
  }

  Future<void> createSampleRelationships() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    try {
      // Create sample users first if they don't exist
      final sampleUsers = [
        {
          'id': 'user1',
          'username': 'gamer_girl',
          'displayName': 'Gamer Girl',
          'bio': 'Professional gamer',
        },
        {
          'id': 'user2',
          'username': 'art_streamer',
          'displayName': 'Art Streamer',
          'bio': 'Digital artist',
        },
        {
          'id': 'user3',
          'username': 'music_lover',
          'displayName': 'Music Lover',
          'bio': 'Music enthusiast',
        },
      ];
      
      for (final userData in sampleUsers) {
        final userId = userData['id']!;
        final userRef = _db.collection('users').doc(userId);
        
        await userRef.set({
          'id': userId,
          'username': userData['username']!,
          'displayName': userData['displayName']!,
          'bio': userData['bio']!,
          'onlineStatus': 'online',
          'followerCount': 0,
          'followingCount': 0,
          'postCount': 0,
          'hashtags': [],
          'aiSelf': '',
          'calendarEvents': [],
        }, SetOptions(merge: true));
      }
      
      // Create sample relationships
      final relationships = [
        {'followerId': uid, 'followingId': 'user1'}, // Current user follows user1
        {'followerId': 'user1', 'followingId': uid}, // user1 follows current user (mutual)
        {'followerId': 'user2', 'followingId': uid}, // user2 follows current user (follower only)
        {'followerId': uid, 'followingId': 'user3'}, // Current user follows user3 (following only)
      ];
      
      for (final relationshipData in relationships) {
        await _db.collection('relationships').add({
          'followerId': relationshipData['followerId']!,
          'followingId': relationshipData['followingId']!,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      
      print('✅ Created sample relationships for testing');
      
    } catch (e) {
      print('❌ Error creating sample relationships: $e');
    }
    
    await bindLive();
  }

  Future<void> followUser(String userId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid == userId) return;
    
    try {
      // 1. Check if already following
      final existing = await _db
          .collection('relationships')
          .where('followerId', isEqualTo: uid)
          .where('followingId', isEqualTo: userId)
          .get();
      
      if (existing.docs.isNotEmpty) {
        print('🔍 RelationshipService: Already following user $userId');
        return; // Already following
      }
      
      // 2. Create relationship document in Firestore
      await _db.collection('relationships').add({
        'followerId': uid,
        'followingId': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // 3. Update follower count
      await _updateFollowerCount(userId, 1);
      await _updateFollowingCount(uid, 1);
      
      // 4. Create follow notification
      await _createFollowNotification(uid, userId);
      
      print('✅ RelationshipService: Successfully followed user $userId');
      
      // Track analytics
      await NetworkAnalyticsService.trackFollow(userId, 'User');
      
    } catch (e) {
      print('❌ RelationshipService: Error following user $userId: $e');
      await NetworkAnalyticsService.trackError('follow_error', e.toString());
      rethrow;
    }
  }

  Future<void> _updateFollowerCount(String userId, int increment) async {
    try {
      await _db.collection('users').doc(userId).update({
        'followerCount': FieldValue.increment(increment),
      });
    } catch (e) {
      print('❌ Error updating follower count: $e');
    }
  }

  Future<void> _updateFollowingCount(String userId, int increment) async {
    try {
      await _db.collection('users').doc(userId).update({
        'followingCount': FieldValue.increment(increment),
      });
    } catch (e) {
      print('❌ Error updating following count: $e');
    }
  }

  Future<void> _createFollowNotification(String followerId, String followingId) async {
    try {
      // Get follower info
      final followerDoc = await _db.collection('users').doc(followerId).get();
      final followerData = followerDoc.data();
      
      if (followerData != null) {
        await _db.collection('notifications').add({
          'userId': followingId,
          'type': 'follow',
          'fromUserId': followerId,
          'fromUserName': followerData['displayName'] ?? 'Someone',
          'message': '${followerData['displayName'] ?? 'Someone'} started following you',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
        print('✅ Created follow notification for user $followingId');
      }
    } catch (e) {
      print('❌ Error creating follow notification: $e');
    }
  }

  Future<void> _removeFollowNotification(String followerId, String followingId) async {
    try {
      // Remove follow notification if it exists
      final notificationQuery = await _db
          .collection('notifications')
          .where('userId', isEqualTo: followingId)
          .where('type', isEqualTo: 'follow')
          .where('fromUserId', isEqualTo: followerId)
          .get();
      
      for (final doc in notificationQuery.docs) {
        await doc.reference.delete();
      }
      print('✅ Removed follow notification for user $followingId');
    } catch (e) {
      print('❌ Error removing follow notification: $e');
    }
  }
}

/// ======== VIEW MODEL (ChangeNotifier) ========
/// Mirrors your SwiftUI NetworkViewModel
class NetworkViewModel extends ChangeNotifier {
  List<User> connections = [];
  List<User> followers = [];
  List<User> following = [];
  List<User> suggested = [];
  bool isLoading = false;

  RelationshipService? _relationshipService;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _suggestionTimer;

  void setupRelationshipService(RelationshipService svc) {
    _relationshipService = svc;

    // initial bind
    connections = svc.connections;
    followers = svc.followers;
    following = svc.following;

    // listen for changes
    svc.addListener(_pullFromService);
    _logInit();
    notifyListeners();
  }

  void _pullFromService() {
    if (_relationshipService == null) return;
    connections = _relationshipService!.connections;
    followers = _relationshipService!.followers;
    following = _relationshipService!.following;
    notifyListeners();
  }

  Future<void> loadAll() async {
    isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    suggested = List.generate(
      8,
      (i) => User(id: 's$i', displayName: 'Suggested $i', username: 'sugg$i'),
    );
    isLoading = false;
    notifyListeners();
  }

  Future<void> refreshData() async {
    if ((followers.isEmpty && following.isEmpty) && _relationshipService != null) {
      await _relationshipService!.createSampleRelationships();
    }
    notifyListeners();
  }

  void loadSuggestionsIfNeeded() {
    if (DateTime.now().difference(_lastTap) <= const Duration(milliseconds: 300)) return;
    _lastTap = DateTime.now();

    _suggestionTimer?.cancel();
    _suggestionTimer = Timer(const Duration(milliseconds: 1), () async {
      await Future.delayed(const Duration(milliseconds: 200));
      suggested.shuffle();
      notifyListeners();
    });
  }

  Future<void> unfollowUser(User u) async {
    await _relationshipService?.unfollowUser(u);
    notifyListeners();
  }

  Future<void> removeFollower(User u) async {
    await _relationshipService?.removeFollower(u);
    notifyListeners();
  }

  void disposeListeners() {
    _relationshipService?.removeListener(_pullFromService);
  }

  void _logInit() {}
}

/// ======== UI WIDGETS ========

class NetworkCardButton extends StatelessWidget {
  final String iconName;
  final IconData icon;
  final String title;
  final int count;
  final VoidCallback action;
  final bool isSelected;

  const NetworkCardButton({
    super.key,
    required this.iconName,
    required this.icon,
    required this.title,
    required this.count,
    required this.action,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    const selectedGradient = LinearGradient(
      colors: [
        Color(0xFF9248d2),
        Color(0xFF7768df),
        Color(0xFF1670de),
        Color(0xFF3c8bd6),
        Color(0xFF4897d2),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final cardGlass = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.30),
          Colors.white.withOpacity(0.15),
          Colors.white.withOpacity(0.08),
          Colors.white.withOpacity(0.02),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(color: Colors.white.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 6)),
        BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 8, offset: const Offset(0, 4)),
      ],
      border: Border.all(
        width: 2,
        color: Colors.white.withOpacity(0.25),
      ),
    );

    Widget iconWidget = Icon(icon, size: 28, color: Colors.white);
    if (isSelected) {
      iconWidget = ShaderMask(
        shaderCallback: (Rect bounds) => selectedGradient.createShader(bounds),
        child: Icon(icon, size: 28, color: Colors.white),
      );
    }

    return TextButton(
      onPressed: action,
      style: TextButton.styleFrom(padding: EdgeInsets.zero),
      child: Container(
        width: 140,
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: cardGlass,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Center(child: iconWidget),
            const SizedBox(height: 8),
            Center(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Text(
                  '$count',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NetworkView extends StatefulWidget {
  final NetworkViewModel vm;
  final RelationshipService relationshipService;

  const NetworkView({
    super.key,
    required this.vm,
    required this.relationshipService,
  });

  @override
  State<NetworkView> createState() => _NetworkViewState();
}

class _NetworkViewState extends State<NetworkView> {
  NetworkTab _selectedTab = NetworkTab.connections;
  double _dragOffset = 0;
  final ScrollController _listController = ScrollController();
  
  // Performance optimizations
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    widget.vm.setupRelationshipService(widget.relationshipService);
    _listController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.vm.loadAll();
      widget.vm.loadSuggestionsIfNeeded();
    });
  }

  void _onScroll() {
    if (_listController.position.pixels >= _listController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  void _loadMoreData() {
    if (_isLoadingMore || !_hasMoreData) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    // Simulate loading more data
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          // In a real implementation, you would load more data from Firestore here
        });
      }
    });
  }

  @override
  void dispose() {
    widget.vm.disposeListeners();
    _listController.dispose();
    super.dispose();
  }

  List<User> get _currentList {
    final svc = widget.relationshipService;
    switch (_selectedTab) {
      case NetworkTab.connections:
        return svc.connections;
      case NetworkTab.followers:
        return svc.nonMutualFollowers;
      case NetworkTab.following:
        return svc.nonMutualFollowing;
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = LinearGradient(
      colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return AnimatedBuilder(
      animation: widget.relationshipService,
      builder: (_, __) {
        return Container(
          decoration: const BoxDecoration(gradient: bg),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                _statsRow(context),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(color: Colors.white.withOpacity(0.15), height: 1, thickness: 1),
                ),
                const SizedBox(height: 12),
                Expanded(child: _mainList(context)),
                const SizedBox(height: 80), // Bottom padding for navigation
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _mainList(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.vm.refreshData,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        controller: _listController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: _currentList.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          if (i < _currentList.length) {
            final user = _currentList[i];
            return ConnectionRowWithSwipe(
              user: user,
              currentTab: _selectedTab,
              onUserTap: () => _openStreamerCard(user),
              onUnfollow: (u) async {
                await widget.relationshipService.unfollowUser(u);
              },
              onRemoveFollower: (u) async {
                await widget.relationshipService.removeFollower(u);
              },
            );
          } else if (_isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
                ),
              ),
            );
          } else {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  Widget _statsRow(BuildContext context) {
    final svc = widget.relationshipService;
    final connectionsCount = svc.connections.length;
    final followersCount = svc.nonMutualFollowers.length;
    final followingCount = svc.nonMutualFollowing.length;

    final double cardWidth = (MediaQuery.of(context).size.width - 40 - 12) / 2;

    return GestureDetector(
      onHorizontalDragUpdate: (details) => _dragOffset = details.delta.dx,
      onHorizontalDragEnd: (_) {
        const threshold = 50.0;
        if (_dragOffset > threshold) {
          setState(() {
            _selectedTab = switch (_selectedTab) {
              NetworkTab.connections => NetworkTab.following,
              NetworkTab.followers => NetworkTab.connections,
              NetworkTab.following => NetworkTab.followers,
            };
          });
          _scrollToTop();
        } else if (_dragOffset < -threshold) {
          setState(() {
            _selectedTab = switch (_selectedTab) {
              NetworkTab.connections => NetworkTab.followers,
              NetworkTab.followers => NetworkTab.following,
              NetworkTab.following => NetworkTab.connections,
            };
          });
          _scrollToTop();
        }
        _dragOffset = 0;
      },
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            StatGlassCard(
              width: cardWidth,
              height: 126,
              icon: Icons.group,
              title: 'Connections',
              count: connectionsCount,
              isSelected: _selectedTab == NetworkTab.connections,
              onTap: () {
                setState(() => _selectedTab = NetworkTab.connections);
                _scrollToTop();
              },
            ),
            const SizedBox(width: 12),
            StatGlassCard(
              width: cardWidth,
              height: 126,
              icon: Icons.favorite,
              title: 'Followers',
              count: followersCount,
              isSelected: _selectedTab == NetworkTab.followers,
              onTap: () {
                setState(() => _selectedTab = NetworkTab.followers);
                _scrollToTop();
              },
            ),
            const SizedBox(width: 12),
            StatGlassCard(
              width: cardWidth,
              height: 126,
              icon: Icons.person,
              title: 'Following',
              count: followingCount,
              isSelected: _selectedTab == NetworkTab.following,
              onTap: () {
                setState(() => _selectedTab = NetworkTab.following);
                _scrollToTop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToTop() {
    if (_listController.hasClients) {
      _listController.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _openStreamerCard(User user) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StreamerCardPage(user: user),
      fullscreenDialog: true,
    ));
  }
}

class StatGlassCard extends StatelessWidget {
  final double width;
  final double height;
  final IconData icon;
  final String title;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const StatGlassCard({
    super.key,
    required this.width,
    required this.height,
    required this.icon,
    required this.title,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.12),
          Colors.white.withOpacity(0.06),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 8)),
      ],
    );

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: decoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Center(child: _buildIcon(icon)),
            const SizedBox(height: 8),
            Center(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            const Spacer(),
            Text(
              '$count',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(IconData iconData) {
    if (!isSelected) {
      return Icon(iconData, color: Colors.white.withOpacity(0.9), size: 34);
    }
    const gradient = LinearGradient(
      colors: [Color(0xFF40DCD1), Color(0xFF3D99F7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return ShaderMask(
      shaderCallback: (Rect bounds) => gradient.createShader(bounds),
      child: Icon(iconData, color: Colors.white, size: 34),
    );
  }
}

class ConnectionRow extends StatelessWidget {
  final User user;
  const ConnectionRow({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final glass = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.18),
          Colors.white.withOpacity(0.08),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(color: Colors.white.withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 6)),
        BoxShadow(color: Colors.black.withOpacity(0.20), blurRadius: 10, offset: const Offset(0, 6)),
      ],
      border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
    );

    return Stack(
      children: [
        Container(
          height: 92,
          decoration: glass,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _avatar(user),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 18),
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned.fill(
          right: 20,
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.7),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _getStatusColor(user.onlineStatus),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatar(User user) {
    final fallback = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, color: Colors.grey),
    );
    if (user.avatarURL == null) return fallback;
    return ClipOval(
      child: Image.network(
        user.avatarURL!,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return Colors.green;
      case 'offline':
        return Colors.grey;
      case 'busy':
        return Colors.orange;
      case 'dnd':
        return Colors.red;
      case 'streaming':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

class ConnectionRowWithSwipe extends StatefulWidget {
  final User user;
  final NetworkTab currentTab;
  final VoidCallback onUserTap;
  final Future<void> Function(User) onUnfollow;
  final Future<void> Function(User) onRemoveFollower;

  const ConnectionRowWithSwipe({
    super.key,
    required this.user,
    required this.currentTab,
    required this.onUserTap,
    required this.onUnfollow,
    required this.onRemoveFollower,
  });

  @override
  State<ConnectionRowWithSwipe> createState() => _ConnectionRowWithSwipeState();
}

class _ConnectionRowWithSwipeState extends State<ConnectionRowWithSwipe> {
  double _offset = 0;
  bool _isSwiped = false;

  static const double _swipeThreshold = -80;

  @override
  Widget build(BuildContext context) {
    final isFollowersTab = widget.currentTab == NetworkTab.followers;
    final actionColor = isFollowersTab ? Colors.orange : Colors.red;

    return Stack(
      children: [
        Opacity(
          opacity: _offset < -20 ? 1 : 0,
          child: SizedBox(
            height: 80,
            child: Row(
              children: [
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: IconButton(
                    onPressed: () => _confirmAction(context, isFollowersTab),
                    icon: Icon(Icons.person_remove, color: actionColor, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ),
        Semantics(
          label: '${widget.user.displayName}, ${widget.user.username}. Swipe left to ${isFollowersTab ? 'remove follower' : 'unfollow'}.',
          button: true,
          child: GestureDetector(
            onHorizontalDragUpdate: (d) {
              final newOffset = d.delta.dx;
              setState(() {
                _offset += newOffset;
                if (_offset > 0) _offset = 0;
                if (_offset < -140) _offset = -140;
              });
            },
            onHorizontalDragEnd: (_) {
              setState(() {
                if (_offset < _swipeThreshold) {
                  _offset = -100;
                  _isSwiped = true;
                } else {
                  _offset = 0;
                  _isSwiped = false;
                }
              });
            },
            onTap: () {
              if (_isSwiped) {
                setState(() {
                  _offset = 0;
                  _isSwiped = false;
                });
              } else {
                widget.onUserTap();
              }
            },
            child: Transform.translate(
              offset: Offset(_offset, 0),
              child: const SizedBox.shrink(),
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(_offset, 0),
          child: ConnectionRow(user: widget.user),
        ),
      ],
    );
  }

  void _confirmAction(BuildContext context, bool isFollowersTab) {
    final name = widget.user.displayName;
    final title = isFollowersTab ? 'Remove $name?' : 'Unfollow $name?';
    final message = isFollowersTab
        ? "This will remove $name from your followers. They won't be able to see your posts anymore."
        : "You won't see their posts in your feed anymore. You can follow them again anytime.";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0E1220),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: TextStyle(color: Colors.white.withOpacity(0.9))),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _offset = 0;
                _isSwiped = false;
              });
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              setState(() {
                _offset = 0;
                _isSwiped = false;
              });
              Navigator.pop(context);
              if (isFollowersTab) {
                await widget.onRemoveFollower(widget.user);
              } else {
                await widget.onUnfollow(widget.user);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(isFollowersTab ? 'Remove' : 'Unfollow'),
          ),
        ],
      ),
    );
  }
}

// old placeholder removed; now using StreamerCardPage


