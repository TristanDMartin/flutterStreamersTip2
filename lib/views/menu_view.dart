import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings/appearance_settings_view.dart';
import 'settings_view.dart';
import '../pages/bookmark_view.dart';
import '../widgets/account_management_menu.dart';
import 'manage_posts_view.dart';
import 'contact_support_view.dart';
import '../constants/app_colors.dart';
import 'upgrade_view.dart';
import '../routing/app_navigator.dart';
import '../routing/app_routes.dart';
import '../utils/avatar_url_resolver.dart';
import '../utils/responsive_layout.dart';

class MenuView extends ConsumerStatefulWidget {
  const MenuView({super.key});

  @override
  ConsumerState<MenuView> createState() => _MenuViewState();
}

class _MenuViewState extends ConsumerState<MenuView> {
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = fa.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted && doc.exists) {
        setState(() {
          _userData = doc.data();
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _MenuMetrics.of(context);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: isLight ? const Color(0xFF0F172A) : colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: metrics.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopSurface(context, metrics),
              SizedBox(height: metrics.sectionGap),
              _buildMenuSectionHeader(context, metrics),
              SizedBox(height: metrics.gridTopGap),
              _buildMenuGrid(context, metrics),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopSurface(BuildContext context, _MenuMetrics metrics) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: metrics.surfacePadding,
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.08)
            : colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(metrics.surfaceRadius),
        border: Border.all(
          color: isLight
              ? Colors.white.withValues(alpha: 0.22)
              : colorScheme.onSurface.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, metrics),
          SizedBox(height: metrics.profileTopGap),
          _buildProfileSection(context, metrics),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, _MenuMetrics metrics) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color onSurface = isLight ? Colors.white : colorScheme.onSurface;
    final now = TimeOfDay.now();
    final formattedHour = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final formattedMinute = now.minute.toString().padLeft(2, '0');
    final period = now.period == DayPeriod.am ? 'AM' : 'PM';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Menu',
              style: TextStyle(
                color: onSurface,
                fontSize: metrics.titleFontSize,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$formattedHour:$formattedMinute $period',
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.68),
                fontSize: metrics.timeFontSize,
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: onSurface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(metrics.closeRadius),
            border: Border.all(
              color: onSurface.withValues(alpha: 0.12),
            ),
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            constraints: BoxConstraints.tightFor(
              width: metrics.closeButtonSize,
              height: metrics.closeButtonSize,
            ),
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.close,
              color: onSurface,
              size: metrics.closeIconSize,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSection(BuildContext context, _MenuMetrics metrics) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color onSurface = isLight ? Colors.white : colorScheme.onSurface;
    final user = fa.FirebaseAuth.instance.currentUser;
    final avatarURL = resolveAvatarUrl(_userData);
    final displayName =
        _userData?['displayName'] as String? ?? user?.displayName ?? 'User';
    final username = _userData?['username'] as String? ??
        user?.email?.split('@')[0] ??
        'username';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAvatarWithGradientRing(context, avatarURL, metrics),
            SizedBox(width: metrics.profileTextGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onSurface,
                      fontSize: metrics.profileNameFontSize,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(height: metrics.usernameGap),
                  Text(
                    '@$username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onSurface.withValues(alpha: 0.7),
                      fontSize: metrics.usernameFontSize,
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(height: metrics.profileDescriptionGap),
                  Text(
                    'Quick access to your account, saved content, and settings.',
                    maxLines: metrics.compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onSurface.withValues(alpha: 0.64),
                      fontSize: metrics.descriptionFontSize,
                      fontWeight: FontWeight.w500,
                      height: 1.24,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuSectionHeader(
    BuildContext context,
    _MenuMetrics metrics,
  ) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color onSurface =
        isLight ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: metrics.sectionHeaderInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Access',
            style: TextStyle(
              color: onSurface,
              fontSize: metrics.sectionTitleFontSize,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Everything you need from one calm place.',
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.66),
              fontSize: metrics.sectionSubtitleFontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarWithGradientRing(
    BuildContext context,
    String? avatarURL,
    _MenuMetrics metrics,
  ) {
    final Color on = Theme.of(context).colorScheme.onSurface;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: metrics.avatarOuterSize,
          height: metrics.avatarOuterSize,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                Color(0xFFFF6CAB),
                Color(0xFF8E54E9),
                Color(0xFF3D99F7),
                Color(0xFFFF6CAB),
              ],
            ),
          ),
          child: Center(
            child: Container(
              width: metrics.avatarInnerSize,
              height: metrics.avatarInnerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on.withValues(alpha: 0.12),
              ),
              child: ClipOval(
                child: avatarURL != null && avatarURL.isNotEmpty
                    ? Image.network(
                        avatarURL,
                        key: ValueKey(avatarURL),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.person,
                          color: on,
                          size: metrics.avatarIconSize,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        color: on,
                        size: metrics.avatarIconSize,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuGrid(BuildContext context, _MenuMetrics metrics) {
    final cards = <Widget>[
      _buildMenuCard(
        context,
        metrics: metrics,
        icon: Icons.bar_chart_rounded,
        title: 'Creator Intelligence',
        subtitle: 'Insights, trends & personalized next steps',
        onTap: () => AppNavigator.openCreatorIntelligence(context),
      ),
      _buildMenuCard(
        context,
        metrics: metrics,
        icon: Icons.insights_rounded,
        title: 'Creator Insights',
        subtitle: 'Per-video performance & audience',
        onTap: () => AppNavigator.openVideoInsights(context),
      ),
      _buildMenuCard(
        context,
        metrics: metrics,
        icon: Icons.support_agent,
        title: 'Contact Support',
        subtitle: 'Get help & support',
        onTap: () => _navigateToPage(
          context,
          const ContactSupportView(),
          '${AppRoutes.settings}/contact-support',
        ),
      ),
      _buildMenuCard(
        context,
        metrics: metrics,
        icon: Icons.workspace_premium_rounded,
        title: 'Upgrade',
        subtitle: 'View tiers & subscribe',
        isPrimary: true,
        onTap: () => _navigateToPage(
          context,
          const UpgradeView(),
          AppRoutes.upgrade,
        ),
      ),
      _buildMenuCard(
        context,
        metrics: metrics,
        icon: Icons.bookmark,
        title: 'Bookmarks',
        subtitle: 'Saved content',
        onTap: () => _navigateToPage(
          context,
          const BookmarkView(),
          '/bookmarks',
        ),
      ),
      _buildMenuCard(
        context,
        metrics: metrics,
        icon: Icons.schedule,
        title: 'Scheduled',
        subtitle: 'Manage posts',
        onTap: () => _navigateToManagePosts(context),
      ),
      _buildMenuCard(
        context,
        metrics: metrics,
        icon: Icons.settings,
        title: 'Settings',
        subtitle: 'Settings & Privacy',
        onTap: () => _navigateToSettings(context),
      ),
      _buildMenuCard(
        context,
        metrics: metrics,
        icon: Icons.palette_outlined,
        title: 'Appearance',
        subtitle: 'Light, dark, or system',
        onTap: () => _navigateToPage(
          context,
          const AppearanceSettingsView(),
          '${AppRoutes.settings}/appearance',
        ),
      ),
      _buildMenuCard(
        context,
        metrics: metrics,
        icon: Icons.logout,
        title: 'Log Out',
        subtitle: 'Sign out of account',
        onTap: () => _showLogOutDialog(context),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: metrics.gridSpacing,
        mainAxisSpacing: metrics.gridSpacing,
        childAspectRatio: metrics.cardAspectRatio,
      ),
      itemBuilder: (context, index) => cards[index],
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required _MenuMetrics metrics,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color on = isLight ? Colors.white : colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: metrics.cardPadding,
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: AppColors.supportAccentGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isPrimary
              ? null
              : isLight
                  ? Colors.white.withValues(alpha: 0.10)
                  : on.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(metrics.cardRadius),
          border: Border.all(
            color: on.withValues(
              alpha: isPrimary ? 0.22 : (isLight ? 0.22 : 0.12),
            ),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow,
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: metrics.cardIconBoxSize,
              height: metrics.cardIconBoxSize,
              decoration: BoxDecoration(
                color: on.withValues(
                  alpha: isPrimary ? 0.18 : (isLight ? 0.14 : 0.1),
                ),
                borderRadius: BorderRadius.circular(metrics.cardIconRadius),
                border: Border.all(
                  color: on.withValues(alpha: 0.12),
                ),
              ),
              child: Icon(
                icon,
                color: isPrimary ? Colors.white : on,
                size: metrics.cardIconSize,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isPrimary ? Colors.white : on,
                    fontSize: metrics.cardTitleFontSize,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: metrics.cardSubtitleGap),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isPrimary
                        ? Colors.white.withValues(alpha: 0.85)
                        : on.withValues(alpha: 0.75),
                    fontSize: metrics.cardSubtitleFontSize,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: metrics.cardActionGap),
                Row(
                  children: [
                    Text(
                      'Open',
                      style: TextStyle(
                        color: isPrimary
                            ? Colors.white.withValues(alpha: 0.9)
                            : on.withValues(alpha: 0.82),
                        fontSize: metrics.cardActionFontSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: metrics.cardArrowGap),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: isPrimary
                          ? Colors.white.withValues(alpha: 0.9)
                          : on.withValues(alpha: 0.82),
                      size: metrics.cardArrowSize,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPage(BuildContext context, Widget page, String routeName) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: routeName),
        builder: (BuildContext context) => page,
      ),
    );
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.settings),
        builder: (BuildContext context) => const SettingsView(),
      ),
    );
  }

  void _navigateToManagePosts(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.managePosts),
        builder: (BuildContext context) => const ManagePostsView(),
      ),
    );
  }

  void _showLogOutDialog(BuildContext context) {
    final metrics = _MenuMetrics.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        final ColorScheme colorScheme = Theme.of(sheetContext).colorScheme;
        final Color on = colorScheme.onSurface;
        return Container(
          padding: EdgeInsets.fromLTRB(
            metrics.sheetHorizontalPadding,
            16,
            metrics.sheetHorizontalPadding,
            24 + MediaQuery.paddingOf(sheetContext).bottom,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: on.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: on.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Account Management',
                style: TextStyle(
                  color: on,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage your account settings and sign out from one place.',
                style: TextStyle(
                  color: on.withValues(alpha: 0.7),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: EdgeInsets.all(metrics.sheetInnerPadding),
                decoration: BoxDecoration(
                  color: on.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: on.withValues(alpha: 0.1),
                  ),
                ),
                child: const AccountManagementMenu(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _MenuMetrics {
  const _MenuMetrics({
    required this.compact,
    required this.pagePadding,
    required this.surfacePadding,
    required this.surfaceRadius,
    required this.sectionGap,
    required this.gridTopGap,
    required this.profileTopGap,
    required this.titleFontSize,
    required this.timeFontSize,
    required this.closeButtonSize,
    required this.closeIconSize,
    required this.closeRadius,
    required this.avatarOuterSize,
    required this.avatarInnerSize,
    required this.avatarIconSize,
    required this.profileTextGap,
    required this.profileNameFontSize,
    required this.usernameFontSize,
    required this.usernameGap,
    required this.descriptionFontSize,
    required this.profileDescriptionGap,
    required this.sectionHeaderInset,
    required this.sectionTitleFontSize,
    required this.sectionSubtitleFontSize,
    required this.gridSpacing,
    required this.cardAspectRatio,
    required this.cardPadding,
    required this.cardRadius,
    required this.cardIconBoxSize,
    required this.cardIconRadius,
    required this.cardIconSize,
    required this.cardTitleFontSize,
    required this.cardSubtitleFontSize,
    required this.cardSubtitleGap,
    required this.cardActionFontSize,
    required this.cardActionGap,
    required this.cardArrowGap,
    required this.cardArrowSize,
    required this.sheetHorizontalPadding,
    required this.sheetInnerPadding,
  });

  final bool compact;
  final EdgeInsets pagePadding;
  final EdgeInsets surfacePadding;
  final double surfaceRadius;
  final double sectionGap;
  final double gridTopGap;
  final double profileTopGap;
  final double titleFontSize;
  final double timeFontSize;
  final double closeButtonSize;
  final double closeIconSize;
  final double closeRadius;
  final double avatarOuterSize;
  final double avatarInnerSize;
  final double avatarIconSize;
  final double profileTextGap;
  final double profileNameFontSize;
  final double usernameFontSize;
  final double usernameGap;
  final double descriptionFontSize;
  final double profileDescriptionGap;
  final double sectionHeaderInset;
  final double sectionTitleFontSize;
  final double sectionSubtitleFontSize;
  final double gridSpacing;
  final double cardAspectRatio;
  final EdgeInsets cardPadding;
  final double cardRadius;
  final double cardIconBoxSize;
  final double cardIconRadius;
  final double cardIconSize;
  final double cardTitleFontSize;
  final double cardSubtitleFontSize;
  final double cardSubtitleGap;
  final double cardActionFontSize;
  final double cardActionGap;
  final double cardArrowGap;
  final double cardArrowSize;
  final double sheetHorizontalPadding;
  final double sheetInnerPadding;

  static _MenuMetrics of(BuildContext context) {
    final responsive = context.responsive;
    final width = MediaQuery.sizeOf(context).width;
    final compact = responsive.isCompactPhone || width < 360;
    final small = responsive.isSmallPhone || width < 390;

    final horizontal = compact ? 16.0 : 20.0;
    final gridSpacing = compact ? 12.0 : 14.0;
    final cardAspectRatio = compact ? 0.78 : (small ? 0.84 : 0.90);
    final avatarOuter = compact ? 82.0 : (small ? 92.0 : 104.0);

    return _MenuMetrics(
      compact: compact,
      pagePadding: EdgeInsets.fromLTRB(
        responsive.spacing(horizontal),
        responsive.spacing(compact ? 14 : 18),
        responsive.spacing(horizontal),
        responsive.spacing(26) + MediaQuery.paddingOf(context).bottom,
      ),
      surfacePadding: EdgeInsets.fromLTRB(
        responsive.spacing(compact ? 14 : 18),
        responsive.spacing(compact ? 14 : 18),
        responsive.spacing(compact ? 14 : 18),
        responsive.spacing(compact ? 16 : 20),
      ),
      surfaceRadius: responsive.radius(compact ? 24 : 28),
      sectionGap: responsive.spacing(compact ? 22 : 28),
      gridTopGap: responsive.spacing(compact ? 12 : 14),
      profileTopGap: responsive.spacing(compact ? 14 : 18),
      titleFontSize: responsive.font(compact ? 24 : 26),
      timeFontSize: responsive.font(14),
      closeButtonSize: compact ? 40 : 44,
      closeIconSize: compact ? 20 : 22,
      closeRadius: responsive.radius(16),
      avatarOuterSize: avatarOuter,
      avatarInnerSize: avatarOuter - 8,
      avatarIconSize: compact ? 36 : 44,
      profileTextGap: responsive.spacing(compact ? 12 : 16),
      profileNameFontSize: responsive.font(compact ? 21 : 24),
      usernameFontSize: responsive.font(compact ? 14 : 16),
      usernameGap: responsive.spacing(compact ? 5 : 6),
      descriptionFontSize: responsive.font(13),
      profileDescriptionGap: responsive.spacing(compact ? 8 : 10),
      sectionHeaderInset: responsive.spacing(4),
      sectionTitleFontSize: responsive.font(compact ? 20 : 21),
      sectionSubtitleFontSize: responsive.font(13),
      gridSpacing: responsive.spacing(gridSpacing),
      cardAspectRatio: cardAspectRatio,
      cardPadding: EdgeInsets.all(responsive.spacing(compact ? 14 : 16)),
      cardRadius: responsive.radius(22),
      cardIconBoxSize: compact ? 42 : (small ? 46 : 50),
      cardIconRadius: responsive.radius(16),
      cardIconSize: compact ? 22 : 25,
      cardTitleFontSize: responsive.font(compact ? 15 : 16),
      cardSubtitleFontSize: responsive.font(12.5),
      cardSubtitleGap: responsive.spacing(5),
      cardActionFontSize: responsive.font(12),
      cardActionGap: responsive.spacing(compact ? 9 : 11),
      cardArrowGap: responsive.spacing(4),
      cardArrowSize: compact ? 13 : 14,
      sheetHorizontalPadding: responsive.spacing(compact ? 18 : 24),
      sheetInnerPadding: responsive.spacing(compact ? 14 : 16),
    );
  }
}
