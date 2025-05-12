// lib/screens/room_face_verification_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/room_service.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/camera_widget.dart';
import '../theme/theme.dart';
import '../models/room.dart';

class RoomFaceVerificationScreen extends StatefulWidget {
  final String roomId;

  const RoomFaceVerificationScreen({
    super.key,
    required this.roomId,
  });

  @override
  State<RoomFaceVerificationScreen> createState() => _RoomFaceVerificationScreenState();
}

class _RoomFaceVerificationScreenState extends State<RoomFaceVerificationScreen> {
  late RoomService _roomService;
  bool _isLoading = false;
  bool _hasCaptured = false;
  Uint8List? _capturedImage;
  String? _errorMessage;
  int _remainingTime = 20; // Default 20 seconds
  Room? _room;
  
  // Countdown timer
  int _currentSeconds = 20;
  bool _isTimerActive = true;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVerification();
    });
  }
  
  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _isTimerActive) {
        setState(() {
          _currentSeconds--;
        });
        
        if (_currentSeconds > 0) {
          _startTimer();
        } else {
          // Time's up
          _handleTimeout();
        }
      }
    });
  }
  
  Future<void> _initializeVerification() async {
    _roomService = Provider.of<RoomService>(context, listen: false);
    
    try {
      // Get room details
      _room = await _roomService.getRoomStatus(widget.roomId);
      
      // Check if room is already unlocked
      if (_room!.isUnlocked) {
        if (mounted) {
          setState(() {
            _isTimerActive = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room is already unlocked'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Go back to dashboard
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              context.go('/dashboard');
            }
          });
        }
        return;
      }
      
      // Ensure the room service has the selected room
      await _roomService.selectRoom(widget.roomId);
      
      setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    }
  }

  void _onImageCaptured(Uint8List imageData) {
    setState(() {
      _capturedImage = imageData;
      _hasCaptured = true;
      _isTimerActive = false; // Stop timer when image is captured
    });
    
    // Proceed with verification
    _verifyFace();
  }

  void _retakePhoto() {
    setState(() {
      _capturedImage = null;
      _hasCaptured = false;
      _errorMessage = null;
      
      // Restart timer if we still have time
      if (_currentSeconds > 0) {
        _isTimerActive = true;
        _startTimer();
      }
    });
  }

  void _verifyFace() async {
    if (_capturedImage == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Verify face
      final result = await _roomService.roomFaceVerify(_capturedImage!);
      
      // Navigate to voice verification
      if (mounted) {
        context.go('/room/${widget.roomId}/voice-verification');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
          _hasCaptured = false;
          _capturedImage = null;
          
          // Restart timer if we still have time
          if (_currentSeconds > 0) {
            _isTimerActive = true;
            _startTimer();
          }
        });
      }
    }
  }
  
  void _handleTimeout() {
    if (mounted && !_hasCaptured && !_isLoading) {
      setState(() {
        _errorMessage = 'Face verification timed out. Please try again.';
      });
      
      // Go back to room access after delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          context.go('/room/${widget.roomId}');
        }
      });
    }
  }

  @override
  void dispose() {
    _isTimerActive = false;
    super.dispose();
  }

  Color _getTimerColor(double progress) {
    if (progress > 0.6) {
      return Colors.green;
    } else if (progress > 0.3) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  IconData _getRoomIcon(String roomName) {
    final lowercaseName = roomName.toLowerCase();
    
    if (lowercaseName.contains('lab')) return Icons.science;
    if (lowercaseName.contains('office')) return Icons.business;
    if (lowercaseName.contains('server')) return Icons.dns;
    if (lowercaseName.contains('meeting')) return Icons.groups;
    if (lowercaseName.contains('storage')) return Icons.inventory_2;
    if (lowercaseName.contains('entrance')) return Icons.door_front_door;
    
    return Icons.meeting_room;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Face Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/room/${widget.roomId}'),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const AnimatedBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Room info
                      GlassCard(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getRoomIcon(_room?.name ?? ''),
                                  size: 24,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _room?.name ?? 'Room ${widget.roomId}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (_room?.groupName != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Group: ${_room!.groupName}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Time remaining
                      if (_currentSeconds > 0 && !_hasCaptured && !_isLoading) ...[
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.timer,
                                  color: _getTimerColor(_currentSeconds / _remainingTime),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Time remaining: $_currentSeconds seconds',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _getTimerColor(_currentSeconds / _remainingTime),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: _currentSeconds / _remainingTime,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getTimerColor(_currentSeconds / _remainingTime),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Main camera or captured image
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_isLoading) ...[
                              // Loading state
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24.0),
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text(
                                      'Verifying your face...',
                                      style: TextStyle(fontSize: 16),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (_hasCaptured && _capturedImage != null) ...[
                              // Show captured image
                              AspectRatio(
                                aspectRatio: 3/4,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12.0),
                                  child: Image.memory(
                                    _capturedImage!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _retakePhoto,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Take Again'),
                              ),
                            ] else ...[
                              // Camera widget for capturing
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12.0),
                                child: CameraWidget(
                                  onImageCaptured: _onImageCaptured,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Position your face within the frame and look directly at the camera.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                            
                            // Error message
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => context.go('/room/${widget.roomId}'),
                                child: const Text('Go Back'),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      // Instructions
                      const SizedBox(height: 24),
                      GlassCard(
                        padding: const EdgeInsets.all(16.0),
                        child: const Column(
                          children: [
                            Icon(Icons.info_outline, size: 24),
                            SizedBox(height: 8),
                            Text(
                              'Make sure your face is clearly visible and well-lit. No hats, glasses, or masks that may obscure your features.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}