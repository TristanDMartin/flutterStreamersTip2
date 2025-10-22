import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../services/advanced_admin_service.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AdvancedAdminPanel extends StatefulWidget {
  const AdvancedAdminPanel({super.key});

  @override
  State<AdvancedAdminPanel> createState() => _AdvancedAdminPanelState();
}

class _AdvancedAdminPanelState extends State<AdvancedAdminPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  Map<String, List<Map<String, dynamic>>> _searchResults = {};
  bool _isSearching = false;
  bool _maintenanceMode = false;
  Map<String, bool> _featureFlags = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadSystemSettings();
    _loadFeatureFlags();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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
          '⚡ Advanced Admin',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFF9248D2),
          labelColor: const Color(0xFF9248D2),
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: '🚫 Moderation'),
            Tab(text: '🔍 Search'),
            Tab(text: '📧 Notifications'),
            Tab(text: '📊 Analytics'),
            Tab(text: '📝 Activity'),
            Tab(text: '⚙️ Settings'),
            Tab(text: '📈 Charts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildModerationTab(),
          _buildSearchTab(),
          _buildNotificationsTab(),
          _buildAnalyticsTab(),
          _buildActivityTab(),
          _buildSettingsTab(),
          _buildChartsTab(),
        ],
      ),
    );
  }

  Widget _buildModerationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User Moderation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
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
            'Unban User',
            Icons.check_circle,
            Colors.green,
            () => _showUnbanUserDialog(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Content Moderation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            'Delete Video',
            Icons.delete_forever,
            Colors.red,
            () => _showDeleteVideoDialog(),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Delete Comment',
            Icons.remove_circle,
            Colors.orange,
            () => _showDeleteCommentDialog(),
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
      padding: const EdgeInsets.all(16),
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
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

  Widget _buildActivityTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: AdvancedAdminService.instance.getActivityHistory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
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
                  '${log['timestamp']?.toDate() ?? 'N/A'}\nAdmin: ${log['adminId'] ?? 'Unknown'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
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
            activeColor: const Color(0xFF9248D2),
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
                activeColor: const Color(0xFF9248D2),
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

  Widget _buildChartsTab() {
    return const Center(
      child: Text(
        'Charts coming soon...\nUse Flutter charts package',
        style: TextStyle(color: Colors.white54),
        textAlign: TextAlign.center,
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
          border: Border.all(color: color.withOpacity(0.3)),
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
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  void _showBanUserDialog() {
    final userIdController = TextEditingController();
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User banned successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
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
    // Similar to ban but with duration picker
    _showBanUserDialog(); // Placeholder
  }

  void _showUnbanUserDialog() {
    final userIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Unban User', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: userIdController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'User ID',
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
                await AdvancedAdminService.instance
                    .unbanUser(userIdController.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User unbanned successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Unban', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  void _showDeleteVideoDialog() {
    // Similar to ban user
    _showBanUserDialog(); // Placeholder
  }

  void _showDeleteCommentDialog() {
    // Similar to ban user
    _showBanUserDialog(); // Placeholder
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Broadcast sent successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
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
    // Similar to broadcast
    _showBroadcastDialog(); // Placeholder
  }

  Future<void> _exportToCSV() async {
    try {
      final csv = await AdvancedAdminService.instance.exportAnalyticsToCSV();
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
          '${directory.path}/analytics_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv);

      if (mounted) {
        await Share.shareXFiles([XFile(file.path)], text: 'Analytics Export');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Analytics exported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _toggleMaintenanceMode(bool value) async {
    try {
      await AdvancedAdminService.instance.setMaintenanceMode(value);
      setState(() => _maintenanceMode = value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Maintenance mode ${value ? 'enabled' : 'disabled'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _toggleFeatureFlag(String flag, bool value) async {
    try {
      await AdvancedAdminService.instance.setFeatureFlag(flag, value);
      setState(() => _featureFlags[flag] = value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Feature flag $flag ${value ? 'enabled' : 'disabled'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Feature flag added')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
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
}
