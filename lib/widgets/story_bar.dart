import 'package:flutter/material.dart';
import '../models/story.dart';

class StoryBar extends StatefulWidget {
  final List<Story> stories;
  final ValueChanged<Story> onStorySelected;

  const StoryBar({
    super.key,
    required this.stories,
    required this.onStorySelected,
  });

  @override
  State<StoryBar> createState() => _StoryBarState();
}

class _StoryBarState extends State<StoryBar> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: widget.stories.map((story) {
          return Padding(
            padding: const EdgeInsets.only(
              left: 12,
              right: 0,
            ),
            child: GestureDetector(
              onTap: () => widget.onStorySelected(story),
              child: StoryPreview(story: story),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class StoryPreview extends StatelessWidget {
  final Story story;

  const StoryPreview({
    super.key,
    required this.story,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 4),
        
        // Story circle with gradient ring
        Stack(
          children: [
            // Gradient ring
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Color(0xFF25E5D2), // Teal
                    Color(0xFF17C2AD), // Darker teal
                    Color(0xFF25E5D2), // Back to teal for smooth transition
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF25E5D2).withValues(alpha: 0.3),
                    blurRadius: 5,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
            
            // Inner circle with avatar placeholder
            Positioned(
              top: 3,
              left: 3,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.grey,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 4),
        
        // Creator name
        SizedBox(
          width: 60,
          child: Text(
            story.creatorName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
