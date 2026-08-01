import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../core/theme/support_shell_style.dart';
import '../core/feature_flags.dart';
import '../components/onboarding/contextual_tips_service.dart';
import '../features/analytics/creator_intelligence_view.dart';
import '../features/analytics/creator_video_insights_view.dart';
import 'linked_platforms_view.dart';
import '../routing/app_navigator.dart';
import '../routing/app_routes.dart';
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final Widget scaffold = Scaffold(
      backgroundColor: shell.scaffold,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: shell.pageGradient,
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
                          if (FeatureFlags.linkedPlatforms)
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
                        title: 'Creator Analytics',
                        items: <Widget?>[
                          _buildSettingsItem(
                            context,
                            icon: Icons.bar_chart_rounded,
                            title: 'Creator Intelligence',
                            subtitle:
                                'Personalized insights, trends, and next steps',
                            onTap: () =>
                                _navigateToPage(context, 'Creator Intelligence'),
                          ),
                          _buildSettingsItem(
                            context,
                            icon: Icons.insights_rounded,
                            title: 'Creator Insights',
                            subtitle: 'Views, engagement, audience, and retention',
                            onTap: () =>
                                _navigateToPage(context, 'Video Insights'),
                          ),
                          _buildSettingsItem(
                            context,
                            icon: Icons.summarize_rounded,
                            title: 'Weekly Report',
                            subtitle:
                                'Basic recap free; Pro growth and Studio business depth',
                            onTap: () =>
                                _navigateToPage(context, 'Weekly Report'),
                          ),
                          _buildSettingsItem(
                            context,
                            icon: Icons.groups_rounded,
                            title: 'Team & Automation',
                            subtitle:
                                'Assignments, approvals, automation, and exports',
                            onTap: () =>
                                _navigateToPage(context, 'Team & Automation'),
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
                          _buildSettingsItem(
                            context,
                            icon: Icons.explore_rounded,
                            title: 'Replay onboarding tips',
                            subtitle:
                                'Show contextual hints again as you explore',
                            onTap: () => _resetOnboardingTips(context),
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 18, 10),
        decoration: BoxDecoration(
          color: shell.surfaceCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: shell.surfaceCardBorder),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: shell.shadowSoft,
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back_rounded, color: shell.onChrome),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Settings & Privacy',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: shell.onChrome,
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: shell.panelSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: shell.panelBorder),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (String value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        style: TextStyle(color: shell.onChrome),
        decoration: InputDecoration(
          hintText: 'Search settings...',
          hintStyle: TextStyle(color: shell.muted),
          border: InputBorder.none,
          icon: Icon(Icons.search_rounded, color: shell.iconDim),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: Icon(Icons.clear_rounded, color: shell.iconDim),
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final List<Widget> visibleItems =
        items.whereType<Widget>().toList(growable: false);
    if (visibleItems.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            color: shell.onChrome,
            fontSize: _sectionTitleSize,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: shell.surfaceCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: shell.surfaceCardBorder),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: shell.shadowSoft,
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              for (int index = 0;
                  index < visibleItems.length;
                  index++) ...<Widget>[
                if (index > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: c.outlineVariant.withValues(alpha: 0.45),
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: shell.chipUnselectedBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: shell.chipUnselectedBorder),
              ),
              child: Icon(
                icon,
                color: shell.onChrome,
                size: 21,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      color: shell.onChrome,
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
                      color: shell.muted,
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
              Icons.arrow_forward_ios_rounded,
              color: shell.iconDim,
              size: 15,
            ),
          ],
        ),
      ),
    ),
    );
  }

  void _pushSettingsPage(BuildContext context, Widget page, String routeName) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: routeName),
        builder: (BuildContext context) => page,
      ),
    );
  }

  void _navigateToPage(BuildContext context, String pageName) {
    switch (pageName) {
      case 'Manage Account':
        _pushSettingsPage(
          context,
          const ManageAccountView(),
          '${AppRoutes.settings}/manage-account',
        );
        return;
      case 'Two-Factor Authentication':
        _pushSettingsPage(
          context,
          const TwoFactorSettingsView(),
          '${AppRoutes.settings}/two-factor',
        );
        return;
      case 'Linked Platforms':
        _pushSettingsPage(
          context,
          const LinkedPlatformsView(),
          AppRoutes.linkedPlatforms,
        );
        return;
      case 'Creator Intelligence':
        _pushSettingsPage(
          context,
          const CreatorIntelligenceView(),
          AppRoutes.creatorIntelligence,
        );
        return;
      case 'Video Insights':
        _pushSettingsPage(
          context,
          const CreatorVideoInsightsView(),
          AppRoutes.videoInsights,
        );
        return;
      case 'Weekly Report':
        AppNavigator.openWeeklyReport(context);
        return;
      case 'Team & Automation':
        AppNavigator.openStudioTeamControl(context);
        return;
      case 'Blocked Accounts':
        _pushSettingsPage(
          context,
          const BlockedAccountsView(),
          '${AppRoutes.settings}/blocked-accounts',
        );
        return;
      case 'Privacy Settings':
        _pushSettingsPage(
          context,
          const PrivacySettingsView(),
          '${AppRoutes.settings}/privacy',
        );
        return;
      case 'Mentions & Tags':
        _pushSettingsPage(
          context,
          const MentionsTagsView(),
          '${AppRoutes.settings}/mentions-tags',
        );
        return;
      case 'Notifications':
        _pushSettingsPage(
          context,
          const NotificationsView(),
          '${AppRoutes.settings}/notifications',
        );
        return;
      case 'Video Categorization':
        _pushSettingsPage(
          context,
          const VideoCategorizationScreen(),
          '${AppRoutes.settings}/video-categorization',
        );
        return;
      case 'Content Preferences':
        _pushSettingsPage(
          context,
          const ContentPreferencesView(),
          '${AppRoutes.settings}/content-preferences',
        );
        return;
      case 'Report a Problem':
        _pushSettingsPage(
          context,
          const ContactSupportView(),
          '${AppRoutes.settings}/contact-support',
        );
        return;
      case 'Safety Center':
        _pushSettingsPage(
          context,
          const SafetyCenterView(),
          '${AppRoutes.settings}/safety-center',
        );
        return;
      case 'Community Guidelines':
        _pushSettingsPage(
          context,
          const CommunityGuidelinesView(),
          '${AppRoutes.settings}/community-guidelines',
        );
        return;
      case 'Terms & Privacy Policy':
        _pushSettingsPage(
          context,
          const TermsAndPrivacyView(),
          '${AppRoutes.settings}/terms-privacy',
        );
        return;
      case 'About':
        _pushSettingsPage(
          context,
          const AboutView(),
          '${AppRoutes.settings}/about',
        );
        return;
      default:
        break;
    }
  }

  Future<void> _resetOnboardingTips(BuildContext context) async {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'local';
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String prefix = 'streamerstip.first_tap_tip.$userId.';
    for (final String key in prefs.getKeys().where(
          (String key) => key.startsWith(prefix),
        )) {
      await prefs.remove(key);
    }
    if (userId != 'local') {
      await ContextualTipsService().resetAllTips(userId);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Onboarding tips will appear again as you explore.'),
      ),
    );
  }
}
