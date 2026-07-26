import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/home_video.dart';
import '../models/share_payload.dart';
import '../models/share_video_payload.dart';
import '../models/video_thumbnails.dart';
import '../services/chat_service.dart';
import '../services/chat_service_optimized.dart';
import '../services/connections_service.dart';
import '../services/enhanced_share_service.dart';
import '../utils/swallow_non_fatal.dart';
import '../services/report_service.dart';
import '../services/video_actions_service.dart';
import '../constants/app_colors.dart';
import '../core/feature_flags.dart';
import '../views/network_view.dart';
import 'share_sheet_brand_icon.dart';
import 'threads/create_thread_screen.dart';
import 'video_qr_code_dialog.dart';
import 'package:streamers_tip/utils/secure_log.dart';

class EnhancedShareSheet extends StatefulWidget {
  final HomeVideo video;
  final VoidCallback? onClose;
  final Function(String videoId, String creatorId)? onReport;
  final Function(String videoId, String creatorId)? onBlock;
  final Function(String videoId, String creatorId)? onNotInterested;
  final Function(String videoId, String creatorId)? onFavorite;

  const EnhancedShareSheet({
    super.key,
    required this.video,
    this.onClose,
    this.onReport,
    this.onBlock,
    this.onNotInterested,
    this.onFavorite,
  });

  @override
  State<EnhancedShareSheet> createState() => _EnhancedShareSheetState();
}

class _EnhancedShareSheetState extends State<EnhancedShareSheet>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _chipEntranceController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  SharePayload? _sharePayload;
  bool _isLoading = true;
  bool _connectionsLoading = true;
  bool _showConnectionSearch = false;
  bool _isSendingConnection = false;
  List<_ShareConnection> _connections = <_ShareConnection>[];
  String? _selectedConnectionId;
  Timer? _toastTimer;
  String? _toastMessage;
  bool _toastIsError = false;
  final TextEditingController _connectionSearchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadShareData();
    _loadConnections();
    _connectionSearchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HapticFeedback.lightImpact();
    });
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 340),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _chipEntranceController = AnimationController(
      duration: const Duration(milliseconds: 520),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutQuart,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideController.forward();
    _fadeController.forward();
  }

  Future<void> _loadShareData() async {
    try {
      // Load share payload
      final payload =
          await EnhancedShareService().fetchSharePayload(widget.video);

      if (mounted) {
        try {
          EnhancedShareService().trackShareSheetOpen(widget.video.id);
        } catch (e, st) {
          swallowNonFatal('EnhancedShareSheet.trackOpen', e, st);
        }
        setState(() {
          _sharePayload = payload;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _chipEntranceController.forward(from: 0);
          }
        });
      }
    } catch (e) {
      secureLog('❌ EnhancedShareSheet: Error loading share data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadConnections() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        setState(() => _connectionsLoading = false);
      }
      return;
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .collection('connections')
              .limit(24)
              .get();

      final List<_ShareConnection> directConnections =
          snapshot.docs.map(_ShareConnection.fromDocument).toList();

      final List<_ShareConnection> resolvedConnections = <_ShareConnection>[];
      for (final _ShareConnection connection in directConnections) {
        if (connection.hasDisplayData) {
          resolvedConnections.add(connection);
          continue;
        }
        try {
          final DocumentSnapshot<Map<String, dynamic>> userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(connection.userId)
                  .get();
          resolvedConnections.add(connection.mergeUserData(userDoc.data()));
        } catch (_) {
          resolvedConnections.add(connection);
        }
      }

      List<_ShareConnection> finalConnections = resolvedConnections;
      if (finalConnections.isEmpty) {
        final liteConnections =
            await ConnectionsService().getConnectionsPreview(limit: 12);
        finalConnections =
            liteConnections.map(_ShareConnection.fromLite).toList();
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _connections = finalConnections
            .where(
                (_ShareConnection connection) => connection.userId.isNotEmpty)
            .toList();
        _connectionsLoading = false;
      });
    } catch (e) {
      debugPrint('❌ EnhancedShareSheet: Error loading connections: $e');
      if (mounted) {
        setState(() => _connectionsLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _connectionSearchController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    _chipEntranceController.dispose();
    super.dispose();
  }

  Future<void> _closeSheet() async {
    await Future.wait([
      _slideController.reverse(),
      _fadeController.reverse(),
    ]);
    if (mounted) {
      widget.onClose?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Container(
          color: Colors.black.withValues(
            alpha: 0.62 * _fadeAnimation.value,
          ),
          child: SlideTransition(
            position: _slideAnimation,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.76,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF080C18).withValues(alpha: 0.78),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        const Color(0xFF162034).withValues(alpha: 0.74),
                        const Color(0xFF080C18).withValues(alpha: 0.92),
                      ],
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: _isLoading
                            ? _buildLoadingView()
                            : _buildShareContent(),
                      ),
                      if (_toastMessage != null) _buildToastBanner(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToastBanner() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: MediaQuery.of(context).padding.bottom + 12,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _toastIsError
                ? const Color(0xFF3D1518).withValues(alpha: 0.95)
                : const Color(0xFF1A2E1F).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _toastIsError
                  ? AppColors.error.withValues(alpha: 0.45)
                  : AppColors.success.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            _toastMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              height: 18,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 86,
            child: Row(
              children: List<Widget>.generate(
                5,
                (int i) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 4 ? 10 : 0),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareContent() {
    if (_sharePayload == null) {
      return _buildErrorView();
    }

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: math.max(MediaQuery.of(context).padding.bottom, 10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSwipeHandle(),
          _buildHeader(),
          const SizedBox(height: 12),
          _buildConnectionsRow(),
          const SizedBox(height: 18),
          _buildShareTargets(),
          const SizedBox(height: 14),
          _buildDivider(),
          const SizedBox(height: 14),
          _buildActionButtons(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: SelectableText.rich(
          TextSpan(
            children: <InlineSpan>[
              const WidgetSpan(
                child: Icon(
                  Icons.cloud_off_outlined,
                  color: AppColors.error,
                  size: 22,
                ),
              ),
              TextSpan(
                text: '  Could not load share options.\n',
                style: TextStyle(
                  color: AppColors.error.withValues(alpha: 0.95),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: 'Check your connection and try again.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSwipeHandle() {
    return Container(
      width: 36,
      height: 5,
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 8, 0),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Send this clip or share it anywhere',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: Colors.white.withValues(alpha: 0.92),
              size: 22,
            ),
            onPressed: _closeSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildShareTargets() {
    const List<ShareTarget> targets = <ShareTarget>[
      ShareTarget.copyLink,
      ShareTarget.sms,
      ShareTarget.instagramDirect,
      ShareTarget.whatsapp,
      ShareTarget.more,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Share actions'),
        const SizedBox(height: 10),
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: targets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (BuildContext context, int index) {
              return _buildShareTargetStaggered(
                targets[index],
                index,
                targets.length,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShareTargetStaggered(
    ShareTarget target,
    int index,
    int total,
  ) {
    final double start = index * (0.42 / math.max(total, 1));
    final double end = (start + 0.58).clamp(0.0, 1.0);
    final Animation<double> interval = CurvedAnimation(
      parent: _chipEntranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: interval,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.14),
          end: Offset.zero,
        ).animate(interval),
        child: _buildShareTarget(target),
      ),
    );
  }

  Widget _buildShareTarget(ShareTarget target) {
    return Semantics(
      button: true,
      label: target.displayName,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleShareTarget(target),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 70,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Center(
                    child: ShareSheetBrandIcon(
                      target: target,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  target.displayName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionsRow() {
    final List<_ShareConnection> visibleConnections = _filteredConnections();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Send to creators',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (_selectedConnectionId != null)
                TextButton(
                  onPressed: _isSendingConnection
                      ? null
                      : () => _sendSelectedConnection(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(_isSendingConnection ? 'Sending...' : 'Send'),
                ),
              IconButton(
                tooltip: 'Search creators',
                onPressed: () {
                  setState(
                      () => _showConnectionSearch = !_showConnectionSearch);
                },
                icon: const Icon(Icons.search_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
        if (_showConnectionSearch) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              controller: _connectionSearchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search creators',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.white.withValues(alpha: 0.55),
                  size: 19,
                ),
                suffixIcon: _connectionSearchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _connectionSearchController.clear,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          ),
        ],
        SizedBox(
          height:
              _connectionsLoading || visibleConnections.isNotEmpty ? 98 : 82,
          child: _buildConnectionContent(visibleConnections),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  List<_ShareConnection> _filteredConnections() {
    final String query = _connectionSearchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _connections;
    }
    return _connections.where((_ShareConnection connection) {
      return connection.displayName.toLowerCase().contains(query) ||
          connection.username.toLowerCase().contains(query) ||
          connection.creatorActivity.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  Widget _buildConnectionContent(List<_ShareConnection> visibleConnections) {
    if (_connectionsLoading) {
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 42,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      );
    }

    if (visibleConnections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.people_alt_outlined,
                color: Colors.white.withValues(alpha: 0.72),
                size: 20,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Start building your creator network',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: _openNetworkDiscovery,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                child: const Text('Find creators'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: visibleConnections.length + 1,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (BuildContext context, int index) {
        if (index == visibleConnections.length) {
          return _buildMoreConnectionButton();
        }
        return _buildConnectionPill(visibleConnections[index]);
      },
    );
  }

  Widget _buildMoreConnectionButton() {
    return GestureDetector(
      onTap: () => setState(() => _showConnectionSearch = true),
      child: SizedBox(
        width: 66,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: const Icon(Icons.more_horiz_rounded, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'More',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.76),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionPill(_ShareConnection connection) {
    final bool selected = _selectedConnectionId == connection.userId;
    return GestureDetector(
      onTap: connection.canDM
          ? () {
              HapticFeedback.selectionClick();
              setState(() => _selectedConnectionId = connection.userId);
            }
          : null,
      child: Opacity(
        opacity: connection.canDM ? 1 : 0.48,
        child: SizedBox(
          width: 68,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 58,
                    height: 58,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: selected
                          ? const LinearGradient(
                              colors: AppColors.primaryGradient,
                            )
                          : const LinearGradient(
                              colors: <Color>[
                                Colors.transparent,
                                Colors.transparent,
                              ],
                            ),
                      border: Border.all(
                        color: selected
                            ? Colors.transparent
                            : Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: ClipOval(
                      child: connection.avatarUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: connection.avatarUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 116,
                              memCacheHeight: 116,
                              placeholder: (_, __) =>
                                  _buildConnectionFallback(connection),
                              errorWidget: (_, __, ___) =>
                                  _buildConnectionFallback(connection),
                            )
                          : _buildConnectionFallback(connection),
                    ),
                  ),
                  if (connection.isOnline)
                    Positioned(
                      right: 3,
                      bottom: 3,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF28D17C),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF080C18),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  if (selected)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: AppColors.primaryGradient,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                connection.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (connection.creatorActivity.isNotEmpty)
                Text(
                  connection.creatorActivity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionFallback(_ShareConnection connection) {
    final String initial = connection.displayName.isNotEmpty
        ? connection.displayName.characters.first.toUpperCase()
        : '?';
    return Container(
      color: Colors.white.withValues(alpha: 0.11),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 21,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final actionButtons = <Widget>[
      _buildActionButton(
        icon: Icons.qr_code,
        label: 'QR Code',
        onTap: _handleQRCode,
      ),
      _buildActionButton(
        icon: Icons.flag_outlined,
        label: 'Report',
        onTap: _handleReport,
      ),
      _buildActionButton(
        icon: Icons.bookmark_add_outlined,
        label: 'Collection',
        onTap: _handleAddToCollection,
      ),
      _buildActionButton(
        icon: Icons.forum_outlined,
        label: 'Start Thread',
        onTap: _handleStartThread,
      ),
      _buildActionButton(
        icon: Icons.not_interested_outlined,
        label: 'Not Interested',
        onTap: _handleNotInterested,
      ),
    ];
    if (FeatureFlags.videoDownload && _canDownloadVideo) {
      actionButtons.insert(
        2,
        _buildActionButton(
          icon: Icons.download_rounded,
          label: 'Save Video',
          onTap: _handleSaveVideo,
        ),
      );
    }
    if (FeatureFlags.watermarkExport && _canShareWithWatermark) {
      actionButtons.insert(
        3,
        _buildActionButton(
          icon: Icons.branding_watermark_rounded,
          label: 'Watermark',
          onTap: _handleShareWithWatermark,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Creator tools'),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: actionButtons.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, int index) => actionButtons[index],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 76,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.white.withValues(alpha: 0.92),
                  size: 21,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canDownloadVideo {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final bool isOwner =
        currentUser != null && currentUser.uid == widget.video.creator.id;
    final bool hasPlayableSource = widget.video.videoURL.trim().isNotEmpty;
    final bool ready = widget.video.status == 'published';
    return hasPlayableSource && ready && (isOwner || widget.video.allowSave);
  }

  bool get _canShareWithWatermark {
    return _canDownloadVideo && widget.video.videoURL.trim().isNotEmpty;
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  void _showSheetToast(String message, {bool isError = false}) {
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
      _toastIsError = isError;
    });
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() => _toastMessage = null);
      }
    });
  }

  Future<void> _sendSelectedConnection() async {
    final String? selectedId = _selectedConnectionId;
    if (selectedId == null || _isSendingConnection) {
      return;
    }
    final _ShareConnection connection = _connections.firstWhere(
      (_ShareConnection item) => item.userId == selectedId,
      orElse: () => _ShareConnection(userId: selectedId),
    );

    setState(() => _isSendingConnection = true);
    HapticFeedback.lightImpact();
    try {
      final chat = await ChatService.shared.fetchOrCreateChat(selectedId);
      if (chat?.id == null || chat!.id!.isEmpty) {
        throw StateError('Could not open conversation');
      }

      final String thumbnailUrl = widget.video.thumbnailURL ??
          widget.video.thumbnails?.getLargestUrl() ??
          '';
      final String title = widget.video.caption.trim().isNotEmpty
          ? widget.video.caption.trim()
          : 'StreamersTip clip';
      final bool sent = await ChatServiceOptimized().sendVideoShare(
        chatId: chat.id!,
        videoId: widget.video.id,
        shareToken: _sharePayload?.trackingToken ?? '',
        previewText: 'Shared a video',
        thumbnailUrl: thumbnailUrl,
        title: title,
      );
      if (!sent) {
        throw StateError('Message could not be sent');
      }
      await EnhancedShareService().incrementVideoShareCount(widget.video.id);
      if (!mounted) {
        return;
      }
      _showSheetToast('Sent to ${connection.displayName}');
      setState(() => _selectedConnectionId = null);
    } catch (e) {
      if (mounted) {
        _showSheetToast('Could not send this clip', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingConnection = false);
      }
    }
  }

  void _openNetworkDiscovery() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NetworkView(),
        settings: const RouteSettings(name: '/network'),
      ),
    );
  }

  Future<void> _handleSaveVideo() async {
    HapticFeedback.selectionClick();
    try {
      await VideoActionsService().saveVideo(widget.video.id);
      if (mounted) {
        _showSheetToast('Video saved');
      }
    } catch (e) {
      if (mounted) {
        _showSheetToast('Could not save this video', isError: true);
      }
    }
  }

  void _handleShareWithWatermark() {
    _showSheetToast('Watermark export is unavailable in this build',
        isError: true);
  }

  Future<void> _handleNotInterested() async {
    HapticFeedback.selectionClick();
    try {
      await VideoActionsService().markNotInterested(
        videoId: widget.video.id,
        creatorId: widget.video.creator.id,
      );
      widget.onNotInterested?.call(widget.video.id, widget.video.creator.id);
      if (mounted) {
        _showSheetToast('Noted. Adjusting recommendations...');
        await _closeSheet();
      }
    } catch (e) {
      if (mounted) {
        _showSheetToast('Could not update preferences', isError: true);
      }
    }
  }

  Future<void> _handleAddToCollection() async {
    HapticFeedback.selectionClick();
    try {
      await VideoActionsService().addToFavorites(widget.video.id);
      widget.onFavorite?.call(widget.video.id, widget.video.creator.id);
      if (mounted) {
        _showSheetToast('Added to collection');
      }
    } catch (e) {
      if (mounted) {
        _showSheetToast('Could not add to collection', isError: true);
      }
    }
  }

  void _handleStartThread() {
    HapticFeedback.selectionClick();
    final String caption = widget.video.caption.trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateThreadScreen(
          attachedVideoId: widget.video.id,
          initialTitle: caption.isEmpty ? 'Discuss this clip' : null,
          initialContent: caption.isEmpty
              ? 'What do you think about this clip?'
              : 'What do you think about this clip?\n\n$caption',
        ),
        settings: const RouteSettings(name: '/threads/create'),
      ),
    );
  }

  Future<void> _handleShareTarget(ShareTarget target) async {
    if (_sharePayload == null) {
      return;
    }
    HapticFeedback.selectionClick();
    try {
      await EnhancedShareService().shareToTarget(target, _sharePayload!);
      if (!mounted) {
        return;
      }
      if (target == ShareTarget.copyLink) {
        _showSheetToast('Link copied.');
        await Future<void>.delayed(const Duration(milliseconds: 240));
      } else if (target == ShareTarget.more) {
        _showSheetToast('Share opened');
        await Future<void>.delayed(const Duration(milliseconds: 240));
      }
      await _closeSheet();
    } on ShareUserNoticeException catch (e) {
      if (!mounted) {
        return;
      }
      _showSheetToast(e.message);
    } catch (e) {
      secureLog(
          '❌ EnhancedShareSheet: Error sharing to ${target.displayName}: $e');
      _showSheetToast(
        'Could not share to ${target.displayName}',
        isError: true,
      );
    }
  }

  void _handleQRCode() {
    HapticFeedback.lightImpact();
    if (_sharePayload == null) {
      return;
    }
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (BuildContext context) => VideoQRCodeDialog(
        video: widget.video,
        shareUrl: ShareVideoPayload.buildPublicUrl(widget.video.id),
      ),
    );
  }

  void _handleReport() async {
    try {
      final hasReported =
          await ReportService().hasUserReportedVideo(widget.video.id);
      if (hasReported) {
        _showSheetToast('You already reported this video', isError: true);
        return;
      }
    } catch (e) {
      debugPrint('❌ Error checking report status: $e');
      // Continue anyway - let user try to report
    }

    _showReportDialog();
  }

  void _showReportDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildReportSheet(),
    );
  }

  Widget _buildReportSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text(
              'Why are you reporting this video?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Report options
          _buildReportOptions(),

          // Cancel button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportOptions() {
    final reportReasons = [
      'Spam',
      'Nudity or sexual activity',
      'Violence or dangerous acts',
      'Hate speech or harassment',
      'Dangerous goods or services',
      'Bullying or harassment',
      'Intellectual property violation',
      'False information',
      'Self-harm or suicide',
      'Terrorism',
      'Other',
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reportReasons.length,
      itemBuilder: (context, index) {
        final reason = reportReasons[index];
        return ListTile(
          title: Text(
            reason,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          onTap: () => _handleReportReason(reason),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            color: Colors.white54,
            size: 16,
          ),
        );
      },
    );
  }

  void _handleReportReason(String reason) async {
    try {
      // Close the report dialog
      Navigator.pop(context);

      // Submit the report to the service
      await ReportService().reportVideo(
        videoId: widget.video.id,
        creatorId: widget.video.creator.id,
        reason: reason,
      );

      await _closeSheet();

      // Call the report callback
      widget.onReport?.call(widget.video.id, widget.video.creator.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report submitted: $reason'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Log the report for analytics
      debugPrint('📋 Report submitted for video ${widget.video.id}: $reason');
    } catch (e) {
      debugPrint('❌ Error submitting report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText.rich(
              TextSpan(
                text: 'Failed to submit report: $e',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _ShareConnection {
  const _ShareConnection({
    required this.userId,
    this.displayName = '',
    this.username = '',
    this.avatarUrl = '',
    this.creatorActivity = '',
    this.isOnline = false,
    this.canDM = true,
  });

  final String userId;
  final String displayName;
  final String username;
  final String avatarUrl;
  final String creatorActivity;
  final bool isOnline;
  final bool canDM;

  bool get hasDisplayData =>
      displayName.trim().isNotEmpty ||
      username.trim().isNotEmpty ||
      avatarUrl.trim().isNotEmpty;

  factory _ShareConnection.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    final String userId =
        _readString(data, <String>['userId', 'uid', 'connectedUserId']) ??
            doc.id;
    return _ShareConnection(
      userId: userId,
      displayName:
          _readString(data, <String>['displayName', 'name', 'fullName']) ?? '',
      username:
          _readString(data, <String>['username', 'handle', 'userName']) ?? '',
      avatarUrl: _readString(
            data,
            <String>['avatarUrl', 'avatarURL', 'photoURL', 'profileImageUrl'],
          ) ??
          '',
      creatorActivity: _readString(
            data,
            <String>[
              'creatorActivity',
              'activity',
              'creatorType',
              'category',
              'statusText',
            ],
          ) ??
          '',
      isOnline: data['isOnline'] == true ||
          data['online'] == true ||
          data['onlineStatus'] == 'online',
      canDM: data['canDM'] != false && data['canReceiveDMs'] != false,
    );
  }

  factory _ShareConnection.fromLite(dynamic connection) {
    return _ShareConnection(
      userId: connection.userId as String,
      displayName: connection.displayName as String,
      username: connection.handle as String,
      avatarUrl: connection.avatarUrl as String,
      isOnline: connection.isOnline as bool,
      canDM: connection.canDM as bool,
    );
  }

  _ShareConnection mergeUserData(Map<String, dynamic>? data) {
    if (data == null) {
      return this;
    }
    return _ShareConnection(
      userId: userId,
      displayName: displayName.trim().isNotEmpty
          ? displayName
          : (_readString(data, <String>['displayName', 'name']) ?? username),
      username: username.trim().isNotEmpty
          ? username
          : (_readString(data, <String>['username', 'handle']) ?? ''),
      avatarUrl: avatarUrl.trim().isNotEmpty
          ? avatarUrl
          : (_readString(
                data,
                <String>['avatarUrl', 'avatarURL', 'photoURL'],
              ) ??
              ''),
      creatorActivity: creatorActivity.trim().isNotEmpty
          ? creatorActivity
          : (_readString(
                data,
                <String>['creatorActivity', 'creatorType', 'category', 'role'],
              ) ??
              ''),
      isOnline: isOnline ||
          data['isOnline'] == true ||
          data['online'] == true ||
          data['onlineStatus'] == 'online',
      canDM: canDM && data['canReceiveDMs'] != false,
    );
  }

  static String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final Object? value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }
}
