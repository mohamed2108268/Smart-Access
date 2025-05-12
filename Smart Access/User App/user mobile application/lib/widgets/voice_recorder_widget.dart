// lib/widgets/voice_recorder_widget.dart
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:async';
import 'dart:math' as math;
import '../theme/theme.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final Function(Uint8List) onRecordingComplete;
  final bool isRecording;

  const VoiceRecorderWidget({
    super.key,
    required this.onRecordingComplete,
    required this.isRecording,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  bool _isRecording = false;
  bool _hasRecording = false;
  int _recordingDuration = 0;
  Timer? _timer;
  html.MediaRecorder? _mediaRecorder;
  List<html.Blob> _audioChunks = [];
  bool _isAudioAvailable = true;

  @override
  void initState() {
    super.initState();
    _requestAudioPermission();
  }

  @override
  void dispose() {
    _stopRecording();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _requestAudioPermission() async {
    try {
      await html.window.navigator.mediaDevices?.getUserMedia({'audio': true});
      setState(() {
        _isAudioAvailable = true;
      });
    } catch (e) {
      setState(() {
        _isAudioAvailable = false;
      });
      print('Error requesting audio permission: $e');
    }
  }

  void _startRecording() async {
    _audioChunks = [];
    
    try {
      final mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({
        'audio': true
      });

      if (mediaStream != null) {
        _mediaRecorder = html.MediaRecorder(mediaStream);
        
        // Add event listeners using addEventListener instead of stream methods
        _mediaRecorder!.addEventListener('dataavailable', (event) {
          // Handle the data available event
          if (event is html.Event && event is html.BlobEvent) {
            if ((event as html.BlobEvent).data != null) {
              _audioChunks.add((event as html.BlobEvent).data!);
            }
          }
        });

        _mediaRecorder!.addEventListener('stop', (event) {
          _processRecording();
        });

        _mediaRecorder!.start();
        
        setState(() {
          _isRecording = true;
          _recordingDuration = 0;
        });
        
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration++;
          });
          
          // Auto-stop after 10 seconds
          if (_recordingDuration >= 10) {
            _stopRecording();
          }
        });
      }
    } catch (e) {
      setState(() {
        _isAudioAvailable = false;
      });
      print('Error starting recording: $e');
    }
  }

  void _stopRecording() {
    if (_mediaRecorder != null && _isRecording) {
      _mediaRecorder!.stop();
      _timer?.cancel();
      
      setState(() {
        _isRecording = false;
      });
    }
  }

  void _processRecording() {
    if (_audioChunks.isEmpty) return;
    
    final blob = html.Blob(_audioChunks, 'audio/wav');
    
    final reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    
    reader.onLoad.listen((event) {
      if (reader.result != null) {
        final result = reader.result!;
        final bytes = Uint8List.fromList(result as List<int>);
        
        setState(() {
          _hasRecording = true;
        });
        
        widget.onRecordingComplete(bytes);
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAudioAvailable) {
      return Container(
        padding: const EdgeInsets.all(BioAccessTheme.paddingMedium),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(BioAccessTheme.borderRadiusMedium),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: BioAccessTheme.errorColor),
            const SizedBox(height: BioAccessTheme.paddingMedium),
            const Text(
              'Microphone not available',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: BioAccessTheme.paddingSmall),
            const Text(
              'Please ensure you have given microphone permissions',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: BioAccessTheme.paddingMedium),
            ElevatedButton(
              onPressed: _requestAudioPermission,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(BioAccessTheme.paddingMedium),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(BioAccessTheme.borderRadiusMedium),
      ),
      child: Column(
        children: [
          // Audio visualization (simplified)
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.background.withOpacity(0.3),
              borderRadius: BorderRadius.circular(BioAccessTheme.borderRadiusMedium),
            ),
            child: Center(
              child: _isRecording
                  ? _buildWaveform()
                  : _hasRecording
                      ? const Icon(Icons.graphic_eq, size: 48, color: BioAccessTheme.primaryColor)
                      : const Icon(Icons.mic, size: 48, color: Colors.grey),
            ),
          ),
          const SizedBox(height: BioAccessTheme.paddingMedium),
          
          // Status text
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isRecording) ...[
                const Icon(Icons.mic, color: BioAccessTheme.errorColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Recording: ${_formatDuration(_recordingDuration)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: BioAccessTheme.errorColor,
                  ),
                ),
              ] else if (_hasRecording) ...[
                const Icon(Icons.check_circle, color: BioAccessTheme.successColor, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Recording Complete',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    color: BioAccessTheme.successColor,
                  ),
                ),
              ] else ...[
                const Icon(Icons.mic_none, size: 24),
                const SizedBox(width: 8),
                const Text('Ready to Record'),
              ],
            ],
          ),
          const SizedBox(height: BioAccessTheme.paddingMedium),
          
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isRecording) ...[
                SizedBox(
                  width: 180,
                  child: ElevatedButton.icon(
                    onPressed: _stopRecording,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Recording'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BioAccessTheme.errorColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: 160,
                  child: ElevatedButton.icon(
                    onPressed: _hasRecording ? null : _startRecording,
                    icon: const Icon(Icons.mic),
                    label: const Text('Start Recording'),
                  ),
                ),
                if (_hasRecording) ...[
                  const SizedBox(width: BioAccessTheme.paddingMedium),
                  SizedBox(
                    width: 160,
                    child: OutlinedButton.icon(
                      onPressed: _startRecording,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Record Again'),
                    ),
                  ),
                ],
              ],
            ],
          ),
          
          // Progress note
          if (_isRecording) ...[
            const SizedBox(height: BioAccessTheme.paddingMedium),
            LinearProgressIndicator(
              value: _recordingDuration / 10, // Max 10 seconds
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(BioAccessTheme.primaryColor),
            ),
            const SizedBox(height: BioAccessTheme.paddingSmall),
            Text(
              'Maximum recording time: 10 seconds',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildWaveform() {
    return CustomPaint(
      painter: WaveformPainter(
        progress: _recordingDuration / 10, // 0.0 to 1.0
      ),
      size: const Size(double.infinity, 120),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final double progress;
  
  WaveformPainter({required this.progress});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BioAccessTheme.primaryColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    final width = size.width;
    final height = size.height;
    final center = height / 2;
    
    // Animate the waveform based on progress
    for (int i = 0; i < width; i += 5) {
      final normalizedX = i / width; // 0.0 to 1.0
      final amplitude = 30.0 * progress; // Max amplitude
      
      // Create a wave pattern with some randomization using math library
      final y = center + 
          amplitude * 
          (0.5 + 0.5 * 
            math.sin((normalizedX * 5 + progress * 10) * math.pi) * 
            math.cos((normalizedX * 3 + progress * 8) * math.pi)
          );
      
      // Draw a vertical line
      canvas.drawLine(
        Offset(i.toDouble(), center - 5),
        Offset(i.toDouble(), y),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(WaveformPainter oldDelegate) => 
      oldDelegate.progress != progress;
}