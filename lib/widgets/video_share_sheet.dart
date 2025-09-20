import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/video.dart';

class VideoShareSheet extends StatefulWidget {
  final Video video;
  final VoidCallback? onDismiss;

  const VideoShareSheet({
    super.key,
    required this.video,
    this.onDismiss,
  });

  @override
  State<VideoShareSheet> createState() => _VideoShareSheetState();
}

class _VideoShareSheetState extends State<VideoShareSheet> {
  // bool _showAnalytics = false;
  // bool _showDeleteAlert = false;
  bool _isOwnVideo = false;

  // Mock data - replace with real data
  final List<String> _friends = [
    "nikoleglenn", "BuzZz", "Reggie", "Ashley Fyl Johnson", "drina", "Camil"
  ];

  @override
  void initState() {
    super.initState();
    // Determine if this is the user's own video
    // For now, assume it's the user's own video
    _isOwnVideo = true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1a1a1a),
            Color(0xFF2a2a2a),
          ],
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),
          
          const Divider(color: Colors.white24),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // Section 1: Send to Network
                  if (_friends.isNotEmpty) _buildNetworkSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Section 2: Share to Platforms
                  _buildPlatformsSection(),
                  
                  // Section 3: User Actions (for video owner only)
                  if (_isOwnVideo) ...[
                    const SizedBox(height: 24),
                    _buildUserActionsSection(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          TextButton(
            onPressed: widget.onDismiss,
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white),
            ),
          ),
          
          const Expanded(
            child: Text(
              "Share",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          TextButton(
            onPressed: () {
              // Search functionality
            },
            child: const Text(
              "Search",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Send to Network",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _friends.length,
            itemBuilder: (context, index) {
              final friend = _friends[index];
              return GestureDetector(
                onTap: () => _sendToFriend(friend),
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                        child: Center(
                          child: Text(
                            friend[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Share to Platforms",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _getPlatformActions().length,
          itemBuilder: (context, index) {
            final action = _getPlatformActions()[index];
            return SharePlatformButton(
              title: action["title"] as String,
              icon: action["icon"] as IconData,
              color: action["color"] as Color,
              onTap: action["onTap"] as VoidCallback,
            );
          },
        ),
      ],
    );
  }

  Widget _buildUserActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "User Actions",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Column(
          children: [
            
            VideoShareActionButton(
              title: "Download",
              icon: Icons.download,
              color: Colors.green,
              onTap: _downloadVideo,
            ),
            
            const SizedBox(height: 12),
            
            VideoShareActionButton(
              title: "Delete",
              icon: Icons.delete,
              color: Colors.red,
              onTap: () {
                // setState(() {
                //   _showDeleteAlert = true;
                // });
              },
            ),
          ],
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getPlatformActions() {
    return [
      {
        "title": "Copy Link",
        "icon": Icons.link,
        "color": Colors.blue,
        "onTap": _copyLink,
      },
      {
        "title": "SMS",
        "icon": Icons.message,
        "color": Colors.green,
        "onTap": _shareViaSMS,
      },
      {
        "title": "WhatsApp",
        "icon": Icons.chat,
        "color": Colors.green,
        "onTap": _shareViaWhatsApp,
      },
      {
        "title": "Instagram",
        "icon": Icons.camera_alt,
        "color": Colors.purple,
        "onTap": _shareViaInstagram,
      },
      {
        "title": "Stories",
        "icon": Icons.add_circle,
        "color": Colors.orange,
        "onTap": _shareToStories,
      },
      {
        "title": "Twitter",
        "icon": Icons.flutter_dash, // Placeholder for Twitter icon
        "color": Colors.blue,
        "onTap": _shareViaTwitter,
      },
      {
        "title": "Facebook",
        "icon": Icons.facebook,
        "color": Colors.blue,
        "onTap": _shareViaFacebook,
      },
      {
        "title": "More",
        "icon": Icons.more_horiz,
        "color": Colors.grey,
        "onTap": _shareViaSystem,
      },
    ];
  }

  // MARK: - Actions

  void _sendToFriend(String friend) {
    // print("📤 Sending video to $friend");
    // Implement in-app sharing
    widget.onDismiss?.call();
  }

  void _copyLink() {
    final videoLink = "https://streamerstip.com/video/${widget.video.id}";
    Clipboard.setData(ClipboardData(text: videoLink));
    // print("📋 Copied link: $videoLink");
    widget.onDismiss?.call();
  }

  void _shareViaSMS() {
    final videoLink = "https://streamerstip.com/video/${widget.video.id}";
    final message = "Check out this video: $videoLink";
    final uri = Uri.parse("sms:?body=${Uri.encodeComponent(message)}");
    _launchUrl(uri);
    widget.onDismiss?.call();
  }

  void _shareViaWhatsApp() {
    final videoLink = "https://streamerstip.com/video/${widget.video.id}";
    final message = "Check out this video: $videoLink";
    final uri = Uri.parse("whatsapp://send?text=${Uri.encodeComponent(message)}");
    _launchUrl(uri);
    widget.onDismiss?.call();
  }

  void _shareViaInstagram() {
    final videoLink = "https://streamerstip.com/video/${widget.video.id}";
    final uri = Uri.parse("instagram://library?AssetPath=${Uri.encodeComponent(videoLink)}");
    _launchUrl(uri);
    widget.onDismiss?.call();
  }

  void _shareToStories() {
    final uri = Uri.parse("instagram-stories://share?source_application=streamerstip");
    _launchUrl(uri);
    widget.onDismiss?.call();
  }

  void _shareViaTwitter() {
    final videoLink = "https://streamerstip.com/video/${widget.video.id}";
    final message = "Check out this video: $videoLink";
    final uri = Uri.parse("twitter://post?message=${Uri.encodeComponent(message)}");
    _launchUrl(uri);
    widget.onDismiss?.call();
  }

  void _shareViaFacebook() {
    final videoLink = "https://streamerstip.com/video/${widget.video.id}";
    final uri = Uri.parse("fb://share?link=${Uri.encodeComponent(videoLink)}");
    _launchUrl(uri);
    widget.onDismiss?.call();
  }

  void _shareViaSystem() async {
    try {
      final videoLink = "https://streamerstip.com/video/${widget.video.id}";
      final shareText = "Check out this awesome video on StreamersTip!\n$videoLink";
      
      await Share.share(
        shareText,
        subject: 'StreamersTip Video: ${widget.video.caption.isNotEmpty ? widget.video.caption : "Untitled"}',
      );
      
      // Log the share action (replace with proper logging framework)
      debugPrint("📤 Shared via system: $videoLink");
    } catch (e) {
      // Handle share errors gracefully
      debugPrint("❌ Error sharing via system: $e");
    } finally {
      widget.onDismiss?.call();
    }
  }

  void _downloadVideo() {
    // print("📥 Downloading video: ${widget.video.id}");
    // Implement video download
    widget.onDismiss?.call();
  }

  Future<void> _launchUrl(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
    // print("Could not launch $uri");
    }
  }
}

// MARK: - Supporting Views

class SharePlatformButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const SharePlatformButton({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class VideoShareActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const VideoShareActionButton({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 18,
            ),
            
            const SizedBox(width: 12),
            
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const Spacer(),
            
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

// MARK: - Analytics View

class VideoAnalyticsView extends StatelessWidget {
  final Video video;
  final VoidCallback? onDismiss;

  const VideoAnalyticsView({
    super.key,
    required this.video,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: onDismiss,
            child: const Text(
              "Done",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Video Analytics",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 20),
            
            Column(
              children: [
                AnalyticsRow(
                  title: "Views",
                  value: "${video.views}",
                  icon: Icons.visibility,
                  color: Colors.blue,
                ),
                
                const SizedBox(height: 16),
                
                AnalyticsRow(
                  title: "Likes",
                  value: "${video.likes}",
                  icon: Icons.favorite,
                  color: Colors.red,
                ),
                
                const SizedBox(height: 16),
                
                AnalyticsRow(
                  title: "Comments",
                  value: "${video.comments}",
                  icon: Icons.chat_bubble,
                  color: Colors.green,
                ),
                
                const SizedBox(height: 16),
                
                const AnalyticsRow(
                  title: "Shares",
                  value: "0",
                  icon: Icons.share,
                  color: Colors.orange,
                ),
              ],
            ),
            
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class AnalyticsRow extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const AnalyticsRow({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          
          const SizedBox(width: 12),
          
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          
          const Spacer(),
          
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
