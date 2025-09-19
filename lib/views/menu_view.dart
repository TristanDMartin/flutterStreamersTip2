import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'settings_view.dart';
import '../pages/bookmark_view.dart';
import '../widgets/account_management_menu.dart';
import '../widgets/insights_view.dart';

class MenuView extends StatelessWidget {
  const MenuView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with close button
                _buildHeader(context),
                
                const SizedBox(height: 24),
                
                // Profile Section
                _buildProfileSection(context),
                
                const SizedBox(height: 32),
                
                // Menu Grid
                _buildMenuGrid(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Time display (placeholder)
        const Text(
          '10:45',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        // Close button
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.close,
            color: Colors.white,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    final user = fa.FirebaseAuth.instance.currentUser;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile Avatar Card
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF9248D2), Color(0xFF7768DF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: user?.photoURL != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      user!.photoURL!,
                      fit: BoxFit.cover,
                      width: 80,
                      height: 80,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 40,
                  ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // User Info
        Text(
          user?.displayName ?? 'User',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '@${user?.email?.split('@')[0] ?? 'username'}',
          style: TextStyle(
            color: Colors.white.withValues(alpha:0.7),
            fontSize: 16,
          ),
        ),
      ],
    );
  }


  Widget _buildMenuGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildMenuCard(
          context,
          icon: Icons.star_outline,
          title: 'Rate App',
          subtitle: 'Rate us 5-stars',
          onTap: () => _navigateToPage(context, 'Rate App'),
          isPrimary: true,
        ),
        _buildMenuCard(
          context,
          icon: Icons.support_agent,
          title: 'Contact Support',
          subtitle: 'Get help & support',
          onTap: () => _navigateToPage(context, 'Contact Support'),
        ),
        _buildMenuCard(
          context,
          icon: Icons.favorite_outline,
          title: 'Try Premium',
          subtitle: 'Try premium features',
          onTap: () => _navigateToPage(context, 'Try Premium'),
        ),
        _buildMenuCard(
          context,
          icon: Icons.bookmark,
          title: 'Bookmarks',
          subtitle: 'Saved content',
          onTap: () => _navigateToPage(context, 'Bookmarks'),
        ),
        _buildMenuCard(
          context,
          icon: Icons.schedule,
          title: 'Scheduled',
          subtitle: 'Manage posts',
          onTap: () => _navigateToPage(context, 'Scheduled Content'),
        ),
        _buildMenuCard(
          context,
          icon: Icons.insights,
          title: 'Insights',
          subtitle: 'Performance data',
          onTap: () => _navigateToPage(context, 'Insights'),
        ),
        _buildMenuCard(
          context,
          icon: Icons.settings,
          title: 'Settings',
          subtitle: 'Settings & Privacy',
          onTap: () => _navigateToSettings(context),
        ),
        _buildMenuCard(
          context,
          icon: Icons.logout,
          title: 'Log Out',
          subtitle: 'Sign out of account',
          onTap: () => _showLogOutDialog(context),
        ),
      ],
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isPrimary 
              ? const Color(0xFF9248D2) // Purple for primary card
              : Colors.white.withValues(alpha: 0.1), // Semi-transparent white for other cards
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha:0.8),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPage(BuildContext context, String pageName) {
    Widget page;
    
    switch (pageName) {
      case 'Bookmarks':
        page = const BookmarkView();
        break;
      case 'Insights':
        page = const InsightsView(
          videoId: 'general-insights',
          videoTitle: 'General Insights',
        );
        break;
      default:
        page = _PlaceholderPage(title: pageName);
        break;
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => page,
      ),
    );
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsView(),
      ),
    );
  }

        void _showLogOutDialog(BuildContext context) {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (context) => Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            const Text(
              'Account Management',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your account settings and sign out',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            
            // Account Management Menu
            const AccountManagementMenu(),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// Placeholder page for existing functionality
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
              color: Colors.white.withValues(alpha:0.5),
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
                color: Colors.white.withValues(alpha:0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
