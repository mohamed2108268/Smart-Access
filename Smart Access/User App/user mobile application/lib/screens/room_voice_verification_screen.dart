// lib/screens/room_voice_verification_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/room_service.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/voice_recorder_widget.dart';
import '../theme/theme.dart';
import '../models/room.dart';

class RoomVoiceVerificationScreen extends StatefulWidget {
  final String roomId;

  const RoomVoiceVerificationScreen({
    super.key,
    required this.roomId,
  });

  @override
  State<RoomVoiceVerificationScreen> createState() => _RoomVoiceVerificationScreenState();
}

class _RoomVoiceVerificationScreenState extends State<RoomVoiceVerificationScreen> {
  late RoomService _roomService;
  bool _isLoading = false;
  bool _isRecording = false;
  bool _accessGranted = false;
  String? _errorMessage;
  Room? _room;
  
  // Challenge sentence
  String? _challengeSentence;
  
  // Countdown timer
  int _remainingTime = 30; // Default 30 seconds
  int _currentSeconds = 30;
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
      
      // Get the challenge sentence from the room service
      final challengeSentence = _roomService.challengeSentence;
      
      if (challengeSentence != null) {
        setState(() {
          _challengeSentence = challengeSentence;
        });
      } else {
        // If no challenge sentence, this means we probably didn't go through face verification
        // Go back to face verification
        if (mounted) {
          setState(() {
            _errorMessage = 'Invalid session. Please complete face verification first.';
          });
          
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              context.go('/room/${widget.roomId}/face-verification');
            }
          });
        }
        return;
      }
      
      // Check if room is already unlocked
      if (_room!.isUnlocked) {
        if (mounted) {
          setState(() {
            _isTimerActive = false;
            _accessGranted = true;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room is already unlocked'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Go back to dashboard
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              context.go('/dashboard');
            }
          });
        }
        return;
      }
      
      setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    }
  }
  
  void _onRecordingStart() {
    setState(() {
      _isRecording = true;
    });
  }

  void _onRecordingComplete(Uint8List recordingData) {
    setState(() {
      _isRecording = false;
      _isTimerActive = false; // Stop timer
    });
    
    // Proceed with verification
    _verifyVoice(recordingData);
  }

  void _verifyVoice(Uint8List recordingData) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Verify voice
      final result = await _roomService.roomVoiceVerify(recordingData);
      
      // Show success and navigate back to dashboard
      setState(() {
        _accessGranted = true;
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access granted! Room unlocked.'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate back to dashboard after delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          context.go('/dashboard');
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
          
          // Restart timer if we still have time and it's not a frozen account
          if (_currentSeconds > 0 && !_errorMessage!.contains('frozen')) {
            _isTimerActive = true;
            _startTimer();
          }
        });
      }
    }
  }
  
  void _handleTimeout() {
    if (mounted && !_isRecording && !_isLoading && !_accessGranted) {
      setState(() {
        _errorMessage = 'Voice verification timed out. Please try again.';
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
        title: const Text('Voice Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/room/${widget.roomId}/face-verification'),
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
                      
                      // Access Granted message
                      if (_accessGranted) ...[
                        GlassCard(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Access Granted!',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Door has been unlocked. Redirecting to dashboard...',
                                textAlign: TextAlign.center,
                              ),
                              
                              // Add a success animation or image here if desired
                              const SizedBox(height: 24),
                              const SizedBox(
                                width: 100,
                                height: 100,
                                child: CircularProgressIndicator(
                                  value: 1.0,
                                  color: Colors.green,
                                  backgroundColor: Colors.grey,
                                  strokeWidth: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Time remaining
                        if (_currentSeconds > 0 && !_isLoading) ...[
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
                        
                        // Challenge sentence
                        GlassCard(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Icon(Icons.record_voice_over, size: 28),
                              const SizedBox(height: 8),
                              const Text(
                                'Please read the following sentence clearly:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(
                                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _challengeSentence ?? 'Loading challenge sentence...',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Voice recorder or loading
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
                                        'Verifying your voice...',
                                        style: TextStyle(fontSize: 16),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                // Voice recorder
                                VoiceRecorderWidget(
                                  onRecordingComplete: _onRecordingComplete,
                                  isRecording: _isRecording,
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
                                  child: Column(
                                    children: [
                                      Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (_errorMessage!.contains('frozen')) ...[
                                        const SizedBox(height: 16),
                                        const Text(
                                          'Your account has been frozen. Please contact an administrator.',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          if (!_errorMessage!.contains('frozen')) ...[
                                            ElevatedButton(
                                              onPressed: () => context.go('/room/${widget.roomId}'),
                                              child: const Text('Try Again'),
                                            ),
                                            const SizedBox(width: 16),
                                          ],
                                          OutlinedButton(
                                            onPressed: () => context.go('/dashboard'),
                                            child: Text(_errorMessage!.contains('frozen') ? 'Go to Dashboard' : 'Cancel'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
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
                                'Speak clearly in a normal voice. Make sure you are in a quiet environment for best results.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
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