import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:async';

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
        
        _mediaRecorder!.addEventListener('dataavailable', (event) {
          // Handle the data available event
          if (event is html.Event) {
            final blobEvent = event as html.BlobEvent;
            if (blobEvent.data != null) {
              _audioChunks.add(blobEvent.data!);
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
    
    reader.onLoadEnd.listen((event) {
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Microphone not available',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please ensure you have given microphone permissions',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _requestAudioPermission,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isRecording) ...[
                const Icon(Icons.mic, color: Colors.red, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Recording: ${_formatDuration(_recordingDuration)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ] else if (_hasRecording) ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Recording Complete',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ] else ...[
                const Icon(Icons.mic_none, size: 24),
                const SizedBox(width: 8),
                const Text('Ready to Record'),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isRecording) ...[
                ElevatedButton.icon(
                  onPressed: _stopRecording,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop Recording'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _hasRecording ? null : _startRecording,
                  icon: const Icon(Icons.mic),
                  label: const Text('Start Recording'),
                ),
                if (_hasRecording) ...[
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _startRecording,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Record Again'),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }
}
