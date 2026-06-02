import 'package:flutter/material.dart';

/// Per-platform character limits for cross-posting.
class PlatformCharacterLimits {
  static const Map<String, int> limits = {
    'TikTok': 2200,
    'YouTube': 5000,
    'Instagram': 2200,
    'Twitter': 280,
    'Facebook': 63206,
    'Bluesky': 300,
    'Reddit': 40000,
    'Twitch': 500,
    'Kick': 500,
    'Other': 500,
  };

  static int limitFor(String platformName) => limits[platformName] ?? 500;
}

/// Reusable platform row for cross-posting in both QuickPublishSheet and
/// VideoPublishingScreen.
class PlatformRow extends StatefulWidget {
  final String platformName;
  final IconData platformIcon;
  final Color platformColor;
  final bool isEnabled;
  final bool isLocked;
  final String initialCaption;
  final int characterLimit;
  final String? lockedReason;
  final String? trailingLabel;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onCaptionChanged;

  const PlatformRow({
    super.key,
    required this.platformName,
    required this.platformIcon,
    required this.platformColor,
    required this.isEnabled,
    this.isLocked = false,
    required this.initialCaption,
    required this.characterLimit,
    this.lockedReason,
    this.trailingLabel,
    required this.onToggle,
    required this.onCaptionChanged,
  });

  @override
  State<PlatformRow> createState() => _PlatformRowState();
}

class _PlatformRowState extends State<PlatformRow> {
  late TextEditingController _captionCtrl;
  late int _charCount;

  @override
  void initState() {
    super.initState();
    _captionCtrl = TextEditingController(text: widget.initialCaption);
    _charCount = widget.initialCaption.length;
    _captionCtrl.addListener(_onCaptionChanged);
  }

  @override
  void didUpdateWidget(PlatformRow old) {
    super.didUpdateWidget(old);
    // Sync caption if parent pushes a new initial value while toggled off.
    if (!widget.isEnabled && _captionCtrl.text != widget.initialCaption) {
      _captionCtrl.text = widget.initialCaption;
      _charCount = widget.initialCaption.length;
    }
  }

  @override
  void dispose() {
    _captionCtrl.removeListener(_onCaptionChanged);
    _captionCtrl.dispose();
    super.dispose();
  }

  void _onCaptionChanged() {
    final text = _captionCtrl.text;
    setState(() => _charCount = text.length);
    widget.onCaptionChanged(text);
  }

  Color _counterColor() {
    final ratio = _charCount / widget.characterLimit;
    if (ratio >= 1.0) return Colors.red;
    if (ratio >= 0.8) return Colors.orange;
    return Colors.white38;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: widget.isEnabled
            ? Colors.white.withValues(alpha: 0.07)
            : widget.isLocked
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isEnabled
              ? widget.platformColor.withValues(alpha: 0.5)
              : widget.isLocked
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row: icon + name + toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.platformColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.platformIcon,
                    color: widget.platformColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.platformName,
                    style: TextStyle(
                      color: widget.isEnabled
                          ? Colors.white
                          : widget.isLocked
                              ? Colors.white38
                              : Colors.white54,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.trailingLabel != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.platformColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: widget.platformColor.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Text(
                      widget.trailingLabel!,
                      style: TextStyle(
                        color: widget.platformColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Switch(
                  value: widget.isEnabled,
                  onChanged: widget.isLocked ? null : widget.onToggle,
                  activeThumbColor: widget.platformColor,
                  activeTrackColor: widget.platformColor.withValues(alpha: 0.3),
                  inactiveTrackColor: Colors.white12,
                ),
              ],
            ),
          ),
          if (widget.isLocked && widget.lockedReason != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.36),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.lockedReason!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Caption editor — only when enabled
          if (widget.isEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextField(
                    controller: _captionCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 3,
                    maxLength: widget.characterLimit,
                    decoration: InputDecoration(
                      hintText: 'Caption for ${widget.platformName}…',
                      hintStyle:
                          const TextStyle(color: Colors.white38, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(10),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_charCount / ${widget.characterLimit}',
                    style: TextStyle(color: _counterColor(), fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
