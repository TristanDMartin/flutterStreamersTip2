import 'package:flutter/material.dart';
import 'dart:async';
import '../models/connection_lite.dart';
import '../services/connections_service.dart';
import '../services/user_blocking_service.dart';

/// ConnectionsSearchOverlay - Full-screen search for connections
///
/// Provides typeahead search with debounced queries and selection
class ConnectionsSearchOverlay extends StatefulWidget {
  final String videoId;
  final String shareToken;
  final Function(String)? onConnectionSelected;

  const ConnectionsSearchOverlay({
    super.key,
    required this.videoId,
    required this.shareToken,
    this.onConnectionSelected,
  });

  @override
  State<ConnectionsSearchOverlay> createState() =>
      _ConnectionsSearchOverlayState();
}

class _ConnectionsSearchOverlayState extends State<ConnectionsSearchOverlay> {
  final ConnectionsService _connectionsService = ConnectionsService();
  final UserBlockingService _blockingService = UserBlockingService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<ConnectionLite> _searchResults = [];
  bool _isSearching = false;
  String _currentQuery = '';
  Timer? _debounceTimer;
  final Set<String> _sentConnections = {};

  @override
  void initState() {
    super.initState();
    _loadInitialConnections();
    _blockingService.blockListRevision.addListener(_handleBlockListChanged);

    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _blockingService.blockListRevision.removeListener(_handleBlockListChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialConnections() async {
    setState(() {
      _isSearching = true;
    });

    try {
      final connections =
          await _connectionsService.getConnectionsPreview(limit: 20);
      final visibleConnections = await _filterBlockedConnections(connections);
      setState(() {
        _searchResults = visibleConnections;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim() == _currentQuery) return;

    setState(() {
      _currentQuery = query.trim();
      _isSearching = true;
    });

    try {
      final results = await _connectionsService.searchConnections(
        query: _currentQuery,
        limit: 20,
      );
      final visibleResults = await _filterBlockedConnections(results);

      if (mounted) {
        setState(() {
          _searchResults = visibleResults;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<List<ConnectionLite>> _filterBlockedConnections(
    List<ConnectionLite> connections,
  ) async {
    final blockedUserIds = (await _blockingService.getBlockedUsers()).toSet();
    if (blockedUserIds.isEmpty) {
      return connections;
    }
    return connections
        .where((connection) => !blockedUserIds.contains(connection.userId))
        .toList();
  }

  void _handleBlockListChanged() {
    if (_currentQuery.isEmpty) {
      _loadInitialConnections();
      return;
    }
    _performSearch(_currentQuery);
  }

  Future<void> _shareToConnection(ConnectionLite connection) async {
    if (_sentConnections.contains(connection.userId)) return;

    try {
      setState(() {
        _sentConnections.add(connection.userId);
      });

      await _connectionsService.shareToConnection(
        recipientId: connection.userId,
        videoId: widget.videoId,
        shareToken: widget.shareToken,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent to @${connection.handle}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );

        // Close overlay after successful send
        Navigator.of(context).pop();
      }

      widget.onConnectionSelected?.call(connection.userId);
    } catch (e) {
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
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Share to Connections',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search field
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search connections...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Results
          Expanded(
            child: _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _currentQuery.isEmpty ? Icons.people_outline : Icons.search_off,
              color: Colors.white.withValues(alpha: 0.5),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _currentQuery.isEmpty
                  ? 'No connections found'
                  : 'No results for "$_currentQuery"',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _currentQuery.isEmpty
                  ? 'Connect with creators to share videos'
                  : 'Try a different search term',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final connection = _searchResults[index];
        return _buildConnectionTile(connection);
      },
    );
  }

  Widget _buildConnectionTile(ConnectionLite connection) {
    final isSent = _sentConnections.contains(connection.userId);
    final isDisabled = !connection.canDM || isSent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Stack(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundImage: connection.avatarUrl.isNotEmpty
                  ? NetworkImage(connection.avatarUrl)
                  : null,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: connection.avatarUrl.isEmpty
                  ? Icon(
                      Icons.person,
                      color: Colors.white.withValues(alpha: 0.7),
                    )
                  : null,
            ),

            // Online status
            if (connection.isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          connection.displayName,
          style: TextStyle(
            color:
                isDisabled ? Colors.white.withValues(alpha: 0.5) : Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '@${connection.handle}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        trailing: isSent
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Sent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : isDisabled
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Can\'t DM',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  )
                : Icon(
                    Icons.send,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
        onTap: isDisabled ? null : () => _shareToConnection(connection),
      ),
    );
  }
}
