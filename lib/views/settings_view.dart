import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1220),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),
            
            // Search Field
            _buildSearchField(),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Account Section
                    _buildSection(
                      title: 'Account',
                      items: [
                        _buildSettingsItem(
                          icon: Icons.person,
                          title: 'Manage Account',
                          subtitle: 'Phone, email, password',
                          onTap: () => _navigateToPage(context, 'Manage Account'),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Privacy Section
                    _buildSection(
                      title: 'Privacy',
                      items: [
                        _buildSettingsItem(
                          icon: Icons.visibility,
                          title: 'Who can see your content',
                          subtitle: 'Control visibility settings',
                          onTap: () => _navigateToPage(context, 'Privacy Settings'),
                        ),
                        _buildSettingsItem(
                          icon: Icons.block,
                          title: 'Blocked Accounts',
                          subtitle: 'Manage blocked users',
                          onTap: () => _navigateToPage(context, 'Blocked Accounts'),
                        ),
                        _buildSettingsItem(
                          icon: Icons.alternate_email,
                          title: 'Mentions & Tags',
                          subtitle: 'Control who can mention you',
                          onTap: () => _navigateToPage(context, 'Mentions & Tags'),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Content & Activity Section
                    _buildSection(
                      title: 'Content & Activity',
                      items: [
                        _buildSettingsItem(
                          icon: Icons.notifications,
                          title: 'Notifications',
                          subtitle: 'Push & in-app notifications',
                          onTap: () => _navigateToPage(context, 'Notifications'),
                        ),
                        _buildSettingsItem(
                          icon: Icons.tune,
                          title: 'Content Preferences',
                          subtitle: 'Language, restricted mode, screen time',
                          onTap: () => _navigateToPage(context, 'Content Preferences'),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Support & About Section
                    _buildSection(
                      title: 'Support & About',
                      items: [
                        _buildSettingsItem(
                          icon: Icons.report_problem,
                          title: 'Report a Problem',
                          subtitle: 'Help us improve the app',
                          onTap: () => _navigateToPage(context, 'Report a Problem'),
                        ),
                        _buildSettingsItem(
                          icon: Icons.security,
                          title: 'Safety Center',
                          subtitle: 'Learn about safety features',
                          onTap: () => _navigateToPage(context, 'Safety Center'),
                        ),
                        _buildSettingsItem(
                          icon: Icons.rule,
                          title: 'Community Guidelines',
                          subtitle: 'Read our community rules',
                          onTap: () => _navigateToPage(context, 'Community Guidelines'),
                        ),
                        _buildSettingsItem(
                          icon: Icons.description,
                          title: 'Terms of Service & Privacy Policy',
                          subtitle: 'Legal information',
                          onTap: () => _navigateToPage(context, 'Terms & Privacy Policy'),
                        ),
                        _buildSettingsItem(
                          icon: Icons.info,
                          title: 'About',
                          subtitle: 'App version and info',
                          onTap: () => _navigateToPage(context, 'About'),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Footer Actions
                    _buildFooterActions(context),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1220),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Text(
            'Settings & Privacy',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search settings...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          border: InputBorder.none,
          icon: Icon(
            Icons.search,
            color: Colors.white.withOpacity(0.5),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: Icon(
                    Icons.clear,
                    color: Colors.white.withOpacity(0.5),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    // Filter based on search query
    if (_searchQuery.isNotEmpty &&
        !title.toLowerCase().contains(_searchQuery) &&
        !subtitle.toLowerCase().contains(_searchQuery)) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterActions(BuildContext context) {
    return Column(
      children: [
        // Switch Account Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _navigateToPage(context, 'Switch Account'),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Switch Account'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Add Account Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _navigateToPage(context, 'Add Account'),
            icon: const Icon(Icons.add),
            label: const Text('Add Account'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Log Out Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showLogOutDialog(context),
            icon: const Icon(Icons.logout),
            label: const Text('Log Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.2),
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showLogOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0E1220),
        title: const Text(
          'Log Out',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              fa.FirebaseAuth.instance.signOut();
              // Navigate back to login screen
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
            child: const Text(
              'Log Out',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToPage(BuildContext context, String pageName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _PlaceholderPage(title: pageName),
      ),
    );
  }
}

// Placeholder page for settings subsections
class _PlaceholderPage extends StatelessWidget {
  final String title;
  
  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1220),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              color: Colors.white.withOpacity(0.5),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This page will be implemented here',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
