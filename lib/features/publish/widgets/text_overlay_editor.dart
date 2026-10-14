import 'package:flutter/material.dart';
import '../models/video_text_overlay.dart';

class TextOverlayEditor extends StatefulWidget {
  const TextOverlayEditor({
    super.key,
    required this.videoSize,
    required this.overlays,
    required this.onOverlaysChanged,
  });

  final Size videoSize;
  final List<VideoTextOverlay> overlays;
  final ValueChanged<List<VideoTextOverlay>> onOverlaysChanged;

  @override
  State<TextOverlayEditor> createState() => _TextOverlayEditorState();
}

class _TextOverlayEditorState extends State<TextOverlayEditor> {
  VideoTextOverlay? _selectedOverlay;

  void _updateOverlay(VideoTextOverlay updated) {
    final updatedList = widget.overlays.map((overlay) {
      return overlay.id == updated.id ? updated : overlay;
    }).toList();
    widget.onOverlaysChanged(updatedList);
  }

  void _removeOverlay(String id) {
    final updatedList = widget.overlays.where((o) => o.id != id).toList();
    widget.onOverlaysChanged(updatedList);
    if (_selectedOverlay?.id == id) {
      setState(() => _selectedOverlay = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Render overlays
        ...widget.overlays.map((overlay) {
          final isSelected = _selectedOverlay?.id == overlay.id;
          final position = Offset(
            overlay.position.dx * widget.videoSize.width,
            overlay.position.dy * widget.videoSize.height,
          );

          return Positioned(
            left: position.dx - 50,
            top: position.dy - 25,
            child: GestureDetector(
              onTap: () => setState(() => _selectedOverlay = overlay),
              onPanUpdate: (details) {
                final newX = ((position.dx + details.delta.dx) / widget.videoSize.width)
                    .clamp(0.0, 1.0);
                final newY = ((position.dy + details.delta.dy) / widget.videoSize.height)
                    .clamp(0.0, 1.0);
                final newPosition = Offset(newX, newY);
                _updateOverlay(overlay.copyWith(position: newPosition));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: overlay.backgroundColor ?? Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                  border: isSelected
                      ? Border.all(color: Colors.blue, width: 2)
                      : null,
                ),
                child: Transform.rotate(
                  angle: overlay.rotation,
                  child: Transform.scale(
                    scale: overlay.scale,
                    child: Text(
                      overlay.text,
                      style: TextStyle(
                        color: overlay.color,
                        fontSize: overlay.fontSize,
                        fontWeight: overlay.fontWeight,
                      ),
                      textAlign: overlay.alignment,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),

        // Delete button for selected overlay
        if (_selectedOverlay != null)
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeOverlay(_selectedOverlay!.id),
            ),
          ),
      ],
    );
  }
}
