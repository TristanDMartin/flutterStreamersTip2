import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../services/advanced_admin_service.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/admin_service.dart';
import '../utils/sensitive_data_redactor.dart';
import '../utils/user_facing_error.dart';

class AdminMonitoringPanel extends StatefulWidget {
  const AdminMonitoringPanel({super.key});

  @override
  State<AdminMonitoringPanel> createState() => _AdminMonitoringPanelState();
}

class _AdminMonitoringPanelState extends State<AdminMonitoringPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _logs = [];
  final List<Map<String, dynamic>> _activeUsers = [];
  final List<Map<String, dynamic>> _recentVideos = [];
  final List<Map<String, dynamic>> _recentMessages = [];
  final List<Map<String, dynamic>> _recentNotifications = [];
  final List<Map<String, dynamic>> _recentReports = [];
  final List<Map<String, dynamic>> _userReports = [];
  final List<Map<String, dynamic>> _errorLogs = [];

  StreamSubscription<QuerySnapshot>? _usersSub;
  StreamSubscription<QuerySnapshot>? _videosSub;
  StreamSubscription<QuerySnapshot>? _messagesSub;
  StreamSubscription<QuerySnapshot>? _notificationsSub;
  StreamSubscription<QuerySnapshot>? _reportsSub;
  StreamSubscription<QuerySnapshot>? _userReportsSub;
  StreamSubscription<QuerySnapshot>? _errorsSub;

  int _totalUsers = 0;
  int _totalVideos = 0;
  int _onlineUsers = 0;
  int _totalLikes = 0;
  int _totalComments = 0;
  int _totalViews = 0;
  int _totalFollows = 0;
  int _totalMessages = 0;
  int _totalReports = 0;
  int _pendingReports = 0;
  int _resolvedReports = 0;
  int _totalErrors = 0;
  int _networkErrors = 0;
  int _firebaseErrors = 0;
  int _nullSafetyErrors = 0;
  int _crashReports = 0;
  bool _showAllUsers = true;
  bool _showAllVideos = false;

  final _searchController = TextEditingController();
  Map<String, List<Map<String, dynamic>>> _searchResults = {};
  bool _isSearching = false;
  bool _maintenanceMode = false;
  Map<String, bool> _featureFlags = {};
  bool _isAuthorized = false;
  bool _isCheckingAuthorization = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 11, vsync: this);
    _initializeAdminAccess();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _usersSub?.cancel();
    _videosSub?.cancel();
    _messagesSub?.cancel();
    _notificationsSub?.cancel();
    _reportsSub?.cancel();
    _userReportsSub?.cancel();
    _errorsSub?.cancel();
    super.dispose();
  }

  void _startMonitoring() {
    _addLog('🟢 Admin monitoring started');
    _monitorUsers();
    _monitorVideos();
    _monitorMessages();
    _monitorNotifications();
    _monitorReports();
    _monitorUserReports();
    _monitorErrors();
    _fetchStats();
  }

  Future<void> _initializeAdminAccess() async {
    final isAdmin = await AdminService.instance.isCurrentUserAdmin();
    if (!mounted) {
      return;
    }

    setState(() {
      _isAuthorized = isAdmin;
      _isCheckingAuthorization = false;
    });

    if (!isAdmin) {
      _addLog('🚫 Unauthorized admin access blocked');
      return;
    }

    _startMonitoring();
    _loadSystemSettings();
    _loadFeatureFlags();
  }

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, '${DateTime.now().toString().split('.')[0]} - $message');
      if (_logs.length > 100) _logs.removeLast();
    });
  }

  void _monitorUsers() {
    final query = FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true);

    _usersSub = (_showAllUsers ? query : query.limit(20))
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _activeUsers.clear();
        _onlineUsers = 0;
        _totalFollows = 0;
        for (final doc in snapshot.docs) {
          final data = doc.data();

          // Handle both app and website users
          final onlineStatus = data['onlineStatus'] ?? 'offline';
          if (onlineStatus == 'online') _onlineUsers++;

          final followers = data['followerCount'] ?? 0;
          final following = data['followingCount'] ?? 0;
          _totalFollows += followers as int;

          // Get lastSeen or fallback to createdAt for website users
          final lastSeen = data['lastSeen'] ?? data['createdAt'];

          _activeUsers.add({
            'id': doc.id,
            'username': data['username'] ?? 'Unknown',
            'displayName': data['displayName'] ?? 'Unknown',
            'onlineStatus': onlineStatus,
            'lastSeen': lastSeen,
            'followers': followers,
            'following': following,
            'postCount': data['postCount'] ?? 0,
            'email': data['email'] ?? 'N/A',
            'createdAt': data['createdAt'],
            'source':
                data['lastSeen'] != null ? 'App' : 'Website', // Track source
          });
        }
      });
      _addLog(
          '👥 Updated users: ${_activeUsers.length} (${_showAllUsers ? 'all' : 'top 20'})');
    });
  }

  void _monitorVideos() {
    final query = FirebaseFirestore.instance
        .collection('videos')
        .orderBy('createdAt', descending: true);

    _videosSub = (_showAllVideos ? query : query.limit(20))
        .snapshots()
        .listen((snapshot) async {
      setState(() {
        _recentVideos.clear();
        _totalLikes = 0;
        _totalComments = 0;
        _totalViews = 0;
      });

      // Process videos and fetch usernames
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final likes = data['likeCount'] ?? 0;
        final comments = data['commentCount'] ?? 0;
        final views = data['views'] ?? 0;
        _totalLikes += likes as int;
        _totalComments += comments as int;
        _totalViews += views as int;

        final userId = data['userId'] ??
            data['creatorId'] ??
            data['creator_id'] ??
            'Unknown';
        String username = 'Unknown';

        // Fetch username for the creator
        try {
          if (userId != 'Unknown') {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();
            username = userDoc.data()?['username'] ?? userId;
          }
        } catch (e) {
          debugPrint('Error fetching username for video creator: $e');
        }

        setState(() {
          _recentVideos.add({
            'id': doc.id,
            'caption': data['caption'] ?? 'No caption',
            'userId': userId,
            'username': username,
            'createdAt': data['createdAt'],
            'views': views,
            'likes': likes,
            'dislikes': data['dislikeCount'] ?? 0,
            'comments': comments,
            'shares': data['shareCount'] ?? 0,
            'status': data['status'] ?? 'unknown',
            'duration': data['duration'] ?? 0,
            'thumbnailURL': data['thumbnailURL'] ?? '',
          });
        });
      }

      _addLog(
          '📹 Updated videos: ${_recentVideos.length} (${_showAllVideos ? 'all' : 'top 20'})');
    });
  }

  void _monitorMessages() {
    _messagesSub = FirebaseFirestore.instance
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) async {
      setState(() {
        _recentMessages.clear();
        _totalMessages = snapshot.docs.length;
      });

      // Process messages and fetch usernames
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final fromId = data['from'] ?? 'Unknown';
        final toId = data['to'] ?? 'Unknown';

        // Fetch usernames for from and to users
        String fromUsername = 'Unknown';
        String toUsername = 'Unknown';

        try {
          if (fromId != 'Unknown') {
            final fromUser = await FirebaseFirestore.instance
                .collection('users')
                .doc(fromId)
                .get();
            fromUsername = fromUser.data()?['username'] ?? fromId;
          }

          if (toId != 'Unknown') {
            final toUser = await FirebaseFirestore.instance
                .collection('users')
                .doc(toId)
                .get();
            toUsername = toUser.data()?['username'] ?? toId;
          }
        } catch (e) {
          debugPrint('Error fetching usernames: $e');
        }

        setState(() {
          _recentMessages.add({
            'id': doc.id,
            'from': fromId,
            'to': toId,
            'fromUsername': fromUsername,
            'toUsername': toUsername,
            'text': data['text'] ?? '',
            'type': data['type'] ?? 'text',
            'timestamp': data['timestamp'],
          });
        });
      }

      _addLog('💬 Updated recent messages: ${_recentMessages.length}');
    });
  }

  void _monitorNotifications() {
    _notificationsSub = FirebaseFirestore.instance
        .collection('items')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _recentNotifications.clear();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          _recentNotifications.add({
            'id': doc.id,
            'type': data['type'] ?? 'unknown',
            'userId': data['userId'] ?? 'Unknown',
            'timestamp': data['timestamp'],
          });
        }
      });
      _addLog('🔔 Updated notifications: ${_recentNotifications.length}');
    });
  }

  void _monitorReports() {
    _reportsSub = FirebaseFirestore.instance
        .collection('reports')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _recentReports.clear();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          _recentReports.add({
            'id': doc.id,
            'videoId': data['videoId'] ?? 'Unknown',
            'creatorId': data['creatorId'] ?? 'Unknown',
            'reporterId': data['reporterId'] ?? 'Unknown',
            'reason': data['reason'] ?? 'Unknown',
            'status': data['status'] ?? 'pending',
            'timestamp': data['timestamp'],
            'additionalDetails': data['additionalDetails'],
          });
        }
      });
      _addLog('📋 Updated video reports: ${_recentReports.length}');
    });
  }

  void _monitorUserReports() {
    _userReportsSub = FirebaseFirestore.instance
        .collection('user_reports')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _userReports.clear();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          _userReports.add({
            'id': doc.id,
            'userId': data['userId'] ?? 'Unknown',
            'reporterId': data['reporterId'] ?? 'Unknown',
            'reason': data['reason'] ?? 'Unknown',
            'status': data['status'] ?? 'pending',
            'timestamp': data['timestamp'],
            'additionalDetails': data['additionalDetails'],
          });
        }
      });
      _addLog('👤 Updated user reports: ${_userReports.length}');
    });
  }

  void _monitorErrors() {
    _errorsSub = FirebaseFirestore.instance
        .collection('error_logs')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _errorLogs.clear();
        _networkErrors = 0;
        _firebaseErrors = 0;
        _nullSafetyErrors = 0;
        _crashReports = 0;
        
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final errorType = data['errorType'] ?? 'unknown';
          final isFatal = data['fatal'] ?? false;
          
          // Count error types
          if (errorType == 'network') {
            _networkErrors++;
          } else if (errorType == 'firebase') {
            _firebaseErrors++;
          } else if (errorType == 'null_safety') {
            _nullSafetyErrors++;
          }
          
          if (isFatal) {
            _crashReports++;
          }
          
          _errorLogs.add({
            'id': doc.id,
            'errorType': errorType,
            'errorMessage': data['errorMessage'] ?? 'Unknown error',
            'stackTrace': data['stackTrace'] ?? '',
            'userId': data['userId'],
            'userAgent': data['userAgent'] ?? '',
            'platform': data['platform'] ?? 'unknown',
            'fatal': isFatal,
            'timestamp': data['timestamp'],
            'recovered': data['recovered'] ?? false,
            'userFriendlyMessage': data['userFriendlyMessage'] ?? '',
          });
        }
        
        _totalErrors = _errorLogs.length;
      });
      _addLog('🚨 Updated error logs: ${_errorLogs.length}');
    });
  }

  Future<void> _fetchStats() async {
    try {
      final usersCount =
          await FirebaseFirestore.instance.collection('users').count().get();
      final videosCount =
          await FirebaseFirestore.instance.collection('videos').count().get();
      final reportsCount =
          await FirebaseFirestore.instance.collection('reports').count().get();

      // Get pending reports count
      final pendingReportsQuery = await FirebaseFirestore.instance
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      // Get resolved reports count
      final resolvedReportsQuery = await FirebaseFirestore.instance
          .collection('reports')
          .where('status', isEqualTo: 'resolved')
          .count()
          .get();

      // Get error statistics
      final errorsCount = await FirebaseFirestore.instance
          .collection('error_logs')
          .count()
          .get();
      
      final networkErrorsCount = await FirebaseFirestore.instance
          .collection('error_logs')
          .where('errorType', isEqualTo: 'network')
          .count()
          .get();
      
      final firebaseErrorsCount = await FirebaseFirestore.instance
          .collection('error_logs')
          .where('errorType', isEqualTo: 'firebase')
          .count()
          .get();
      
      final nullSafetyErrorsCount = await FirebaseFirestore.instance
          .collection('error_logs')
          .where('errorType', isEqualTo: 'null_safety')
          .count()
          .get();
      
      final crashReportsCount = await FirebaseFirestore.instance
          .collection('error_logs')
          .where('fatal', isEqualTo: true)
          .count()
          .get();

      setState(() {
        _totalUsers = usersCount.count ?? 0;
        _totalVideos = videosCount.count ?? 0;
        _totalReports = reportsCount.count ?? 0;
        _pendingReports = pendingReportsQuery.count ?? 0;
        _resolvedReports = resolvedReportsQuery.count ?? 0;
        _totalErrors = errorsCount.count ?? 0;
        _networkErrors = networkErrorsCount.count ?? 0;
        _firebaseErrors = firebaseErrorsCount.count ?? 0;
        _nullSafetyErrors = nullSafetyErrorsCount.count ?? 0;
        _crashReports = crashReportsCount.count ?? 0;
      });
      _addLog(
          '📊 Fetched stats - Users: $_totalUsers, Videos: $_totalVideos, Reports: $_totalReports, Errors: $_totalErrors');
    } catch (e) {
      _addLog('❌ Error fetching stats: $e');
    }
  }

  Future<void> _loadSystemSettings() async {
    final settings = await AdvancedAdminService.instance.getSystemSettings();
    if (mounted) {
      setState(() {
        _maintenanceMode = settings['maintenanceMode'] ?? false;
      });
    }
  }

  Future<void> _loadFeatureFlags() async {
    final flags = await AdvancedAdminService.instance.getFeatureFlags();
    if (mounted) {
      setState(() {
        _featureFlags = Map<String, bool>.from(flags);
      });
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuthorization) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A1A),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Admin Access',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'You do not have permission to view admin tools.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '⚡ Complete Admin Control',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _addLog('🔄 Manual refresh triggered');
              _fetchStats();
              _loadSystemSettings();
              _loadFeatureFlags();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFF9248D2),
          labelColor: const Color(0xFF9248D2),
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: '📊 Overview'),
            Tab(text: '👥 Users'),
            Tab(text: '📹 Videos'),
            Tab(text: '💬 Messages'),
            Tab(text: '🚫 Moderation'),
            Tab(text: '🎫 Support'),
            Tab(text: '🔍 Search'),
            Tab(text: '📧 Notifications'),
            Tab(text: '⚙️ Settings'),
            Tab(text: '🚨 Errors'),
            Tab(text: '📝 Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildUsersTab(),
          _buildVideosTab(),
          _buildMessagesTab(),
          _buildModerationTab(),
          _buildSupportTicketsTab(),
          _buildSearchTab(),
          _buildNotificationsTab(),
          _buildSettingsTab(),
          _buildErrorsTab(),
          _buildLogsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(16, 16, 16, 100), // Extra bottom padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '👥 User Statistics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatCard('Total Users', _totalUsers.toString(), Icons.people),
          const SizedBox(height: 12),
          _buildStatCard(
            'Online Now',
            _onlineUsers.toString(),
            Icons.circle,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Total Followers',
            _formatNumber(_totalFollows),
            Icons.favorite,
          ),
          const SizedBox(height: 24),
          const Text(
            '📹 Video Statistics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Total Videos',
            _totalVideos.toString(),
            Icons.video_library,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Total Views',
            _formatNumber(_totalViews),
            Icons.visibility,
            color: const Color(0xFF2196F3),
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Total Likes',
            _formatNumber(_totalLikes),
            Icons.thumb_up,
            color: const Color(0xFFE91E63),
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Total Comments',
            _formatNumber(_totalComments),
            Icons.comment,
            color: const Color(0xFF4CAF50),
          ),
          const SizedBox(height: 24),
          const Text(
            '💬 Communication',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Recent Messages',
            _totalMessages.toString(),
            Icons.message,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Notifications',
            _recentNotifications.length.toString(),
            Icons.notifications,
          ),
          const SizedBox(height: 24),
          const Text(
            '📋 Report Statistics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Total Reports',
            _totalReports.toString(),
            Icons.report,
            color: const Color(0xFFFF9800),
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Pending Reports',
            _pendingReports.toString(),
            Icons.pending_actions,
            color: const Color(0xFFFF5722),
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Resolved Reports',
            _resolvedReports.toString(),
            Icons.check_circle,
            color: const Color(0xFF4CAF50),
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'User Reports',
            _userReports.length.toString(),
            Icons.person_off,
            color: const Color(0xFF9C27B0),
          ),
          const SizedBox(height: 24),
          const Text(
            '🔴 Live Activity Feed',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ..._logs.take(10).map((log) => _buildLogItem(log)),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${_activeUsers.length} users',
                style: const TextStyle(color: Colors.white70),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showAllUsers = !_showAllUsers;
                    _usersSub?.cancel();
                    _monitorUsers();
                  });
                },
                icon: Icon(
                    _showAllUsers ? Icons.visibility_off : Icons.visibility),
                label: Text(_showAllUsers ? 'Show Top 20' : 'Show All Users'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9248D2),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
                16, 0, 16, 100), // Extra bottom padding
            itemCount: _activeUsers.length,
            itemBuilder: (context, index) {
              final user = _activeUsers[index];
              final isOnline = user['onlineStatus'] == 'online';
              return Card(
                color: const Color(0xFF1A1A1A),
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF9248D2),
                        child: Text(
                          user['username'].toString()[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      if (isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    user['displayName'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '@${user['username']} • ${user['source'] ?? 'Unknown'} • ${isOnline ? 'Online' : _formatTimestamp(user['lastSeen'])}',
                    style: TextStyle(
                      color: isOnline ? Colors.green : Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white54),
                    onPressed: () => _showUserActions(user),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildUserStat(
                                  'Posts', user['postCount'].toString()),
                              _buildUserStat(
                                  'Followers', user['followers'].toString()),
                              _buildUserStat(
                                  'Following', user['following'].toString()),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow('Email', user['email']),
                          _buildDetailRow('User ID', user['id']),
                          _buildDetailRow(
                              'Source', user['source'] ?? 'Unknown'),
                          _buildDetailRow(
                              'Joined', _formatTimestamp(user['createdAt'])),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildVideosTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${_recentVideos.length} videos',
                style: const TextStyle(color: Colors.white70),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showAllVideos = !_showAllVideos;
                    _videosSub?.cancel();
                    _monitorVideos();
                  });
                },
                icon: Icon(
                    _showAllVideos ? Icons.visibility_off : Icons.visibility),
                label: Text(_showAllVideos ? 'Show Top 20' : 'Load All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9248D2),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
                16, 0, 16, 100), // Extra bottom padding
            itemCount: _recentVideos.length,
            itemBuilder: (context, index) {
              final video = _recentVideos[index];
              return Card(
                color: const Color(0xFF1A1A1A),
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: const Icon(
                    Icons.play_circle_outline,
                    color: Color(0xFF9248D2),
                    size: 40,
                  ),
                  title: Text(
                    video['caption'] ?? 'No caption',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${_formatTimestamp(video['createdAt'])} • Status: ${video['status']}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white54),
                    onPressed: () => _showVideoActions(video),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildVideoStat(
                                  'Views',
                                  _formatNumber(video['views']),
                                  Icons.visibility,
                                  Colors.blue),
                              _buildVideoStat(
                                  'Likes',
                                  video['likes'].toString(),
                                  Icons.thumb_up,
                                  Colors.pink),
                              _buildVideoStat(
                                  'Dislikes',
                                  video['dislikes'].toString(),
                                  Icons.thumb_down,
                                  Colors.red),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildVideoStat(
                                  'Comments',
                                  video['comments'].toString(),
                                  Icons.comment,
                                  Colors.green),
                              _buildVideoStat(
                                  'Shares',
                                  video['shares'].toString(),
                                  Icons.share,
                                  Colors.orange),
                              _buildVideoStat(
                                  'Duration',
                                  '${video['duration']}s',
                                  Icons.timer,
                                  Colors.purple),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow('Video ID', video['id']),
                          _buildDetailRow(
                              'Creator', video['username'] ?? 'Unknown'),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVideoStat(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildMessagesTab() {
    return ListView.builder(
      padding:
          const EdgeInsets.fromLTRB(16, 16, 16, 100), // Extra bottom padding
      itemCount: _recentMessages.length,
      itemBuilder: (context, index) {
        final message = _recentMessages[index];
        return Card(
          color: const Color(0xFF1A1A1A),
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: const Icon(
              Icons.message,
              color: Color(0xFF9248D2),
            ),
            title: Text(
              'From: ${message['fromUsername'] ?? message['from']} → To: ${message['toUsername'] ?? message['to']}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              '${_formatTimestamp(message['timestamp'])} • Type: ${message['type']}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Message Content:',
                      style: TextStyle(
                        color: Color(0xFF9248D2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message['text'] != null &&
                              message['text'].toString().isNotEmpty
                          ? message['text']
                          : '(No text content)',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Message ID', message['id']),
                    _buildDetailRow(
                        'From', message['fromUsername'] ?? message['from']),
                    _buildDetailRow(
                        'To', message['toUsername'] ?? message['to']),
                    _buildDetailRow('Type', message['type']),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModerationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Management Section
          const Text(
            '📋 Report Management',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Report Statistics Cards
          Row(
            children: [
              Expanded(
                child: _buildReportStatCard(
                  'Pending',
                  _pendingReports.toString(),
                  Icons.pending_actions,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildReportStatCard(
                  'Resolved',
                  _resolvedReports.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Recent Video Reports
          const Text(
            '🎬 Recent Video Reports',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildReportsList(_recentReports, 'video'),

          const SizedBox(height: 24),

          // Recent User Reports
          const Text(
            '👤 Recent User Reports',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildReportsList(_userReports, 'user'),

          const SizedBox(height: 24),

          // Quick Actions
          const Text(
            '⚡ Quick Actions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            'Ban User',
            Icons.block,
            Colors.red,
            () => _showBanUserDialog(),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Suspend User (Temporary)',
            Icons.pause_circle,
            Colors.orange,
            () => _showSuspendUserDialog(),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Delete Video',
            Icons.delete_forever,
            Colors.red,
            () => _showDeleteVideoDialog(),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Resolve All Pending Reports',
            Icons.check_circle_outline,
            Colors.green,
            () => _resolveAllPendingReports(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search users, videos, messages...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF9248D2)),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchResults = {});
                      },
                    ),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: _performSearch,
          ),
        ),
        Expanded(
          child: _searchResults.isEmpty
              ? const Center(
                  child: Text(
                    'Enter a search query',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView(
                  children: [
                    if (_searchResults['users']?.isNotEmpty ?? false) ...[
                      _buildSearchSection('Users', _searchResults['users']!),
                    ],
                    if (_searchResults['videos']?.isNotEmpty ?? false) ...[
                      _buildSearchSection('Videos', _searchResults['videos']!),
                    ],
                    if (_searchResults['messages']?.isNotEmpty ?? false) ...[
                      _buildSearchSection(
                          'Messages', _searchResults['messages']!),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildNotificationsTab() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(16, 16, 16, 100), // Extra bottom padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Send Push Notifications',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            'Broadcast to All Users',
            Icons.campaign,
            const Color(0xFF9248D2),
            () => _showBroadcastDialog(),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Send to Specific Users',
            Icons.person_add_alt_1,
            Colors.blue,
            () => _showTargetedNotificationDialog(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Export Analytics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            'Export to CSV',
            Icons.table_chart,
            Colors.green,
            _exportToCSV,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(16, 16, 16, 100), // Extra bottom padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text(
              'Maintenance Mode',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              _maintenanceMode ? 'App is in maintenance' : 'App is active',
              style: const TextStyle(color: Colors.white54),
            ),
            value: _maintenanceMode,
            activeThumbColor: const Color(0xFF9248D2),
            onChanged: (value) => _toggleMaintenanceMode(value),
          ),
          const SizedBox(height: 24),
          const Text(
            'Feature Flags',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._featureFlags.entries.map((entry) => SwitchListTile(
                title: Text(
                  entry.key,
                  style: const TextStyle(color: Colors.white),
                ),
                value: entry.value,
                activeThumbColor: const Color(0xFF9248D2),
                onChanged: (value) => _toggleFeatureFlag(entry.key, value),
              )),
          const SizedBox(height: 16),
          _buildActionButton(
            'Add New Feature Flag',
            Icons.add,
            Colors.blue,
            () => _showAddFeatureFlagDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportTicketsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('support_tickets')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final tickets = snapshot.data!.docs;

        if (tickets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: Colors.white38,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No support tickets yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Support tickets will appear here',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: tickets.length,
          itemBuilder: (context, index) {
            final ticket = tickets[index];
            final data = ticket.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            final priority = data['priority'] ?? 'medium';
            final category = data['category'] ?? 'General';

            Color statusColor;
            switch (status) {
              case 'pending':
                statusColor = Colors.orange;
                break;
              case 'in_progress':
                statusColor = Colors.blue;
                break;
              case 'resolved':
                statusColor = Colors.green;
                break;
              case 'closed':
                statusColor = Colors.grey;
                break;
              default:
                statusColor = Colors.orange;
            }

            Color priorityColor;
            switch (priority) {
              case 'high':
                priorityColor = Colors.red;
                break;
              case 'medium':
                priorityColor = Colors.orange;
                break;
              case 'low':
                priorityColor = Colors.green;
                break;
              default:
                priorityColor = Colors.orange;
            }

            return Card(
              color: const Color(0xFF1A1A1A),
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => _showTicketDetails(context, ticket, data),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: priorityColor,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              priority.toUpperCase(),
                              style: TextStyle(
                                color: priorityColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: statusColor,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              status.toUpperCase().replaceAll('_', ' '),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['subject'] ?? 'No Subject',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.category,
                            size: 14,
                            color: Colors.white54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            category,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.person,
                            size: 14,
                            color: Colors.white54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            data['displayName'] ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['message'] ?? 'No message',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      if (data['createdAt'] != null)
                        Text(
                          'Created: ${data['createdAt'].toDate().toString().substring(0, 16)}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTicketDetails(BuildContext context, DocumentSnapshot ticket,
      Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ticket Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTicketDetailRow('Subject', data['subject'] ?? 'N/A'),
                    _buildTicketDetailRow(
                        'Category', data['category'] ?? 'General'),
                    _buildTicketDetailRow(
                        'Status', data['status'] ?? 'pending'),
                    _buildTicketDetailRow(
                        'Priority', data['priority'] ?? 'medium'),
                    _buildTicketDetailRow(
                        'User', data['displayName'] ?? 'Unknown'),
                    _buildTicketDetailRow(
                        'Username', '@${data['username'] ?? 'unknown'}'),
                    _buildTicketDetailRow('Email', data['email'] ?? 'N/A'),
                    const SizedBox(height: 16),
                    const Text(
                      'Message:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        data['message'] ?? 'No message',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Actions:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (data['status'] == 'pending')
                      _buildTicketActionButton(
                        'Mark as In Progress',
                        Colors.blue,
                        () async {
                          await ticket.reference.update({
                            'status': 'in_progress',
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.pop(context);
                        },
                      ),
                    if (data['status'] == 'in_progress')
                      _buildTicketActionButton(
                        'Mark as Resolved',
                        Colors.green,
                        () async {
                          await ticket.reference.update({
                            'status': 'resolved',
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.pop(context);
                        },
                      ),
                    _buildTicketActionButton(
                      'Close Ticket',
                      Colors.grey,
                      () async {
                        await ticket.reference.update({
                          'status': 'closed',
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                        if (!context.mounted) {
                          return;
                        }
                        Navigator.pop(context);
                      },
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

  Widget _buildTicketDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketActionButton(
      String label, Color color, VoidCallback onTap) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.2),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: color),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Error Statistics
          const Text(
            '🚨 Error Statistics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildErrorStatCard(
                  'Total Errors',
                  '$_totalErrors',
                  Colors.red,
                  Icons.error_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildErrorStatCard(
                  'Network',
                  '$_networkErrors',
                  Colors.orange,
                  Icons.wifi_off,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildErrorStatCard(
                  'Firebase',
                  '$_firebaseErrors',
                  Colors.blue,
                  Icons.cloud_off,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildErrorStatCard(
                  'Null Safety',
                  '$_nullSafetyErrors',
                  Colors.purple,
                  Icons.bug_report,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildErrorStatCard(
            'Crashes',
            '$_crashReports',
            Colors.red.shade700,
            Icons.warning,
            fullWidth: true,
          ),
          const SizedBox(height: 24),
          
          // Error Handling Features Status
          const Text(
            '✅ Error Handling Features',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildFeatureStatusCard(
            'Network Errors',
            'Handled gracefully with retry mechanisms',
            Icons.wifi_off,
            Colors.orange,
          ),
          const SizedBox(height: 8),
          _buildFeatureStatusCard(
            'Firebase Errors',
            'Handled with user-friendly messages',
            Icons.cloud_off,
            Colors.blue,
          ),
          const SizedBox(height: 8),
          _buildFeatureStatusCard(
            'Null Safety',
            'Comprehensive null checks throughout',
            Icons.bug_report,
            Colors.purple,
          ),
          const SizedBox(height: 8),
          _buildFeatureStatusCard(
            'User-Friendly Messages',
            'Clear error messages for all scenarios',
            Icons.message,
            Colors.green,
          ),
          const SizedBox(height: 8),
          _buildFeatureStatusCard(
            'Error Recovery',
            'Automatic retry and fallback mechanisms',
            Icons.refresh,
            Colors.teal,
          ),
          const SizedBox(height: 8),
          _buildFeatureStatusCard(
            'Crash Reporting',
            'Firebase Crashlytics integrated',
            Icons.report,
            Colors.red,
          ),
          const SizedBox(height: 24),
          
          // Recent Error Logs
          const Text(
            '📋 Recent Error Logs',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _errorLogs.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'No errors logged yet',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _errorLogs.length > 20 ? 20 : _errorLogs.length,
                  itemBuilder: (context, index) {
                    final error = _errorLogs[index];
                    return _buildErrorLogCard(error);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildErrorStatCard(String label, String value, Color color, IconData icon,
      {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureStatusCard(
      String title, String description, IconData icon, Color color) {
    return Card(
      color: const Color(0xFF1A1A1A),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          description,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }

  Widget _buildErrorLogCard(Map<String, dynamic> error) {
    final errorType = error['errorType'] ?? 'unknown';
    final isFatal = error['fatal'] ?? false;
    final recovered = error['recovered'] ?? false;
    
    Color typeColor = Colors.grey;
    IconData typeIcon = Icons.error_outline;
    
    if (errorType == 'network') {
      typeColor = Colors.orange;
      typeIcon = Icons.wifi_off;
    } else if (errorType == 'firebase') {
      typeColor = Colors.blue;
      typeIcon = Icons.cloud_off;
    } else if (errorType == 'null_safety') {
      typeColor = Colors.purple;
      typeIcon = Icons.bug_report;
    }
    
    if (isFatal) {
      typeColor = Colors.red;
      typeIcon = Icons.warning;
    }

    return Card(
      color: const Color(0xFF1A1A1A),
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(typeIcon, color: typeColor),
        title: Text(
          error['errorMessage'] ?? 'Unknown error',
          style: TextStyle(
            color: Colors.white,
            fontWeight: isFatal ? FontWeight.bold : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    errorType.toUpperCase(),
                    style: TextStyle(
                      color: typeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isFatal) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'FATAL',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (recovered) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'RECOVERED',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(error['timestamp']),
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (error['userFriendlyMessage'] != null &&
                    error['userFriendlyMessage'].toString().isNotEmpty) ...[
                  const Text(
                    'User Message:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    error['userFriendlyMessage'],
                    style: const TextStyle(color: Colors.green, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                ],
                if (error['stackTrace'] != null &&
                    error['stackTrace'].toString().isNotEmpty) ...[
                  const Text(
                    'Stack Trace:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      error['stackTrace'].toString().length > 500
                          ? '${error['stackTrace'].toString().substring(0, 500)}...'
                          : error['stackTrace'].toString(),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
                if (error['userId'] != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'User ID: ${error['userId']}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
                if (error['platform'] != null) ...[
                  Text(
                    'Platform: ${error['platform']}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: AdvancedAdminService.instance.getActivityHistory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
              16, 16, 16, 100), // Extra bottom padding
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index].data() as Map<String, dynamic>;
            return Card(
              color: const Color(0xFF1A1A1A),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.history, color: Color(0xFF9248D2)),
                title: Text(
                  log['action'] ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${log['timestamp']?.toDate() ?? 'N/A'}\nAdmin: ${log['adminUsername'] ?? log['adminId'] ?? 'Unknown'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color ?? const Color(0xFF9248D2).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color ?? const Color(0xFF9248D2),
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(String log) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        log,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection(String title, List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...items.map((item) => ListTile(
              leading:
                  const Icon(Icons.circle, color: Color(0xFF9248D2), size: 12),
              title: Text(
                item['username'] ??
                    item['caption'] ??
                    item['text'] ??
                    'Unknown',
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                'ID: ${item['id']}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            )),
      ],
    );
  }

  void _showVideoDetails(Map<String, dynamic> video) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Video Details',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID', video['id']),
              _buildDetailRow('Caption', video['caption']),
              _buildDetailRow('User ID', video['userId']),
              _buildDetailRow('Views', video['views'].toString()),
              _buildDetailRow('Likes', video['likes'].toString()),
              _buildDetailRow('Status', video['status']),
              _buildDetailRow('Created', _formatTimestamp(video['createdAt'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _displayDetailValue(String label, String value) {
    final String lower = label.toLowerCase();
    if (lower.contains('id') || lower == 'uid') {
      return SensitiveDataRedactor.maskId(value);
    }
    return value;
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Color(0xFF9248D2),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _displayDetailValue(label, value),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserActions(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title:
                  const Text('Ban User', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showBanUserDialog(userId: user['id']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Color(0xFF9248D2)),
              title: const Text('View Details',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showUserDetails(user);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoActions(Map<String, dynamic> video) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Video',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteVideoDialog(videoId: video['id']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Color(0xFF9248D2)),
              title: const Text('View Details',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showVideoDetails(video);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title:
            const Text('User Details', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID', user['id']),
              _buildDetailRow('Username', user['username']),
              _buildDetailRow('Display Name', user['displayName']),
              _buildDetailRow('Status', user['onlineStatus']),
              _buildDetailRow('Last Seen', _formatTimestamp(user['lastSeen'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final results = await AdvancedAdminService.instance.advancedSearch(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
        _addLog(
            '🔍 Search completed: $query (${results.values.map((e) => e.length).reduce((a, b) => a + b)} results)');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        _addLog('❌ Search failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserFacingError.message(e))),
        );
      }
    }
  }

  void _showBanUserDialog({String? userId}) {
    final userIdController = TextEditingController(text: userId);
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Ban User', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userIdController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'User ID',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Reason',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await AdvancedAdminService.instance.banUser(
                  userId: userIdController.text,
                  reason: reasonController.text,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  _addLog('🚫 Banned user: ${userIdController.text}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User banned successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  _addLog('❌ Ban failed: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(UserFacingError.message(e))),
                  );
                }
              }
            },
            child: const Text('Ban', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSuspendUserDialog() {
    final userIdController = TextEditingController();
    final reasonController = TextEditingController();
    int selectedDays = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title:
              const Text('Suspend User', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userIdController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'User ID',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButton<int>(
                value: selectedDays,
                dropdownColor: const Color(0xFF1A1A1A),
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 Day')),
                  DropdownMenuItem(value: 7, child: Text('7 Days')),
                  DropdownMenuItem(value: 30, child: Text('30 Days')),
                ],
                onChanged: (value) => setState(() => selectedDays = value ?? 1),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await AdvancedAdminService.instance.suspendUser(
                    userId: userIdController.text,
                    reason: reasonController.text,
                    duration: Duration(days: selectedDays),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    _addLog(
                        '⏸️ Suspended user: ${userIdController.text} for $selectedDays days');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('User suspended successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    _addLog('❌ Suspend failed: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(UserFacingError.message(e))),
                    );
                  }
                }
              },
              child:
                  const Text('Suspend', style: TextStyle(color: Colors.orange)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteVideoDialog({String? videoId}) {
    final videoIdController = TextEditingController(text: videoId);
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title:
            const Text('Delete Video', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: videoIdController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Video ID',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Reason',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await AdvancedAdminService.instance.deleteVideo(
                  videoId: videoIdController.text,
                  reason: reasonController.text,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  _addLog('🗑️ Deleted video: ${videoIdController.text}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Video deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  _addLog('❌ Delete video failed: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(UserFacingError.message(e))),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBroadcastDialog() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Broadcast Notification',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bodyController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await AdvancedAdminService.instance.sendBroadcastNotification(
                  title: titleController.text,
                  body: bodyController.text,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  _addLog('📧 Broadcast sent: ${titleController.text}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Broadcast sent successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  _addLog('❌ Broadcast failed: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(UserFacingError.message(e))),
                  );
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showTargetedNotificationDialog() {
    final userIdsController = TextEditingController();
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Send Notification',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userIdsController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'User IDs (comma-separated)',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bodyController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final userIds = userIdsController.text
                    .split(',')
                    .map((id) => id.trim())
                    .where((id) => id.isNotEmpty)
                    .toList();
                await AdvancedAdminService.instance.sendPushNotification(
                  userIds: userIds,
                  title: titleController.text,
                  body: bodyController.text,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  _addLog('📧 Notification sent to ${userIds.length} users');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Notification sent successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  _addLog('❌ Notification failed: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(UserFacingError.message(e))),
                  );
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToCSV() async {
    try {
      _addLog('📊 Exporting analytics to CSV...');
      final csv = await AdvancedAdminService.instance.exportAnalyticsToCSV();
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
          '${directory.path}/analytics_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv);

      if (mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Analytics Export',
          ),
        );
        _addLog('✅ Analytics exported successfully');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Analytics exported successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _addLog('❌ Export failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserFacingError.message(e))),
        );
      }
    }
  }

  Future<void> _toggleMaintenanceMode(bool value) async {
    try {
      await AdvancedAdminService.instance.setMaintenanceMode(value);
      setState(() => _maintenanceMode = value);
      _addLog('⚙️ Maintenance mode: ${value ? 'enabled' : 'disabled'}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Maintenance mode ${value ? 'enabled' : 'disabled'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        _addLog('❌ Maintenance mode toggle failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserFacingError.message(e))),
        );
      }
    }
  }

  Future<void> _toggleFeatureFlag(String flag, bool value) async {
    try {
      await AdvancedAdminService.instance.setFeatureFlag(flag, value);
      setState(() => _featureFlags[flag] = value);
      _addLog('🎯 Feature flag $flag: ${value ? 'enabled' : 'disabled'}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Feature flag $flag ${value ? 'enabled' : 'disabled'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        _addLog('❌ Feature flag toggle failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserFacingError.message(e))),
        );
      }
    }
  }

  void _showAddFeatureFlagDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Add Feature Flag',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Flag Name',
            labelStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await AdvancedAdminService.instance.setFeatureFlag(
                  nameController.text,
                  false,
                );
                await _loadFeatureFlags();
                if (context.mounted) {
                  Navigator.pop(context);
                  _addLog('➕ Added feature flag: ${nameController.text}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Feature flag added')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  _addLog('❌ Add feature flag failed: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(UserFacingError.message(e))),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsList(List<Map<String, dynamic>> reports, String type) {
    if (reports.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No reports found',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.builder(
        itemCount: reports.length,
        itemBuilder: (context, index) {
          final report = reports[index];
          return _buildReportItem(report, type);
        },
      ),
    );
  }

  Widget _buildReportItem(Map<String, dynamic> report, String type) {
    final reason = report['reason'] ?? 'Unknown';
    final status = report['status'] ?? 'pending';
    final timestamp = report['timestamp'];
    final reporterId = report['reporterId'] ?? 'Unknown';
    final targetId = type == 'video' ? report['videoId'] : report['userId'];

    Color statusColor = Colors.orange;
    if (status == 'resolved') statusColor = Colors.green;
    if (status == 'dismissed') statusColor = Colors.grey;

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                type == 'video' ? Icons.video_library : Icons.person,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Report ID: ${report['id']}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Reason: $reason',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Target: ${targetId.toString().substring(0, 8)}...',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Reporter: ${reporterId.toString().substring(0, 8)}...',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatTimestamp(timestamp),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
              Row(
                children: [
                  if (status == 'pending') ...[
                    TextButton(
                      onPressed: () => _resolveReport(report['id'], type),
                      child: const Text(
                        'Resolve',
                        style: TextStyle(color: Colors.green, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _dismissReport(report['id'], type),
                      child: const Text(
                        'Dismiss',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _resolveReport(String reportId, String type) async {
    try {
      final collection = type == 'video' ? 'reports' : 'user_reports';
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(reportId)
          .update({
        'status': 'resolved',
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'actionTaken': 'Report resolved by admin',
      });
      _addLog('✅ Resolved $type report: $reportId');
    } catch (e) {
      _addLog('❌ Error resolving report: $e');
    }
  }

  Future<void> _dismissReport(String reportId, String type) async {
    try {
      final collection = type == 'video' ? 'reports' : 'user_reports';
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(reportId)
          .update({
        'status': 'dismissed',
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'actionTaken': 'Report dismissed by admin',
      });
      _addLog('❌ Dismissed $type report: $reportId');
    } catch (e) {
      _addLog('❌ Error dismissing report: $e');
    }
  }

  Future<void> _resolveAllPendingReports() async {
    try {
      // Resolve all pending video reports
      final videoReportsQuery = await FirebaseFirestore.instance
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in videoReportsQuery.docs) {
        batch.update(doc.reference, {
          'status': 'resolved',
          'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
          'reviewedAt': FieldValue.serverTimestamp(),
          'actionTaken': 'Bulk resolved by admin',
        });
      }

      // Resolve all pending user reports
      final userReportsQuery = await FirebaseFirestore.instance
          .collection('user_reports')
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in userReportsQuery.docs) {
        batch.update(doc.reference, {
          'status': 'resolved',
          'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
          'reviewedAt': FieldValue.serverTimestamp(),
          'actionTaken': 'Bulk resolved by admin',
        });
      }

      await batch.commit();
      _addLog('✅ Bulk resolved all pending reports');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All pending reports resolved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _addLog('❌ Error bulk resolving reports: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
