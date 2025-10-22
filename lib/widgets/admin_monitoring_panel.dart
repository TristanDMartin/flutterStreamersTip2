import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

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

  StreamSubscription<QuerySnapshot>? _usersSub;
  StreamSubscription<QuerySnapshot>? _videosSub;
  StreamSubscription<QuerySnapshot>? _messagesSub;
  StreamSubscription<QuerySnapshot>? _notificationsSub;

  int _totalUsers = 0;
  int _totalVideos = 0;
  int _onlineUsers = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _startMonitoring();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usersSub?.cancel();
    _videosSub?.cancel();
    _messagesSub?.cancel();
    _notificationsSub?.cancel();
    super.dispose();
  }

  void _startMonitoring() {
    _addLog('🟢 Admin monitoring started');
    _monitorUsers();
    _monitorVideos();
    _monitorMessages();
    _monitorNotifications();
    _fetchStats();
  }

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, '${DateTime.now().toString().split('.')[0]} - $message');
      if (_logs.length > 100) _logs.removeLast();
    });
  }

  void _monitorUsers() {
    _usersSub = FirebaseFirestore.instance
        .collection('users')
        .orderBy('lastSeen', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _activeUsers.clear();
        _onlineUsers = 0;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          if (data['onlineStatus'] == 'online') _onlineUsers++;
          _activeUsers.add({
            'id': doc.id,
            'username': data['username'] ?? 'Unknown',
            'displayName': data['displayName'] ?? 'Unknown',
            'onlineStatus': data['onlineStatus'] ?? 'offline',
            'lastSeen': data['lastSeen'],
          });
        }
      });
      _addLog('👥 Updated active users: ${_activeUsers.length}');
    });
  }

  void _monitorVideos() {
    _videosSub = FirebaseFirestore.instance
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _recentVideos.clear();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          _recentVideos.add({
            'id': doc.id,
            'caption': data['caption'] ?? 'No caption',
            'userId': data['userId'] ?? 'Unknown',
            'createdAt': data['createdAt'],
            'views': data['views'] ?? 0,
            'likes': data['likeCount'] ?? 0,
            'status': data['status'] ?? 'unknown',
          });
        }
      });
      _addLog('📹 Updated recent videos: ${_recentVideos.length}');
    });
  }

  void _monitorMessages() {
    _messagesSub = FirebaseFirestore.instance
        .collectionGroup('messages')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _recentMessages.clear();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          _recentMessages.add({
            'id': doc.id,
            'from': data['from'] ?? 'Unknown',
            'text': data['text'] ?? '',
            'timestamp': data['timestamp'],
          });
        }
      });
      _addLog('💬 Updated recent messages: ${_recentMessages.length}');
    });
  }

  void _monitorNotifications() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    _notificationsSub = FirebaseFirestore.instance
        .collectionGroup('items')
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

  Future<void> _fetchStats() async {
    try {
      final usersCount =
          await FirebaseFirestore.instance.collection('users').count().get();
      final videosCount =
          await FirebaseFirestore.instance.collection('videos').count().get();
      setState(() {
        _totalUsers = usersCount.count ?? 0;
        _totalVideos = videosCount.count ?? 0;
      });
      _addLog('📊 Fetched stats - Users: $_totalUsers, Videos: $_totalVideos');
    } catch (e) {
      _addLog('❌ Error fetching stats: $e');
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
          '🔍 Admin Monitoring',
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
          _buildLogsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatCard('Total Users', _totalUsers.toString(), Icons.people),
          const SizedBox(height: 12),
          _buildStatCard(
            'Online Users',
            _onlineUsers.toString(),
            Icons.circle,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Total Videos',
            _totalVideos.toString(),
            Icons.video_library,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Recent Messages',
            _recentMessages.length.toString(),
            Icons.message,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Notifications',
            _recentNotifications.length.toString(),
            Icons.notifications,
          ),
          const SizedBox(height: 24),
          Text(
            '🔴 Live Activity',
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

  Widget _buildUsersTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeUsers.length,
      itemBuilder: (context, index) {
        final user = _activeUsers[index];
        final isOnline = user['onlineStatus'] == 'online';
        return Card(
          color: const Color(0xFF1A1A1A),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
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
              '@${user['username']} • ${isOnline ? 'Online' : _formatTimestamp(user['lastSeen'])}',
              style: TextStyle(
                color: isOnline ? Colors.green : Colors.white54,
                fontSize: 12,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new, color: Colors.white54),
              onPressed: () {
                _addLog('👁️ Viewing user: ${user['username']}');
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideosTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recentVideos.length,
      itemBuilder: (context, index) {
        final video = _recentVideos[index];
        return Card(
          color: const Color(0xFF1A1A1A),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
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
              '${_formatTimestamp(video['createdAt'])} • ${video['views']} views • ${video['likes']} likes\nStatus: ${video['status']}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white54),
              onPressed: () {
                _showVideoDetails(video);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessagesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recentMessages.length,
      itemBuilder: (context, index) {
        final message = _recentMessages[index];
        return Card(
          color: const Color(0xFF1A1A1A),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(
              Icons.message,
              color: Color(0xFF9248D2),
            ),
            title: Text(
              'From: ${message['from']}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${message['text']}\n${_formatTimestamp(message['timestamp'])}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        return _buildLogItem(_logs[index]);
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
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
