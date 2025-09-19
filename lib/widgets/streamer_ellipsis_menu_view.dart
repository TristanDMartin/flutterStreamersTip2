import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'share_profile_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/report_service.dart';

class StreamerEllipsisMenuView extends StatefulWidget {
  final Map<String, dynamic> streamer;
  final VoidCallback onDismiss;
  
  const StreamerEllipsisMenuView({
    super.key,
    required this.streamer,
    required this.onDismiss,
  });

  @override
  State<StreamerEllipsisMenuView> createState() => _StreamerEllipsisMenuViewState();
}

class _StreamerEllipsisMenuViewState extends State<StreamerEllipsisMenuView> {
  // final bool _showChatView = false;
  // bool _showBlockAlert = false;
  // bool _showReportAlert = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF9248D2), // Rich purple
            Color(0xFF7768DF), // Purple
            Color(0xFF1670DE), // Blue
            Color(0xFF3C8BD6), // Lighter blue
            Color(0xFF4897D2), // Lightest blue
          ],
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  // Send to Connections Section
                  _buildConnectionsSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Share to Platforms Section
                  _buildShareToPlatformsSection(),
                  
                  const SizedBox(height: 24),
                  
                  // User Actions Section
                  _buildUserActionsSection(),
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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onDismiss,
            icon: const Icon(
              Icons.close,
              color: Colors.white,
              size: 20,
            ),
          ),
          
          const Spacer(),
          
          const Text(
            'Send to',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const Spacer(),
          
          TextButton(
            onPressed: () {
              // Search action
            },
            child: const Text(
              'Search',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Send to',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 12),
          
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _getConnections().length,
              itemBuilder: (context, index) {
                final connection = _getConnections()[index];
                return Container(
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
                            String.fromCharCode(
                              (connection['displayName'] ?? 'A').codeUnitAt(0),
                            ),
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
                        connection['displayName'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareToPlatformsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Share to Platforms',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 12),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              ShareActionButton(
                title: 'Copy link',
                icon: Icons.link,
                color: Colors.blue,
                onTap: () => _handleCopyLink(),
              ),
              ShareActionButton(
                title: 'SMS',
                icon: Icons.message,
                color: Colors.green,
                onTap: () => _handleSMS(),
              ),
              ShareActionButton(
                title: 'WhatsApp',
                icon: Icons.message,
                color: const Color(0xFF25D366),
                onTap: () => _handleWhatsApp(),
              ),
              ShareActionButton(
                title: 'Instagram',
                icon: Icons.camera_alt,
                color: const Color(0xFFE4405F),
                onTap: () => _handleInstagram(),
              ),
              ShareActionButton(
                title: 'X',
                icon: Icons.close,
                color: Colors.black,
                onTap: () => _handleTwitter(),
              ),
              ShareActionButton(
                title: 'Facebook',
                icon: Icons.facebook,
                color: const Color(0xFF1877F2),
                onTap: () => _handleFacebook(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserActionsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 12),
          
          Column(
            children: [
              ActionRow(
                title: 'Send message',
                icon: Icons.message,
                color: Colors.blue,
                onTap: _handleSendMessage,
              ),
              
              const SizedBox(height: 8),
              
              ActionRow(
                title: 'QR code',
                icon: Icons.qr_code,
                color: Colors.purple,
                onTap: _handleQRCode,
              ),
              
              if (widget.streamer['id'] != 'currentUserId') ...[
                const SizedBox(height: 8),
                
                ActionRow(
                  title: 'Block',
                  icon: Icons.block,
                  color: Colors.red,
                  onTap: () {
                    // setState(() {
                    //   _showBlockAlert = true;
                    // });
                  },
                ),
                
                const SizedBox(height: 8),
                
                ActionRow(
                  title: 'Report',
                  icon: Icons.report,
                  color: Colors.orange,
                  onTap: () {
                    _showReportDialog();
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getConnections() {
    // Mock connections - replace with actual relationship service call
    return [
      {'id': '1', 'displayName': 'John Doe'},
      {'id': '2', 'displayName': 'Jane Smith'},
      {'id': '3', 'displayName': 'Bob Johnson'},
    ];
  }

  void _handleCopyLink() {
    final profileUrl = 'https://streamerstip.com/profile/${widget.streamer['id']}';
    Clipboard.setData(ClipboardData(text: profileUrl));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied to clipboard!'),
        ),
      );
    }
  }

  void _handleSMS() async {
    // Use a default message without phone number for SMS
    final message = 'Check out ${widget.streamer['displayName']} on StreamersTip!';
    final uri = Uri.parse('sms:?body=$message');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _handleWhatsApp() async {
    // Use a default message without phone number for WhatsApp
    final message = 'Check out ${widget.streamer['displayName']} on StreamersTip!';
    final uri = Uri.parse('whatsapp://send?text=$message');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _handleInstagram() async {
    final uri = Uri.parse('https://www.instagram.com/');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Instagram app not found. Please install Instagram.'),
        ),
      );
    }
  }

  void _handleTwitter() async {
    final message = 'Check out ${widget.streamer['displayName']} on StreamersTip!';
    final uri = Uri.parse('https://twitter.com/intent/tweet?text=$message');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _handleFacebook() async {
    final message = 'Check out ${widget.streamer['displayName']} on StreamersTip!';
    final uri = Uri.parse('https://www.facebook.com/sharer/sharer.php?u=https://streamerstip.com&quote=$message');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _handleSendMessage() {
    // Navigate to chat or show message input
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening chat with ${widget.streamer['displayName']}...'),
        ),
      );
    }
    widget.onDismiss();
  }

  void _handleQRCode() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShareProfileView(
          user: widget.streamer,
          dismiss: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  // void _handleBlockUser() {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text('${widget.streamer['displayName']} has been blocked'),
  //     ),
  //   );
  //   widget.onDismiss();
  // }

  Future<void> _handleReportUser() async {
    final container = ProviderScope.containerOf(context, listen: false);
    final auth = container.read(authServiceProvider);
    final String? reporterId = auth.currentUser?.id;
    final String targetId = (widget.streamer['id'] ?? '').toString();
    if (reporterId == null || targetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to submit report.')),
      );
      return;
    }
    try {
      await ReportService().reportUser(
        reporterId: reporterId,
        targetUserId: targetId,
        reason: 'inappropriate_content',
        details: 'Reported from StreamerEllipsisMenuView',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.streamer['displayName']} has been reported'),
          ),
        );
      }
      widget.onDismiss();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report failed. Please try again.')),
        );
      }
    }
  }

  void _showReportDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Report User'),
          content: Text('Are you sure you want to report ${widget.streamer['displayName']}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _handleReportUser();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('Report'),
            ),
          ],
        );
      },
    );
  }


  // Widget _buildBlockAlert() {
  //   return Container(
  //     color: Colors.black54,
  //     child: Center(
  //       child: Container(
  //         margin: const EdgeInsets.all(20),
  //         padding: const EdgeInsets.all(20),
  //         decoration: BoxDecoration(
  //           color: Colors.white,
  //           borderRadius: BorderRadius.circular(12),
  //         ),
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             const Text(
  //               'Block User',
  //               style: TextStyle(
  //                 fontSize: 18,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //             
  //             const SizedBox(height: 16),
  //             
  //             Text(
  //               'Are you sure you want to block ${widget.streamer['displayName']}? You won\'t see their content anymore.',
  //               textAlign: TextAlign.center,
  //             ),
  //             
  //             const SizedBox(height: 20),
  //             
  //             Row(
  //               children: [
  //                 Expanded(
  //                   child: TextButton(
  //                     onPressed: () {
  //                       setState(() {
  //                         _showBlockAlert = false;
  //                       });
  //                     },
  //                     child: const Text('Cancel'),
  //                   ),
  //                 ),
  //                 
  //                 Expanded(
  //                   child: ElevatedButton(
  //                     onPressed: () {
  //                       setState(() {
  //                         _showBlockAlert = false;
  //                       });
  //                       _handleBlockUser();
  //                     },
  //                     style: ElevatedButton.styleFrom(
  //                       backgroundColor: Colors.red,
  //                       foregroundColor: Colors.white,
  //                     ),
  //                     child: const Text('Block'),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildReportAlert() {
  //   return Container(
  //     color: Colors.black54,
  //     child: Center(
  //       child: Container(
  //         margin: const EdgeInsets.all(20),
  //         padding: const EdgeInsets.all(20),
  //         decoration: BoxDecoration(
  //           color: Colors.white,
  //           borderRadius: BorderRadius.circular(12),
  //         ),
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             const Text(
  //               'Report User',
  //               style: TextStyle(
  //                 fontSize: 18,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //             
  //             const SizedBox(height: 16),
  //             
  //             Text(
  //               'Are you sure you want to report ${widget.streamer['displayName']}?',
  //               textAlign: TextAlign.center,
  //             ),
  //             
  //             const SizedBox(height: 20),
  //             
  //             Row(
  //               children: [
  //                 Expanded(
  //                   child: TextButton(
  //                     onPressed: () {
  //                       setState(() {
  //                         _showReportAlert = false;
  //                       });
  //                     },
  //                     child: const Text('Cancel'),
  //                   ),
  //                 ),
  //                 
  //                 Expanded(
  //                   child: ElevatedButton(
  //                     onPressed: () {
  //                       setState(() {
  //                         _showReportAlert = false;
  //                       });
  //                       _handleReportUser();
  //                     },
  //                     style: ElevatedButton.styleFrom(
  //                       backgroundColor: Colors.orange,
  //                       foregroundColor: Colors.white,
  //                     ),
  //                     child: const Text('Report'),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }
}

class ShareActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const ShareActionButton({
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha:0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            
            const SizedBox(height: 6),
            
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class ActionRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const ActionRow({
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha:0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 16,
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
          ],
        ),
      ),
    );
  }
}
