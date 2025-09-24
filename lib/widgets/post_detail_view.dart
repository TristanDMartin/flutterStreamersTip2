import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_notification.dart';

class PostDetailView extends ConsumerStatefulWidget {
  final ActivityNotification notification;
  final VoidCallback? onDismiss;

  const PostDetailView({
    super.key,
    required this.notification,
    this.onDismiss,
  });

  @override
  ConsumerState<PostDetailView> createState() => _PostDetailViewState();
}

class _PostDetailViewState extends ConsumerState<PostDetailView> {
  // bool _showShareSheet = false;
  // bool _showEllipsisMenu = false;
  // bool _showInsightsModal = false;
  bool _isLiked = false;
  int _likeCount = 1;
  final int _commentCount = 0;

  // Mock data for the ellipsis menu
  final bool _isOwnVideo = true; // This would be determined by comparing current user with video owner
  // final List<String> _friends = [
  //   "nikoleglenn", "BuzZz", "Reggie", "Ashley Fyl Johnson", "drina.", "Camil"
  // ]; // Unused field commented out

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background video content
          Container(
            color: Colors.black,
            child: const Center(
              child: Text(
                "Video Content Here",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
          ),

          // Top section with search bar
          _buildTopSection(),

          // Social interaction buttons (right side)
          _buildRightSideButtons(),

          // Bottom section with user info
          _buildBottomSection(),
        ],
      ),
    );
  }

  Widget _buildTopSection() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.only(top: 60, left: 16, right: 16),
        child: Row(
          children: [
            IconButton(
              onPressed: widget.onDismiss,
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
            ),
            
            const Expanded(
              child: Text(
                "Find related content",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            TextButton(
              onPressed: () {
                // Search action
              },
              child: const Text(
                "Search",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightSideButtons() {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Like button
            _buildActionButton(
              icon: _isLiked ? Icons.favorite : Icons.favorite_border,
              label: _likeCount.toString(),
              color: _isLiked ? Colors.red : Colors.white,
              onTap: () {
                setState(() {
                  _isLiked = !_isLiked;
                  _likeCount += _isLiked ? 1 : -1;
                });
              },
            ),
            
            const SizedBox(height: 20),
            
            // Comment button
            _buildActionButton(
              icon: Icons.chat_bubble_outline,
              label: _commentCount.toString(),
              onTap: () {
                // Comment action
              },
            ),
            
            const SizedBox(height: 20),
            
            // Save button
            _buildActionButton(
              icon: Icons.bookmark_border,
              label: "Save",
              onTap: () {
                // Save action
              },
            ),
            
            const SizedBox(height: 20),
            
            // Share button
            _buildActionButton(
              icon: Icons.share,
              label: "Share",
              onTap: () {
                // setState(() {
                //   _showShareSheet = true;
                // }); // Commented out as functionality not implemented
              },
            ),
            
            const SizedBox(height: 20),
            
            // Ellipsis button
            _buildActionButton(
              icon: Icons.more_horiz,
              label: "",
              onTap: () {
                // setState(() {
                //   _showEllipsisMenu = true;
                // }); // Commented out as functionality not implemented
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(
            icon,
            color: color ?? Colors.white,
            size: 24,
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          "@technqs",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        // Only show Follow button if not the current user's video
                        if (true) // TODO: Replace with actual video creator ID check
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.blue, Colors.purple],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              "Follow",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Text(
                      "New Video",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha:0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                
                const Spacer(),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Insights bar for video owner
            if (_isOwnVideo)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.analytics,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "View Insights",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        // setState(() {
                        //   _showInsightsModal = true;
                        // }); // Commented out as functionality not implemented
                      },
                      icon: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// MARK: - Share Sheet View
class ShareSheetView extends StatelessWidget {
  final VoidCallback? onDismiss;

  const ShareSheetView({
    super.key,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                
                const Expanded(
                  child: Text(
                    "Send to",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                TextButton(
                  onPressed: () {
                    // Search action
                  },
                  child: const Text(
                    "Search",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Friends section
                  _buildSection(
                    title: "Friends",
                    child: _buildFriendsList(),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Share actions
                  _buildSection(
                    title: "Share to Platforms",
                    child: _buildShareActions(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
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
        
        const SizedBox(height: 12),
        
        child,
      ],
    );
  }

  Widget _buildFriendsList() {
    final friends = [
      "nikoleglenn", "BuzZz", "Reggie", 
      "Ashley Fyl Johnson", "drina.", "Camil"
    ];
    
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: friends.length,
        itemBuilder: (context, index) {
          final friend = friends[index];
          return Container(
            width: 60,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.withValues(alpha:0.3),
                  ),
                  child: Center(
                    child: Text(
                      friend[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 4),
                
                Text(
                  friend,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShareActions() {
    final actions = [
      {"title": "Copy link", "icon": Icons.link, "color": Colors.blue},
      {"title": "SMS", "icon": Icons.message, "color": Colors.green},
      {"title": "WhatsApp", "icon": Icons.chat, "color": Colors.green},
      {"title": "Instagram", "icon": Icons.camera_alt, "color": Colors.purple},
      {"title": "Stories", "icon": Icons.add_circle, "color": Colors.orange},
    ];
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return PostShareActionButton(
          title: action["title"] as String,
          icon: action["icon"] as IconData,
          color: action["color"] as Color,
        );
      },
    );
  }
}

// MARK: - Ellipsis Menu View
class EllipsisMenuView extends StatelessWidget {
  final bool isOwnVideo;
  final List<String> friends;
  final VoidCallback? onDismiss;

  const EllipsisMenuView({
    super.key,
    required this.isOwnVideo,
    required this.friends,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                
                const Expanded(
                  child: Text(
                    "More Options",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(width: 20),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: Send to Network
                  _buildSection(
                    title: "Send to Network",
                    child: _buildNetworkGrid(),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Section 2: Share to Platforms
                  _buildSection(
                    title: "Share to Platforms",
                    child: _buildPlatformGrid(),
                  ),
                  
                  // Section 3: User Actions (for video owner only)
                  if (isOwnVideo) ...[
                    const SizedBox(height: 20),
                    _buildSection(
                      title: "User Actions",
                      child: _buildUserActionsGrid(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
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
        
        const SizedBox(height: 12),
        
        child,
      ],
    );
  }

  Widget _buildNetworkGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: friends.take(6).length,
      itemBuilder: (context, index) {
        final friend = friends[index];
        return Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.withValues(alpha:0.3),
              ),
              child: Center(
                child: Text(
                  friend[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 4),
            
            Text(
              friend,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlatformGrid() {
    final actions = [
      {"title": "Copy link", "icon": Icons.link, "color": Colors.blue},
      {"title": "SMS", "icon": Icons.message, "color": Colors.green},
      {"title": "WhatsApp", "icon": Icons.chat, "color": Colors.green},
      {"title": "Instagram", "icon": Icons.camera_alt, "color": Colors.purple},
      {"title": "Stories", "icon": Icons.add_circle, "color": Colors.orange},
    ];
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return PostShareActionButton(
          title: action["title"] as String,
          icon: action["icon"] as IconData,
          color: action["color"] as Color,
        );
      },
    );
  }

  Widget _buildUserActionsGrid() {
    final actions = [
      {"title": "Download", "icon": Icons.download, "color": Colors.grey},
      {"title": "Delete", "icon": Icons.delete, "color": Colors.red},
    ];
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return PostShareActionButton(
          title: action["title"] as String,
          icon: action["icon"] as IconData,
          color: action["color"] as Color,
        );
      },
    );
  }
}

// MARK: - Share Action Button
class PostShareActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const PostShareActionButton({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Action for each button
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            
            const SizedBox(height: 8),
            
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
