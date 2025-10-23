import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/connection_lite.dart';
import '../services/connections_service.dart';

/// ConnectionsRow - Horizontal scrollable row of user connections
///
/// Shows top connections for quick sharing with avatars, names, and online status
class ConnectionsRow extends StatefulWidget {
  final String videoId;
  final String shareToken;
  final VoidCallback? onSearchTap;
  final Function(String)? onConnectionTap;

  const ConnectionsRow({
    super.key,
    required this.videoId,
    required this.shareToken,
    this.onSearchTap,
    this.onConnectionTap,
  });

  @override
  State<ConnectionsRow> createState() => _ConnectionsRowState();
}

class _ConnectionsRowState extends State<ConnectionsRow> {
  final ConnectionsService _connectionsService = ConnectionsService();
  List<ConnectionLite> _connections = [];
  bool _isLoading = true;
  final Set<String> _sentConnections = {};

  @override
  void initState() {
    super.initState();
    debugPrint('🔗 ConnectionsRow: initState - loading connections...');
    _loadConnections();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preload avatars as soon as context is available
    if (_connections.isNotEmpty) {
      _preloadAvatars(_connections);
    }
  }

  Future<void> _loadConnections() async {
    debugPrint('🔗 ConnectionsRow: _loadConnections called');
    try {
      final connections = await _connectionsService.getConnectionsPreview();
      debugPrint('🔗 ConnectionsRow: Loaded ${connections.length} connections');

      // Debug each connection's avatar URL
      for (final connection in connections) {
        debugPrint(
            '🔗 ConnectionsRow: Connection ${connection.handle} - Avatar URL: "${connection.avatarUrl}"');
        // Test with a fallback avatar URL if none provided
        if (connection.avatarUrl.isEmpty) {
          debugPrint(
              '🔗 ConnectionsRow: No avatar URL for ${connection.handle}, using default');
        }
      }

      // Use real connections only - no test data fallback
      List<ConnectionLite> finalConnections = connections;

      if (mounted) {
        setState(() {
          _connections = finalConnections;
          _isLoading = false;
        });
        debugPrint(
            '🔗 ConnectionsRow: State updated - showing ${_connections.length} connections');

        // Preload all avatars for instant display
        _preloadAvatars(finalConnections);
      }
    } catch (e) {
      debugPrint('❌ ConnectionsRow: Error loading connections: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Preload all connection avatars for instant display
  void _preloadAvatars(List<ConnectionLite> connections) {
    debugPrint(
        '🖼️ ConnectionsRow: Starting to preload ${connections.length} avatars');
    for (final connection in connections) {
      if (connection.avatarUrl.isNotEmpty) {
        debugPrint(
            '🖼️ ConnectionsRow: Preloading avatar for ${connection.handle}: ${connection.avatarUrl}');
        // Preload the image into cache
        precacheImage(
          CachedNetworkImageProvider(connection.avatarUrl),
          context,
        ).then((_) {
          debugPrint(
              '✅ ConnectionsRow: Successfully preloaded avatar for ${connection.handle}');
        }).catchError((error) {
          debugPrint(
              '⚠️ ConnectionsRow: Failed to preload avatar for ${connection.handle}: $error');
        });
      } else {
        debugPrint('⚠️ ConnectionsRow: No avatar URL for ${connection.handle}');
      }
    }
  }

  Future<void> _shareToConnection(ConnectionLite connection) async {
    if (_sentConnections.contains(connection.userId)) return;

    try {
      // Add to sent set immediately for UI feedback
      setState(() {
        _sentConnections.add(connection.userId);
      });

      // Send DM share
      await _connectionsService.shareToConnection(
        recipientId: connection.userId,
        videoId: widget.videoId,
        shareToken: widget.shareToken,
      );

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent to @${connection.handle}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Callback for analytics
      widget.onConnectionTap?.call(connection.userId);
    } catch (e) {
      // Remove from sent set on error
      setState(() {
        _sentConnections.remove(connection.userId);
      });

      debugPrint('❌ ConnectionsRow: Error sharing to ${connection.handle}: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send message: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        '🔗 ConnectionsRow: build() called - _isLoading: $_isLoading, connections: ${_connections.length}');
    return Container(
      constraints: const BoxConstraints(maxHeight: 100),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with search icon only
          Row(
            children: [
              const Spacer(),
              GestureDetector(
                onTap: widget.onSearchTap,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Connections list
          Flexible(
            child: _buildConnectionsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionsList() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_connections.isEmpty) {
      return _buildEmptyState();
    }

    debugPrint(
        '🔗 ConnectionsRow: Building list with ${_connections.length} connections');

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        shrinkWrap: true,
        itemCount: _connections.length + 1, // +1 for "More" button
        itemBuilder: (context, index) {
          if (index == _connections.length) {
            return _buildMoreButton();
          }

          final connection = _connections[index];
          debugPrint(
              '🔗 ConnectionsRow: Building connection chip for ${connection.handle}');
          return _buildConnectionChip(connection);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        shrinkWrap: true,
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              children: [
                // Skeleton avatar with shimmer effect
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Skeleton text
                Container(
                  width: 32,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            color: Colors.white.withValues(alpha: 0.5),
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Find creators to connect with',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionChip(ConnectionLite connection) {
    final isSent = _sentConnections.contains(connection.userId);
    final isDisabled = !connection.canDM || isSent;
    debugPrint(
        '🔗 ConnectionsRow: Building chip for ${connection.handle} - Avatar: "${connection.avatarUrl}" - Sent: $isSent');

    return GestureDetector(
      onTap: isDisabled ? null : () => _shareToConnection(connection),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with status indicators
            Stack(
              children: [
                // Main avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSent
                          ? Colors.green
                          : Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: connection.avatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: connection.avatarUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 120, // 2x for crisp display
                            memCacheHeight: 120,
                            maxWidthDiskCache: 120,
                            maxHeightDiskCache: 120,
                            placeholder: (context, url) {
                              debugPrint(
                                  '🖼️ ConnectionsRow: Loading avatar for ${connection.handle}: $url');
                              return _buildDefaultAvatar(connection);
                            },
                            errorWidget: (context, url, error) {
                              debugPrint(
                                  '❌ ConnectionsRow: Failed to load avatar for ${connection.handle}: $url - $error');
                              return _buildDefaultAvatar(connection);
                            },
                            fadeInDuration: const Duration(milliseconds: 200),
                            fadeOutDuration: const Duration(milliseconds: 100),
                          )
                        : _buildDefaultAvatar(connection),
                  ),
                ),

                // Online status dot
                if (connection.isOnline)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),

                // Sent checkmark overlay
                if (isSent)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),

                // Disabled overlay
                if (isDisabled && !isSent)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.block,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 2),

            // Display name
            SizedBox(
              width: 60,
              child: Text(
                connection.displayName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDisabled
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.white,
                      fontSize: 10,
                    ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(ConnectionLite connection) {
    // Get the first letter of the display name or handle
    final initial = connection.displayName.isNotEmpty
        ? connection.displayName[0].toUpperCase()
        : connection.handle.isNotEmpty
            ? connection.handle[0].toUpperCase()
            : '?';

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMoreButton() {
    return GestureDetector(
      onTap: widget.onSearchTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: Icon(
                Icons.add,
                color: Colors.white.withValues(alpha: 0.7),
                size: 28,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'More',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
