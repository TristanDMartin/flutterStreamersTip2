import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/video_processing_service.dart';

class TextOverlayEditor extends StatefulWidget {
  final List<TextOverlay> textOverlays;
  final Duration videoDuration;
  final Function(List<TextOverlay>) onTextOverlaysChanged;
  final VoidCallback? onClose;

  const TextOverlayEditor({
    super.key,
    required this.textOverlays,
    required this.videoDuration,
    required this.onTextOverlaysChanged,
    this.onClose,
  });

  @override
  State<TextOverlayEditor> createState() => _TextOverlayEditorState();
}

class _TextOverlayEditorState extends State<TextOverlayEditor>
    with TickerProviderStateMixin {
  late List<TextOverlay> _textOverlays;
  TextOverlay? _selectedOverlay;
  bool _isDragging = false;
  
  // Text editing controllers
  late TextEditingController _textController;
  late TextEditingController _fontSizeController;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  
  // Available fonts
  final List<String> _availableFonts = [
    'Arial',
    'Helvetica',
    'Times New Roman',
    'Courier New',
    'Georgia',
    'Verdana',
    'Impact',
    'Comic Sans MS',
  ];
  
  // Available colors
  final List<Color> _availableColors = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.yellow,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.cyan,
    Colors.amber,
    Colors.indigo,
  ];
  
  // Animation types
  final List<String> _animationTypes = [
    'None',
    'Fade In',
    'Slide Up',
    'Slide Down',
    'Slide Left',
    'Slide Right',
    'Scale In',
    'Bounce',
  ];

  @override
  void initState() {
    super.initState();
    _textOverlays = List.from(widget.textOverlays);
    _textController = TextEditingController();
    _fontSizeController = TextEditingController(text: '24');
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _fontSizeController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _addTextOverlay() {
    final newOverlay = TextOverlay(
      text: 'New Text',
      x: 0.5,
      y: 0.5,
      fontFamily: 'Arial',
      fontSize: 24,
      color: '#FFFFFF',
      startTime: Duration.zero,
      endTime: widget.videoDuration,
      alignment: TextAlignment.center,
    );
    
    setState(() {
      _textOverlays.add(newOverlay);
      _selectedOverlay = newOverlay;
    });
    
    _updateTextOverlays();
    _fadeController.forward();
  }

  void _selectOverlay(TextOverlay overlay) {
    setState(() {
      _selectedOverlay = overlay;
      _textController.text = overlay.text;
      _fontSizeController.text = overlay.fontSize.toString();
    });
    
    _scaleController.forward().then((_) {
      _scaleController.reset();
    });
  }

  void _updateSelectedOverlay() {
    if (_selectedOverlay == null) return;
    
    final index = _textOverlays.indexOf(_selectedOverlay!);
    if (index != -1) {
      setState(() {
        _textOverlays[index] = TextOverlay(
          text: _textController.text,
          x: _selectedOverlay!.x,
          y: _selectedOverlay!.y,
          fontFamily: _selectedOverlay!.fontFamily,
          fontSize: double.tryParse(_fontSizeController.text) ?? 24,
          color: _selectedOverlay!.color,
          startTime: _selectedOverlay!.startTime,
          endTime: _selectedOverlay!.endTime,
          alignment: _selectedOverlay!.alignment,
        );
        _selectedOverlay = _textOverlays[index];
      });
      
      _updateTextOverlays();
    }
  }

  void _deleteSelectedOverlay() {
    if (_selectedOverlay == null) return;
    
    setState(() {
      _textOverlays.remove(_selectedOverlay);
      _selectedOverlay = _textOverlays.isNotEmpty ? _textOverlays.first : null;
    });
    
    _updateTextOverlays();
  }

  void _updateTextOverlays() {
    widget.onTextOverlaysChanged(_textOverlays);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: Row(
                  children: [
                    // Video preview area
                    Expanded(
                      flex: 3,
                      child: _buildVideoPreview(),
                    ),
                    // Text editor panel
                    Expanded(
                      flex: 2,
                      child: _buildTextEditorPanel(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onClose?.call();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Text Overlay Editor',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _addTextOverlay,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9248D2), Color(0xFF4897D2)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Add Text',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Video placeholder
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.grey[900],
              child: const Center(
                child: Icon(
                  Icons.videocam,
                  color: Colors.white,
                  size: 60,
                ),
              ),
            ),
            
            // Text overlays
            ..._textOverlays.map((overlay) => _buildTextOverlay(overlay)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextOverlay(TextOverlay overlay) {
    final isSelected = overlay == _selectedOverlay;
    
    return Positioned(
      left: overlay.x * (MediaQuery.of(context).size.width * 0.6 - 32),
      top: overlay.y * (MediaQuery.of(context).size.height * 0.6 - 32),
      child: GestureDetector(
        onTap: () => _selectOverlay(overlay),
        onPanStart: (details) {
          setState(() {
            _isDragging = true;
          });
        },
        onPanUpdate: (details) {
          if (_isDragging) {
            setState(() {
              final newX = (overlay.x + (details.delta.dx / (MediaQuery.of(context).size.width * 0.6))).clamp(0.0, 1.0);
              final newY = (overlay.y + (details.delta.dy / (MediaQuery.of(context).size.height * 0.6))).clamp(0.0, 1.0);
              
              final index = _textOverlays.indexOf(overlay);
              if (index != -1) {
                _textOverlays[index] = TextOverlay(
                  text: overlay.text,
                  x: newX,
                  y: newY,
                  fontFamily: overlay.fontFamily,
                  fontSize: overlay.fontSize,
                  color: overlay.color,
                  startTime: overlay.startTime,
                  endTime: overlay.endTime,
                  alignment: overlay.alignment,
                );
                _selectedOverlay = _textOverlays[index];
              }
            });
            _updateTextOverlays();
          }
        },
        onPanEnd: (details) {
          setState(() {
            _isDragging = false;
          });
        },
        child: AnimatedScale(
          scale: isSelected ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected 
                  ? const Color(0xFF9248D2).withValues(alpha: 0.8)
                  : Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
              border: isSelected 
                  ? Border.all(color: const Color(0xFF9248D2), width: 2)
                  : null,
            ),
            child: Text(
              overlay.text,
              style: TextStyle(
                color: _parseColor(overlay.color),
                fontSize: overlay.fontSize,
                fontFamily: overlay.fontFamily,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextEditorPanel() {
    if (_selectedOverlay == null) {
      return _buildEmptyState();
    }
    
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text input
          _buildTextInput(),
          const SizedBox(height: 16),
          
          // Font selection
          _buildFontSelection(),
          const SizedBox(height: 16),
          
          // Font size
          _buildFontSizeSlider(),
          const SizedBox(height: 16),
          
          // Color picker
          _buildColorPicker(),
          const SizedBox(height: 16),
          
          // Animation options
          _buildAnimationOptions(),
          const SizedBox(height: 16),
          
          // Time controls
          _buildTimeControls(),
          const SizedBox(height: 16),
          
          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.text_fields,
              color: Colors.white,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'No text selected',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap "Add Text" to create a new overlay',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Text Content',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _textController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter text...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF9248D2)),
            ),
          ),
          onChanged: (value) => _updateSelectedOverlay(),
        ),
      ],
    );
  }

  Widget _buildFontSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Font Family',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedOverlay?.fontFamily ?? 'Arial',
          dropdownColor: const Color(0xFF1C135D),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF9248D2)),
            ),
          ),
          items: _availableFonts.map((font) {
            return DropdownMenuItem(
              value: font,
              child: Text(font, style: const TextStyle(color: Colors.white)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null && _selectedOverlay != null) {
              setState(() {
                final index = _textOverlays.indexOf(_selectedOverlay!);
                if (index != -1) {
                  _textOverlays[index] = TextOverlay(
                    text: _selectedOverlay!.text,
                    x: _selectedOverlay!.x,
                    y: _selectedOverlay!.y,
                    fontFamily: value,
                    fontSize: _selectedOverlay!.fontSize,
                    color: _selectedOverlay!.color,
                    startTime: _selectedOverlay!.startTime,
                    endTime: _selectedOverlay!.endTime,
                    alignment: _selectedOverlay!.alignment,
                  );
                  _selectedOverlay = _textOverlays[index];
                }
              });
              _updateTextOverlays();
            }
          },
        ),
      ],
    );
  }

  Widget _buildFontSizeSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Font Size',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_selectedOverlay?.fontSize.round() ?? 24}px',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        Slider(
          value: _selectedOverlay?.fontSize ?? 24,
          min: 12,
          max: 72,
          activeColor: const Color(0xFF9248D2),
          inactiveColor: Colors.white.withValues(alpha: 0.3),
          onChanged: (value) {
            if (_selectedOverlay != null) {
              setState(() {
                final index = _textOverlays.indexOf(_selectedOverlay!);
                if (index != -1) {
                  _textOverlays[index] = TextOverlay(
                    text: _selectedOverlay!.text,
                    x: _selectedOverlay!.x,
                    y: _selectedOverlay!.y,
                    fontFamily: _selectedOverlay!.fontFamily,
                    fontSize: value,
                    color: _selectedOverlay!.color,
                    startTime: _selectedOverlay!.startTime,
                    endTime: _selectedOverlay!.endTime,
                    alignment: _selectedOverlay!.alignment,
                  );
                  _selectedOverlay = _textOverlays[index];
                }
              });
              _updateTextOverlays();
            }
          },
        ),
      ],
    );
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Text Color',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableColors.map((color) {
            final isSelected = _parseColor(_selectedOverlay?.color ?? '#FFFFFF') == color;
            return GestureDetector(
              onTap: () {
                if (_selectedOverlay != null) {
                  setState(() {
                    final index = _textOverlays.indexOf(_selectedOverlay!);
                    if (index != -1) {
                      _textOverlays[index] = TextOverlay(
                        text: _selectedOverlay!.text,
                        x: _selectedOverlay!.x,
                        y: _selectedOverlay!.y,
                        fontFamily: _selectedOverlay!.fontFamily,
                        fontSize: _selectedOverlay!.fontSize,
                        color: _colorToHex(color),
                        startTime: _selectedOverlay!.startTime,
                        endTime: _selectedOverlay!.endTime,
                        alignment: _selectedOverlay!.alignment,
                      );
                      _selectedOverlay = _textOverlays[index];
                    }
                  });
                  _updateTextOverlays();
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected 
                      ? Border.all(color: Colors.white, width: 3)
                      : Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAnimationOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Animation',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: 'None',
          dropdownColor: const Color(0xFF1C135D),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF9248D2)),
            ),
          ),
          items: _animationTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type, style: const TextStyle(color: Colors.white)),
            );
          }).toList(),
          onChanged: (value) {
            // Animation implementation would go here
          },
        ),
      ],
    );
  }

  Widget _buildTimeControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Timing',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Start Time', style: TextStyle(color: Colors.white70)),
                  Text(
                    _formatDuration(_selectedOverlay?.startTime ?? Duration.zero),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('End Time', style: TextStyle(color: Colors.white70)),
                  Text(
                    _formatDuration(_selectedOverlay?.endTime ?? Duration.zero),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _deleteSelectedOverlay,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red, width: 1),
              ),
              child: const Text(
                'Delete',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onClose?.call();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9248D2), Color(0xFF4897D2)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Done',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _parseColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.white;
    }
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
