import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../services/video_processing_service.dart';

class AudioEditor extends StatefulWidget {
  final AudioEffects audioEffects;
  final Duration videoDuration;
  final Function(AudioEffects) onAudioEffectsChanged;
  final VoidCallback? onClose;

  const AudioEditor({
    super.key,
    required this.audioEffects,
    required this.videoDuration,
    required this.onAudioEffectsChanged,
    this.onClose,
  });

  @override
  State<AudioEditor> createState() => _AudioEditorState();
}

class _AudioEditorState extends State<AudioEditor>
    with TickerProviderStateMixin {
  late AudioEffects _audioEffects;
  
  // Animation controllers
  late AnimationController _waveformController;
  late AnimationController _fadeController;
  
  // Audio track data (simulated)
  final List<double> _waveformData = List.generate(100, (index) => 
    math.sin(index * 0.1) * (math.Random().nextDouble() * 0.5) + 0.5
  );
  
  // Available audio tracks
  final List<AudioTrack> _availableTracks = [
    AudioTrack(
      name: 'Original Audio',
      duration: const Duration(seconds: 60),
      isSelected: true,
    ),
    AudioTrack(
      name: 'Background Music 1',
      duration: const Duration(seconds: 45),
      isSelected: false,
    ),
    AudioTrack(
      name: 'Background Music 2',
      duration: const Duration(seconds: 30),
      isSelected: false,
    ),
    AudioTrack(
      name: 'Sound Effect 1',
      duration: const Duration(seconds: 5),
      isSelected: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _audioEffects = widget.audioEffects;
    
    _waveformController = AnimationController(
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
    _waveformController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _updateAudioEffects() {
    widget.onAudioEffectsChanged(_audioEffects);
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
                    // Audio waveform area
                    Expanded(
                      flex: 3,
                      child: _buildAudioWaveform(),
                    ),
                    // Audio controls panel
                    Expanded(
                      flex: 2,
                      child: _buildAudioControlsPanel(),
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
            'Audio Editor',
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
              _showAudioTrackPicker();
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
                'Add Track',
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

  Widget _buildAudioWaveform() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Waveform visualization
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: _buildWaveformVisualization(),
            ),
          ),
          
          // Audio controls
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Play/Pause button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (_waveformController.isAnimating) {
                      _waveformController.stop();
                    } else {
                      _waveformController.forward();
                    }
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9248D2),
                      shape: BoxShape.circle,
                    ),
                    child: AnimatedBuilder(
                      animation: _waveformController,
                      builder: (context, child) {
                        return Icon(
                          _waveformController.isAnimating ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 24,
                        );
                      },
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Current time
                Expanded(
                  child: Text(
                    '00:00 / ${_formatDuration(widget.videoDuration)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                
                // Volume indicator
                Icon(
                  _audioEffects.isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveformVisualization() {
    return AnimatedBuilder(
      animation: _waveformController,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: WaveformPainter(
            waveformData: _waveformData,
            progress: _waveformController.value,
            isPlaying: _waveformController.isAnimating,
            volume: _audioEffects.volume,
            isMuted: _audioEffects.isMuted,
          ),
        );
      },
    );
  }

  Widget _buildAudioControlsPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Volume control
          _buildVolumeControl(),
          const SizedBox(height: 24),
          
          // Mute toggle
          _buildMuteToggle(),
          const SizedBox(height: 24),
          
          // Fade controls
          _buildFadeControls(),
          const SizedBox(height: 24),
          
          // Audio tracks
          _buildAudioTracks(),
          const SizedBox(height: 24),
          
          // Audio effects
          _buildAudioEffects(),
        ],
      ),
    );
  }

  Widget _buildVolumeControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Volume',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${(_audioEffects.volume * 100).round()}%',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: _audioEffects.volume,
          min: 0.0,
          max: 2.0,
          activeColor: const Color(0xFF9248D2),
          inactiveColor: Colors.white.withValues(alpha: 0.3),
          onChanged: (value) {
            setState(() {
              _audioEffects = AudioEffects(
                volume: value,
                isMuted: _audioEffects.isMuted,
                fadeIn: _audioEffects.fadeIn,
                fadeOut: _audioEffects.fadeOut,
                audioTrack: _audioEffects.audioTrack,
              );
            });
            _updateAudioEffects();
          },
        ),
      ],
    );
  }

  Widget _buildMuteToggle() {
    return Row(
      children: [
        const Icon(Icons.volume_off, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        const Text(
          'Mute Audio',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        const Spacer(),
        Switch(
          value: _audioEffects.isMuted,
          activeColor: const Color(0xFF9248D2),
          onChanged: (value) {
            setState(() {
              _audioEffects = AudioEffects(
                volume: _audioEffects.volume,
                isMuted: value,
                fadeIn: _audioEffects.fadeIn,
                fadeOut: _audioEffects.fadeOut,
                audioTrack: _audioEffects.audioTrack,
              );
            });
            _updateAudioEffects();
          },
        ),
      ],
    );
  }

  Widget _buildFadeControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fade Controls',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Fade In
        Row(
          children: [
            const Icon(Icons.trending_up, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            const Text(
              'Fade In',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const Spacer(),
            Text(
              '${_audioEffects.fadeIn.toStringAsFixed(1)}s',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        Slider(
          value: _audioEffects.fadeIn,
          min: 0.0,
          max: 5.0,
          activeColor: const Color(0xFF9248D2),
          inactiveColor: Colors.white.withValues(alpha: 0.3),
          onChanged: (value) {
            setState(() {
              _audioEffects = AudioEffects(
                volume: _audioEffects.volume,
                isMuted: _audioEffects.isMuted,
                fadeIn: value,
                fadeOut: _audioEffects.fadeOut,
                audioTrack: _audioEffects.audioTrack,
              );
            });
            _updateAudioEffects();
          },
        ),
        
        const SizedBox(height: 16),
        
        // Fade Out
        Row(
          children: [
            const Icon(Icons.trending_down, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            const Text(
              'Fade Out',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const Spacer(),
            Text(
              '${_audioEffects.fadeOut.toStringAsFixed(1)}s',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        Slider(
          value: _audioEffects.fadeOut,
          min: 0.0,
          max: 5.0,
          activeColor: const Color(0xFF9248D2),
          inactiveColor: Colors.white.withValues(alpha: 0.3),
          onChanged: (value) {
            setState(() {
              _audioEffects = AudioEffects(
                volume: _audioEffects.volume,
                isMuted: _audioEffects.isMuted,
                fadeIn: _audioEffects.fadeIn,
                fadeOut: value,
                audioTrack: _audioEffects.audioTrack,
              );
            });
            _updateAudioEffects();
          },
        ),
      ],
    );
  }

  Widget _buildAudioTracks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Audio Tracks',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ..._availableTracks.map((track) => _buildAudioTrackItem(track)),
      ],
    );
  }

  Widget _buildAudioTrackItem(AudioTrack track) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: track.isSelected 
            ? const Color(0xFF9248D2).withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: track.isSelected 
              ? const Color(0xFF9248D2)
              : Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            track.isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: track.isSelected ? const Color(0xFF9248D2) : Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.name,
                  style: TextStyle(
                    color: track.isSelected ? const Color(0xFF9248D2) : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatDuration(track.duration),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (track.isSelected)
            Icon(
              Icons.check_circle,
              color: const Color(0xFF9248D2),
              size: 20,
            ),
        ],
      ),
    );
  }

  Widget _buildAudioEffects() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Audio Effects',
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
              child: _buildEffectButton('Echo', Icons.volume_up),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildEffectButton('Reverb', Icons.surround_sound),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildEffectButton('Chorus', Icons.graphic_eq),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildEffectButton('Distortion', Icons.volume_down),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEffectButton(String name, IconData icon) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // Effect implementation would go here
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showAudioTrackPicker() {
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
              'Add Audio Track',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ..._availableTracks.map((track) => ListTile(
              leading: Icon(
                Icons.music_note,
                color: Colors.white,
              ),
              title: Text(
                track.name,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                _formatDuration(track.duration),
                style: const TextStyle(color: Colors.white70),
              ),
              onTap: () {
                Navigator.pop(context);
                // Add track logic would go here
              },
            )),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

class AudioTrack {
  final String name;
  final Duration duration;
  final bool isSelected;

  AudioTrack({
    required this.name,
    required this.duration,
    required this.isSelected,
  });
}

class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double progress;
  final bool isPlaying;
  final double volume;
  final bool isMuted;

  WaveformPainter({
    required this.waveformData,
    required this.progress,
    required this.isPlaying,
    required this.volume,
    required this.isMuted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isMuted ? Colors.grey : const Color(0xFF9248D2)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = (isMuted ? Colors.grey : const Color(0xFF9248D2)).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final barWidth = size.width / waveformData.length;
    final maxHeight = size.height * 0.8;
    final centerY = size.height / 2;

    for (int i = 0; i < waveformData.length; i++) {
      final x = i * barWidth;
      final barHeight = waveformData[i] * maxHeight * volume;
      final topY = centerY - barHeight / 2;
      final bottomY = centerY + barHeight / 2;

      // Draw waveform bars
      canvas.drawLine(
        Offset(x, topY),
        Offset(x, bottomY),
        paint,
      );

      // Add to paths for fill effect
      if (i == 0) {
        path.moveTo(x, centerY);
        fillPath.moveTo(x, centerY);
      } else {
        path.lineTo(x, topY);
        fillPath.lineTo(x, topY);
      }
    }

    // Complete the fill path
    for (int i = waveformData.length - 1; i >= 0; i--) {
      final x = i * barWidth;
      final barHeight = waveformData[i] * maxHeight * volume;
      final bottomY = centerY + barHeight / 2;
      fillPath.lineTo(x, bottomY);
    }
    fillPath.close();

    // Draw fill
    canvas.drawPath(fillPath, fillPaint);

    // Draw progress indicator
    if (isPlaying) {
      final progressX = size.width * progress;
      final progressPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 3.0;
      
      canvas.drawLine(
        Offset(progressX, 0),
        Offset(progressX, size.height),
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
