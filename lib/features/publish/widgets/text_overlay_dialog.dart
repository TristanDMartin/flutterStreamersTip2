import 'package:flutter/material.dart';
import '../models/video_text_overlay.dart';
import '../../../core/theme/support_shell_style.dart';

class TextOverlayDialog extends StatefulWidget {
  const TextOverlayDialog({
    super.key,
    this.existingOverlay,
  });

  final VideoTextOverlay? existingOverlay;

  @override
  State<TextOverlayDialog> createState() => _TextOverlayDialogState();
}

class _TextOverlayDialogState extends State<TextOverlayDialog> {
  late TextEditingController _textController;
  late double _fontSize;
  late Color _textColor;
  Color? _backgroundColor;
  late FontWeight _fontWeight;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.existingOverlay?.text ?? '',
    );
    _fontSize = widget.existingOverlay?.fontSize ?? 24.0;
    _textColor = widget.existingOverlay?.color ?? Colors.white;
    _backgroundColor = widget.existingOverlay?.backgroundColor;
    _fontWeight = widget.existingOverlay?.fontWeight ?? FontWeight.bold;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shell = StSupportShellStyle.of(context);

    return Dialog(
      backgroundColor: shell.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existingOverlay != null ? 'Edit Text' : 'Add Text',
              style: TextStyle(
                color: shell.onChrome,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),

            // Text input
            TextField(
              controller: _textController,
              maxLength: 100,
              style: TextStyle(color: shell.onChrome),
              decoration: InputDecoration(
                labelText: 'Text',
                labelStyle: TextStyle(color: shell.muted),
                hintText: 'Enter your text...',
                hintStyle: TextStyle(color: shell.muted.withOpacity(0.5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: shell.surfaceCardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: shell.surfaceCardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF7B3FF2), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Font size
            Text(
              'Font Size: ${_fontSize.toInt()}',
              style: TextStyle(color: shell.onChrome, fontSize: 14),
            ),
            Slider(
              value: _fontSize,
              min: 12,
              max: 72,
              divisions: 60,
              activeColor: const Color(0xFF7B3FF2),
              onChanged: (value) => setState(() => _fontSize = value),
            ),
            const SizedBox(height: 12),

            // Font weight
            Text(
              'Font Weight',
              style: TextStyle(color: shell.onChrome, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Normal'),
                  selected: _fontWeight == FontWeight.normal,
                  onSelected: (_) => setState(() => _fontWeight = FontWeight.normal),
                ),
                ChoiceChip(
                  label: const Text('Bold'),
                  selected: _fontWeight == FontWeight.bold,
                  onSelected: (_) => setState(() => _fontWeight = FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Color picker
            Text(
              'Text Color',
              style: TextStyle(color: shell.onChrome, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Colors.white,
                Colors.black,
                Colors.red,
                Colors.blue,
                Colors.green,
                Colors.yellow,
                const Color(0xFF7B3FF2),
                Colors.orange,
              ].map((color) {
                return GestureDetector(
                  onTap: () => setState(() => _textColor = color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _textColor == color
                            ? const Color(0xFF7B3FF2)
                            : shell.surfaceCardBorder,
                        width: _textColor == color ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Background color toggle
            Row(
              children: [
                Text(
                  'Background',
                  style: TextStyle(color: shell.onChrome, fontSize: 14),
                ),
                const Spacer(),
                Switch(
                  value: _backgroundColor != null,
                  activeColor: const Color(0xFF7B3FF2),
                  onChanged: (value) {
                    setState(() {
                      _backgroundColor = value
                          ? Colors.black.withValues(alpha: 0.6)
                          : null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: shell.muted),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    if (_textController.text.trim().isEmpty) {
                      return;
                    }

                    final overlay = VideoTextOverlay(
                      id: widget.existingOverlay?.id ??
                          'text_${DateTime.now().millisecondsSinceEpoch}',
                      text: _textController.text.trim(),
                      fontSize: _fontSize,
                      color: _textColor,
                      backgroundColor: _backgroundColor,
                      fontWeight: _fontWeight,
                      position: widget.existingOverlay?.position ??
                          const Offset(0.5, 0.5),
                    );

                    Navigator.pop(context, overlay);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B3FF2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
