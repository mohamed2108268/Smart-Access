// lib/screens/admin_login_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../services/auth_service.dart';
import '../widgets/animated_background.dart';
import '../widgets/fade_slide_transition.dart';
import '../widgets/camera_widget.dart';
import '../widgets/voice_recorder_widget.dart';
import '../widgets/timer_countdown.dart'; // Import the timer widget

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  
  // Authentication steps
  int _currentStep = 0;
  String? _challengeSentence;
  bool _timerActive = false;
  
  // Step-specific timer durations (in seconds)
  final int _faceVerificationTime = 20;
  final int _voiceVerificationTime = 30;
  
  // Biometric data
  Uint8List? _faceImage;
  Uint8List? _voiceRecording;
  
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  Future<void> _login() async {
    // Step 0: Validate credentials
    if (_currentStep == 0) {
      if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter both username and password';
        });
        return;
      }
      
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final result = await authService.loginStep1(
          _usernameController.text, 
          _passwordController.text
        );
        
        setState(() {
          _currentStep = 1;
          _timerActive = true;
        });
      } catch (e) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
    // Step 1: Submit face image
    else if (_currentStep == 1) {
      if (_faceImage == null) {
        setState(() {
          _errorMessage = 'Please capture your face image';
        });
        return;
      }
      
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _timerActive = false; // Stop the timer during processing
      });
      
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final result = await authService.loginStep2(_faceImage!);
        
        setState(() {
          _currentStep = 2;
          _challengeSentence = result['challenge_sentence'];
          _timerActive = true; // Start a new timer for voice verification
        });
      } catch (e) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _timerActive = true; // Restart the timer if verification failed
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
    // Step 2: Submit voice recording
    else if (_currentStep == 2) {
      if (_voiceRecording == null) {
        setState(() {
          _errorMessage = 'Please record your voice';
        });
        return;
      }
      
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _timerActive = false; // Stop the timer during processing
      });
      
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.loginStep3(_voiceRecording!);
        
        // On successful login, redirect to admin dashboard
        if (mounted) {
          context.go('/admin-dashboard');
        }
      } catch (e) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          
          // If we're frozen, go back to step 0
          if (_errorMessage!.contains('frozen')) {
            _currentStep = 0;
            _timerActive = false;
          } else {
            // If other error, restart the voice verification timer
            _timerActive = true;
          }
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _onFaceImageCaptured(Uint8List imageData) {
    setState(() {
      _faceImage = imageData;
    });
  }
  
  void _onVoiceRecorded(Uint8List audioData) {
    setState(() {
      _voiceRecording = audioData;
    });
  }
  
  void _onTimerFinished() {
    setState(() {
      _errorMessage = 'Time expired. Please start over.';
      _currentStep = 0;
      _faceImage = null;
      _voiceRecording = null;
      _challengeSentence = null;
      _timerActive = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AnimatedBackground(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: FadeSlideTransition(
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    width: 500,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Admin Login',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentStep == 0
                              ? 'Enter your credentials'
                              : _currentStep == 1
                                  ? 'Face verification'
                                  : 'Voice verification',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade100),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: Colors.red.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        
                        // Show Timer based on current step and timer status
                        if (_timerActive && _currentStep > 0) ...[
                          TimerCountdown(
                            seconds: _currentStep == 1 ? _faceVerificationTime : _voiceVerificationTime,
                            onFinished: _onTimerFinished,
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Login Step 0: Credentials
                        if (_currentStep == 0) ...[
                          TextField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              child: _isLoading
                                  ? const CircularProgressIndicator()
                                  : const Text('Continue'),
                            ),
                          ),
                        ],
                        
                        // Login Step 1: Face Verification
                        if (_currentStep == 1) ...[
                          const Text(
                            'Please look at the camera',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          CameraWidget(
                            onImageCaptured: _onFaceImageCaptured,
                            capturedImage: _faceImage,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading || _faceImage == null ? null : _login,
                              child: _isLoading
                                  ? const CircularProgressIndicator()
                                  : const Text('Continue'),
                            ),
                          ),
                        ],
                        
                        // Login Step 2: Voice Verification
                        if (_currentStep == 2) ...[
                          if (_challengeSentence != null) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'Please read the following sentence:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _challengeSentence!,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.blue.shade800,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          VoiceRecorderWidget(
                            onRecordingComplete: _onVoiceRecorded,
                            isRecording: false,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading || _voiceRecording == null ? null : _login,
                              child: _isLoading
                                  ? const CircularProgressIndicator()
                                  : const Text('Login'),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 16),
                        // Show "Back to credentials" button if not on first step
                        if (_currentStep > 0) ...[
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _currentStep = 0;
                                _faceImage = null;
                                _voiceRecording = null;
                                _challengeSentence = null;
                                _timerActive = false;
                              });
                            },
                            child: const Text('Start Over'),
                          ),
                          const SizedBox(height: 8),
                        ],
                        
                        // Don't have an account link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account?"),
                            TextButton(
                              onPressed: () => context.go('/admin-signup'),
                              child: const Text('Sign Up'),
                            ),
                          ],
                        ),
                      ],
                    ),
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