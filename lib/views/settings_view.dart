import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'about_view.dart';
import 'blocked_accounts_view.dart';
import 'community_guidelines_view.dart';
import 'content_preferences_view.dart';
import 'manage_account_view.dart';
import 'mentions_tags_view.dart';
import 'notifications_view.dart';
import 'privacy_settings_view.dart';
import 'contact_support_view.dart';
import 'safety_center_view.dart';
import 'terms_and_privacy_view.dart';
import '../widgets/two_factor_settings_view.dart';
import '../widgets/video_categorization_screen.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    this.initialSearchQuery,
  });

  final String? initialSearchQuery;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final TextEditingController _searchController;
  late String _searchQuery;

  bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  double get _headerTitleSize => _isIos ? 20 : 24;

  double get _sectionTitleSize => _isIos ? 16 : 18;

  double get _itemTitleSize => _isIos ? 14.5 : 16;

  double get _itemSubtitleSize => _isIos ? 12 : 13;

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialSearchQuery?.toLowerCase() ?? '';
    _searchController = TextEditingController(
      text: widget.initialSearchQuery ?? '',
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme c = Theme.of(context).colorScheme;
    final Widget scaffold = Scaffold(
      backgroundColor: c.surface,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[c.surface, c.surfaceContainerLow],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              _buildSearchField(context),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection(
                        context,
                        title: 'Account',
                        items: [
                          _buildSettingsItem(
                            context,
                            icon: Icons.person,
                            title: 'Manage Account',
                            subtitle: 'Phone, email, password',
                            onTap: () =>
                                _navigateToPage(context, 'Manage Account'),
                          ),
                          _buildSettingsItem(
                            context,
                            icon: Icons.link,
                            title: 'Linked Platforms',
                            subtitle:
                                'Reconnect YouTube, TikTok, Instagram, and more',
                            onTap: () =>
                                _navigateToPage(context, 'Linked Platforms'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        context,
                        title: 'Security',
                        items: [
                          _buildSettingsItem(
                            context,
                            icon: Icons.security,
                            title: 'Two-Factor Authentication',
                            subtitle: 'Add an extra layer of security',
                            onTap: () => _navigateToPage(
                                context, 'Two-Factor Authentication'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        context,
                        title: 'Privacy',
                        items: [
                          _buildSettingsItem(
                            context,
                            icon: Icons.visibility,
                            title: 'Who can see your content',
                            subtitle: 'Control visibility settings',
                            onTap: () =>
                                _navigateToPage(context, 'Privacy Settings'),
                          ),
                          _buildSettingsItem(
                            context,
                            icon: Icons.block,
                            title: 'Blocked Accounts',
                            subtitle: 'Manage blocked users',
                            onTap: () =>
                                _navigateToPage(context, 'Blocked Accounts'),
                          ),
                          _buildSettingsItem(
                            context,
                            icon: Icons.alternate_email,
                            title: 'Mentions & Tags',
                            subtitle: 'Control who can mention you',
                            onTap: () =>
                                _navigateToPage(context, 'Mentions & Tags'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        context,
                        title: 'Content & Activity',
                        items: [
                          _buildSettingsItem(
                            context,
                            icon: Icons.notifications,
                            title: 'Notifications',
                            subtitle: 'Push & in-app notifications',
                            onTap: () =>
                                _navigateToPage(context, 'Notifications'),
                          ),
                          _buildSettingsItem(
                            context,
                            icon: Icons.category,
                            title: 'Video Categorization',
                            subtitle: 'Categorize existing videos',
                            onTap: () => _navigateToPage(
                                context, 'Video Categorization'),
                          ),
                          _buildSettingsItem(
                            context,
                            icon: Icons.tune,
                            title: 'Content Preferences',
                            subtitle: 'Language, restricted mode, screen time',
                            onTap: () =>
                                _navigateToPage(context, 'Content Preferences'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        context,
                        title: 'Support & About',
                        items: [
                          _buildSettingsItem(
                            context,
                            icon: Icons.report_problem,
                            title: 'Report a Problem',
                            subtitle: 'Help us improve the app',
                            onTap: () =>
                                _navigateToPage(context, 'Report a Problem'),
                          ),
                          _buildSettingsItem(
                            context,
                            icon: Icons.security,
                            title: 'Safety Center',
                            subtitle: 'Learn about safety features',
                            onTap: () =>
                                _navigateToPage(context, 'Safety Center'),
                          ),
                          _buildSettingsItem(
                            context,
                            icon: Icons.rule,
                            title: 'Community Guidelines',
                            subtitle: 'Read our community rules',
                            onTap: () => _navigateToPage(
                                context, 'Community Guidelines'),
                          ),
                          _buildSettingsItem(
                            context,
                            icon: Icons.description,
                            title: 'Terms of Service & Privacy Policy',
                            subtitle: 'Legal information',
                            onTap: () => _navigateToPage(
                                context, 'Terms & Privacy Policy'),
                          ),
                          _buildSettingsItem(
                            context,
                            icon: Icons.info,
                            title: 'About',
                            subtitle: 'App version and info',
                            onTap: () => _navigateToPage(context, 'About'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (_isIos) {
      final MediaQueryData data = MediaQuery.of(context);
      return MediaQuery(
        data: data.copyWith(
          textScaler: data.textScaler.clamp(
            minScaleFactor: 0.82,
            maxScaleFactor: 1.05,
          ),
        ),
        child: scaffold,
      );
    }
    return scaffold;
  }

  Widget _buildHeader(BuildContext context) {
    final Color on = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 18, 10),
        decoration: BoxDecoration(
          color: on.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: on.withValues(alpha: 0.14),
          ),
          boxShadow: [
            BoxShadow(
              color: on.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back, color: on),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Settings & Privacy',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: on,
                  fontSize: _headerTitleSize,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final Color on = Theme.of(context).colorScheme.onSurface;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: on.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: on.withValues(alpha: 0.16),
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
        style: TextStyle(color: on),
        decoration: InputDecoration(
          hintText: 'Search settings...',
          hintStyle: TextStyle(color: on.withValues(alpha: 0.5)),
          border: InputBorder.none,
          icon: Icon(
            Icons.search,
            color: on.withValues(alpha: 0.5),
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
                    color: on.withValues(alpha: 0.5),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget?> items,
  }) {
    final ColorScheme c = Theme.of(context).colorScheme;
    final Color on = c.onSurface;
    final visibleItems = items.whereType<Widget>().toList(growable: false);
    if (visibleItems.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: on,
            fontSize: _sectionTitleSize,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
            shadows: [
              Shadow(
                color: c.shadow,
                offset: const Offset(0, 1),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: on.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: on.withValues(alpha: 0.14),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: on.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              for (int index = 0; index < visibleItems.length; index++) ...[
                if (index > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: on.withValues(alpha: 0.08),
                  ),
                visibleItems[index],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget? _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    if (_searchQuery.isNotEmpty &&
        !title.toLowerCase().contains(_searchQuery) &&
        !subtitle.toLowerCase().contains(_searchQuery)) {
      return null;
    }
    final Color on = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    on.withValues(alpha: 0.16),
                    on.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: on.withValues(alpha: 0.12),
                ),
              ),
              child: Icon(
                icon,
                color: on,
                size: 21,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: on,
                      fontSize: _itemTitleSize,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: on.withValues(alpha: 0.66),
                      fontSize: _itemSubtitleSize,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.arrow_forward_ios,
              color: on.withValues(alpha: 0.5),
              size: 15,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPage(BuildContext context, String pageName) {
    switch (pageName) {
      case 'Manage Account':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ManageAccountView(),
          ),
        );
        return;
      case 'Two-Factor Authentication':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const TwoFactorSettingsView(),
          ),
        );
        return;
      case 'Linked Platforms':
        final ColorScheme cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: const Text(
              'Linked platforms are coming soon. You\'ll be able to '
              'connect YouTube, TikTok, Instagram, and more.',
            ),
            backgroundColor: cs.inverseSurface,
            action: SnackBarAction(
              label: 'OK',
              textColor: cs.onInverseSurface,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
        return;
      case 'Blocked Accounts':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const BlockedAccountsView(),
          ),
        );
        return;
      case 'Privacy Settings':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const PrivacySettingsView(),
          ),
        );
        return;
      case 'Mentions & Tags':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const MentionsTagsView(),
          ),
        );
        return;
      case 'Notifications':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const NotificationsView(),
          ),
        );
        return;
      case 'Video Categorization':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const VideoCategorizationScreen(),
          ),
        );
        return;
      case 'Content Preferences':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ContentPreferencesView(),
          ),
        );
        return;
      case 'Report a Problem':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ContactSupportView(),
          ),
        );
        return;
      case 'Safety Center':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const SafetyCenterView(),
          ),
        );
        return;
      case 'Community Guidelines':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const CommunityGuidelinesView(),
          ),
        );
        return;
      case 'Terms & Privacy Policy':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const TermsAndPrivacyView(),
          ),
        );
        return;
      case 'About':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const AboutView(),
          ),
        );
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$pageName is not available yet.'),
          ),
        );
        break;
    }
  }
}
