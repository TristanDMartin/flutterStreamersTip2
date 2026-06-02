import 'package:flutter/material.dart';

class StreamerCardAvatar extends StatelessWidget {
  final Map<String, dynamic> streamer;

  const StreamerCardAvatar({
    super.key,
    required this.streamer,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1) The gradient ring
        Container(
          width: 120,
          height: 120,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                Color(0xFF25E5D2), // Teal
                Color(0xFF17C2AD), // Darker teal
                Color(0xFF8B5CF6), // Purple
                Color(0xFFEC4899), // Pink
                Color(0xFF25E5D2), // Back to teal for smooth transition
              ],
            ),
          ),
          child: Container(
            margin: const EdgeInsets.all(3), // 6/2 = 3 for lineWidth
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
          ),
        ),

        // 2) The avatar image, same center, slightly smaller
        Positioned(
          top: 4, // (120 - 112) / 2 = 4
          left: 4,
          child: Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF25E5D2).withValues(alpha: 0.6),
                  blurRadius: 8,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: ClipOval(
              child: streamer['avatarURL'] != null
                  ? Image.network(
                      streamer['avatarURL'],
                      width: 112,
                      height: 112,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.person,
                        size: 112,
                        color: Colors.grey,
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      size: 112,
                      color: Colors.grey,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
