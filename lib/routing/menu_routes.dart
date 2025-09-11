// Example routing configuration for the new Menu system
// Add these routes to your existing GoRouter configuration

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../views/menu_view.dart';
import '../views/settings_view.dart';

// Example route configuration
final menuRoutes = [
  // Main Menu
  GoRoute(
    path: '/menu',
    builder: (context, state) => const MenuView(),
  ),
  
  // Settings & Privacy
  GoRoute(
    path: '/settings',
    builder: (context, state) => const SettingsView(),
  ),
  
  // Settings subsections
  GoRoute(
    path: '/settings/account',
    builder: (context, state) => const PlaceholderSettingsPage(title: 'Manage Account'),
  ),
  GoRoute(
    path: '/settings/privacy',
    builder: (context, state) => const PlaceholderSettingsPage(title: 'Privacy Settings'),
  ),
  GoRoute(
    path: '/settings/blocked',
    builder: (context, state) => const PlaceholderSettingsPage(title: 'Blocked Accounts'),
  ),
  GoRoute(
    path: '/settings/mentions',
    builder: (context, state) => const PlaceholderSettingsPage(title: 'Mentions & Tags'),
  ),
  GoRoute(
    path: '/settings/notifications',
    builder: (context, state) => const PlaceholderSettingsPage(title: 'Notifications'),
  ),
  GoRoute(
    path: '/settings/preferences',
    builder: (context, state) => const PlaceholderSettingsPage(title: 'Content Preferences'),
  ),
  GoRoute(
    path: '/settings/report',
    builder: (context, state) => const PlaceholderSettingsPage(title: 'Report a Problem'),
  ),
  GoRoute(
    path: '/settings/safety',
    builder: (context, state) => const PlaceholderSettingsPage(title: 'Safety Center'),
  ),
  GoRoute(
    path: '/settings/guidelines',
    builder: (context, state) => const PlaceholderSettingsPage(title: 'Community Guidelines'),
  ),
  GoRoute(
    path: '/settings/legal',
    builder: (context, state) => const PlaceholderSettingsPage(title: 'Terms & Privacy Policy'),
  ),
  GoRoute(
    path: '/settings/about',
    builder: (context, state) => const PlaceholderSettingsPage(title: 'About'),
  ),
  
  // Account management
  GoRoute(
    path: '/account/switch',
    builder: (context, state) => const PlaceholderSettingsPage(title: 'Switch Account'),
  ),
  GoRoute(
    path: '/account/add',
    builder: (context, state) => const PlaceholderSettingsPage(title: 'Add Account'),
  ),
  
  // Existing pages (keep your current routes)
  GoRoute(
    path: '/bookmarks',
    builder: (context, state) => const PlaceholderSettingsPage(title: 'Bookmarks'),
  ),
  GoRoute(
    path: '/scheduled',
    builder: (context, state) => const PlaceholderSettingsPage(title: 'Scheduled Content'),
  ),
  GoRoute(
    path: '/insights',
    builder: (context, state) => const PlaceholderSettingsPage(title: 'Insights'),
  ),
  GoRoute(
    path: '/analytics',
    builder: (context, state) => const PlaceholderSettingsPage(title: 'Analytics'),
  ),
];

// Placeholder widget for existing pages
class PlaceholderSettingsPage extends StatelessWidget {
  final String title;
  
  const PlaceholderSettingsPage({
    super.key,
    required this.title,
  });

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
              color: Colors.white.withValues(alpha: 0.5),
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
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
