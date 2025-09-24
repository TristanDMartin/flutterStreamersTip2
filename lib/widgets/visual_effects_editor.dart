import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/video_processing_service.dart';

class VisualEffectsEditor extends StatefulWidget {
  final List<VisualEffect> visualEffects;
  final Duration videoDuration;
  final Function(List<VisualEffect>) onEffectsChanged;
  final VoidCallback? onClose;

  const VisualEffectsEditor({
    super.key,
    required this.visualEffects,
    required this.videoDuration,
    required this.onEffectsChanged,
    this.onClose,
  });

  @override
  State<VisualEffectsEditor> createState() => _VisualEffectsEditorState();
}

class _VisualEffectsEditorState extends State<VisualEffectsEditor>
    with TickerProviderStateMixin {
  late List<VisualEffect> _visualEffects;
  VisualEffect? _selectedEffect;
  
  // Animation controllers
  late AnimationController _previewController;
  late AnimationController _fadeController;
  
  // Available effects with parameters
  final Map<String, Map<String, dynamic>> _availableEffects = {
    'None': {},
    'Vintage': {
      'intensity': 0.5,
      'saturation': 0.8,
      'contrast': 1.2,
    },
    'Black & White': {
      'intensity': 1.0,
    },
    'Sepia': {
      'intensity': 0.7,
      'tone': 0.5,
    },
    'Brightness': {
      'intensity': 0.0,
      'min': -1.0,
      'max': 1.0,
    },
    'Contrast': {
      'intensity': 0.0,
      'min': 0.0,
      'max': 2.0,
    },
    'Saturation': {
      'intensity': 0.0,
      'min': 0.0,
      'max': 2.0,
    },
    'Blur': {
      'intensity': 0.0,
      'min': 0.0,
      'max': 10.0,
    },
    'Sharpen': {
      'intensity': 0.0,
      'min': 0.0,
      'max': 2.0,
    },
    'Hue': {
      'intensity': 0.0,
      'min': -180.0,
      'max': 180.0,
    },
  };

  @override
  void initState() {
    super.initState();
    _visualEffects = List.from(widget.visualEffects);
    
    _previewController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _previewController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _addEffect(String effectType) {
    if (effectType == 'None') return;
    
    final parameters = Map<String, dynamic>.from(_availableEffects[effectType] ?? {});
    final newEffect = VisualEffect(
      type: effectType,
      parameters: parameters,
      startTime: Duration.zero,
      endTime: widget.videoDuration,
    );
    
    setState(() {
      _visualEffects.add(newEffect);
      _selectedEffect = newEffect;
    });
    
    _updateEffects();
    _fadeController.forward();
  }

  void _selectEffect(VisualEffect effect) {
    setState(() {
      _selectedEffect = effect;
    });
    
    _previewController.forward().then((_) {
      _previewController.reset();
    });
  }

  void _removeEffect(VisualEffect effect) {
    setState(() {
      _visualEffects.remove(effect);
      if (_selectedEffect == effect) {
        _selectedEffect = _visualEffects.isNotEmpty ? _visualEffects.first : null;
      }
    });
    
    _updateEffects();
  }

  void _updateEffectParameter(String key, double value) {
    if (_selectedEffect == null) return;
    
    setState(() {
      final index = _visualEffects.indexOf(_selectedEffect!);
      if (index != -1) {
        final updatedParameters = Map<String, dynamic>.from(_selectedEffect!.parameters);
        updatedParameters[key] = value;
        
        _visualEffects[index] = VisualEffect(
          type: _selectedEffect!.type,
          parameters: updatedParameters,
          startTime: _selectedEffect!.startTime,
          endTime: _selectedEffect!.endTime,
        );
        _selectedEffect = _visualEffects[index];
      }
    });
    
    _updateEffects();
  }

  void _updateEffects() {
    widget.onEffectsChanged(_visualEffects);
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
                    // Effects panel
                    Expanded(
                      flex: 2,
                      child: _buildEffectsPanel(),
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
            'Visual Effects Editor',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showEffectPicker();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9248D2), Color(0xFF4897D2)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Add Effect',
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
            // Video placeholder with effect preview
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
            
            // Effect preview overlay
            if (_selectedEffect != null)
              _buildEffectPreview(),
            
            // Play button
            Center(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (_previewController.isAnimating) {
                    _previewController.stop();
                  } else {
                    _previewController.forward();
                  }
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: AnimatedBuilder(
                    animation: _previewController,
                    builder: (context, child) {
                      return Icon(
                        _previewController.isAnimating ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 30,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEffectPreview() {
    return AnimatedBuilder(
      animation: _previewController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: _getEffectColor().withValues(alpha: _previewController.value * 0.3),
          ),
        );
      },
    );
  }

  Color _getEffectColor() {
    if (_selectedEffect == null) return Colors.transparent;
    
    switch (_selectedEffect!.type) {
      case 'Vintage':
        return Colors.orange;
      case 'Black & White':
        return Colors.grey;
      case 'Sepia':
        return Colors.brown;
      case 'Brightness':
        return Colors.yellow;
      case 'Contrast':
        return Colors.blue;
      case 'Saturation':
        return Colors.purple;
      case 'Blur':
        return Colors.cyan;
      case 'Sharpen':
        return Colors.green;
      case 'Hue':
        return Colors.pink;
      default:
        return Colors.transparent;
    }
  }

  Widget _buildEffectsPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Effects list
          Expanded(
            child: _buildEffectsList(),
          ),
          
          // Selected effect controls
          if (_selectedEffect != null) ...[
            const Divider(color: Colors.white24),
            const SizedBox(height: 16),
            _buildEffectControls(),
          ],
        ],
      ),
    );
  }

  Widget _buildEffectsList() {
    if (_visualEffects.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_vintage,
              color: Colors.white,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'No effects applied',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap "Add Effect" to get started',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _visualEffects.length,
      itemBuilder: (context, index) {
        final effect = _visualEffects[index];
        final isSelected = effect == _selectedEffect;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => _selectEffect(effect),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFF9248D2).withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected 
                      ? const Color(0xFF9248D2)
                      : Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getEffectIcon(effect.type),
                    color: isSelected ? const Color(0xFF9248D2) : Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          effect.type,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF9248D2) : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _formatEffectParameters(effect),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _removeEffect(effect),
                    child: Icon(
                      Icons.close,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEffectControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_selectedEffect!.type} Settings',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Dynamic parameter controls
        ..._buildParameterControls(),
        
        const SizedBox(height: 16),
        
        // Time controls
        _buildTimeControls(),
      ],
    );
  }

  List<Widget> _buildParameterControls() {
    final parameters = _selectedEffect!.parameters;
    final widgets = <Widget>[];
    
    parameters.forEach((key, value) {
      if (value is double) {
        final min = _availableEffects[_selectedEffect!.type]?['min'] ?? 0.0;
        final max = _availableEffects[_selectedEffect!.type]?['max'] ?? 1.0;
        
        widgets.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatParameterName(key),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  Text(
                    value.toStringAsFixed(2),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              Slider(
                value: value.clamp(min, max).toDouble(),
                min: min,
                max: max,
                activeColor: const Color(0xFF9248D2),
                inactiveColor: Colors.white.withValues(alpha: 0.3),
                onChanged: (newValue) => _updateEffectParameter(key, newValue),
              ),
            ],
          ),
        );
        
        if (widgets.length < parameters.length) {
          widgets.add(const SizedBox(height: 16));
        }
      }
    });
    
    return widgets;
  }

  Widget _buildTimeControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Effect Timing',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
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
                  const Text('Start', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(
                    _formatDuration(_selectedEffect!.startTime),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('End', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(
                    _formatDuration(_selectedEffect!.endTime),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showEffectPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C135D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose an Effect',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemCount: _availableEffects.length,
              itemBuilder: (context, index) {
                final effectType = _availableEffects.keys.elementAt(index);
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _addEffect(effectType);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getEffectIcon(effectType),
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          effectType,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getEffectIcon(String effectType) {
    switch (effectType) {
      case 'None':
        return Icons.remove;
      case 'Vintage':
        return Icons.filter_vintage;
      case 'Black & White':
        return Icons.filter_b_and_w;
      case 'Sepia':
        return Icons.filter_tilt_shift;
      case 'Brightness':
        return Icons.brightness_6;
      case 'Contrast':
        return Icons.contrast;
      case 'Saturation':
        return Icons.palette;
      case 'Blur':
        return Icons.blur_on;
      case 'Sharpen':
        return Icons.auto_fix_high;
      case 'Hue':
        return Icons.color_lens;
      default:
        return Icons.filter_list;
    }
  }

  String _formatEffectParameters(VisualEffect effect) {
    final params = effect.parameters;
    if (params.isEmpty) return 'Default settings';
    
    final paramStrings = params.entries.map((e) {
      if (e.value is double) {
        return '${_formatParameterName(e.key)}: ${e.value.toStringAsFixed(1)}';
      }
      return '${_formatParameterName(e.key)}: ${e.value}';
    }).toList();
    
    return paramStrings.join(', ');
  }

  String _formatParameterName(String key) {
    return key.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
