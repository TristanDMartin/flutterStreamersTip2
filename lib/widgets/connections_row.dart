import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
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

  Future<void> _loadConnections() async {
    debugPrint('🔗 ConnectionsRow: _loadConnections called');
    try {
      final connections = await _connectionsService.getConnectionsPreview();
      debugPrint('🔗 ConnectionsRow: Loaded ${connections.length} connections');
      if (mounted) {
        setState(() {
          _connections = connections;
          _isLoading = false;
        });
        debugPrint(
            '🔗 ConnectionsRow: State updated - showing ${_connections.length} connections');
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not send message'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
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
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.3), // TEMP: Visual indicator
        border: Border.all(
            color: Colors.orange, width: 2), // TEMP: Visual indicator
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with search icon
          Row(
            children: [
              Text(
                'Share to Connections',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: widget.onSearchTap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Connections list
          Expanded(
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

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _connections.length + 1, // +1 for "More" button
      itemBuilder: (context, index) {
        if (index == _connections.length) {
          return _buildMoreButton();
        }

        final connection = _connections[index];
        return _buildConnectionChip(connection);
      },
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(right: 12),
          child: Column(
            children: [
              // Skeleton avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 4),
              // Skeleton text
              Container(
                width: 50,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        );
      },
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

    return GestureDetector(
      onTap: isDisabled ? null : () => _shareToConnection(connection),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            // Avatar with status indicators
            Stack(
              children: [
                // Main avatar
                Container(
                  width: 56,
                  height: 56,
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
                        ? Image.network(
                            connection.avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildDefaultAvatar(connection);
                            },
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

            const SizedBox(height: 4),

            // Display name
            SizedBox(
              width: 60,
              child: Text(
                connection.displayName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDisabled
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.white,
                      fontSize: 12,
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
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person,
        color: Colors.white.withValues(alpha: 0.7),
        size: 28,
      ),
    );
  }

  Widget _buildMoreButton() {
    return GestureDetector(
      onTap: widget.onSearchTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
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
            const SizedBox(height: 4),
            Text(
              'More',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
