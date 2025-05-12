// lib/screens/login_voice_verification_screen.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/voice_recorder_widget.dart';
import '../theme/theme.dart';
import '../widgets/cookie_debug_view.dart'; // Import the debug view

class LoginVoiceVerificationScreen extends StatefulWidget {
  const LoginVoiceVerificationScreen({super.key});

  @override
  State<LoginVoiceVerificationScreen> createState() => _LoginVoiceVerificationScreenState();
}

class _LoginVoiceVerificationScreenState extends State<LoginVoiceVerificationScreen> {
  bool _isLoading = false;
  bool _isRecording = false;
  String? _errorMessage;
  int _remainingTime = 30; // Default 30 seconds
  String? _challengeSentence;
  late AuthService _authService;
  
  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    
    // Debug the login state
    if (kDebugMode) {
      _authService.printLoginState();
    }
    
    // Check if we're in the right login step
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_authService.loginStep != 2 || _authService.challengeSentence == null) {
        // If not in the correct step, return to login with a message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please start the login process again'),
            backgroundColor: Colors.red,
          ),
        );
        context.go('/login');
        return;
      }
      
      _remainingTime = _authService.remainingTime;
      _challengeSentence = _authService.challengeSentence;
      // Start countdown timer
      _startCountdown();
    });
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      
      setState(() {
        _remainingTime--;
      });
      
      if (_remainingTime > 0 && !_isLoading && !_isRecording) {
        _startCountdown();
      } else if (_remainingTime <= 0 && !_isLoading) {
        // Time's up - show error
        setState(() {
          _errorMessage = 'Voice verification timed out. Please try again.';
        });
        
        // Go back to login after delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            context.go('/login');
          }
        });
      }
    });
  }

  void _onRecordingComplete(Uint8List recordingData) {
    setState(() {
      _isRecording = false;
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
      if (kDebugMode) {
        print('Sending voice verification request with recording of size: ${recordingData.length} bytes');
      }
      
      await _authService.loginStep3(recordingData);
      
      if (kDebugMode) {
        print('Voice verification successful');
      }
      
      // Navigate to dashboard on success
      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Voice verification error: $e');
      }
      
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/login/face-verification'),
        ),
        // Add debug button in debug mode
        actions: kDebugMode ? [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const CookieDebugView(),
              );
            },
          ),
        ] : null,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const AnimatedBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(BioAccessTheme.paddingLarge),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title
                      Text(
                        'Voice Verification',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: BioAccessTheme.paddingSmall),
                      const Text(
                        'Step 3: Voice authentication',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: BioAccessTheme.paddingLarge),
                      
                      // Time remaining
                      if (_remainingTime > 0 && !_isLoading) ...[
                        Text(
                          'Time remaining: $_remainingTime seconds',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: BioAccessTheme.paddingMedium),
                      ],
                      
                      // Challenge sentence
                      if (_challengeSentence != null && !_isLoading) ...[
                        GlassCard(
                          padding: const EdgeInsets.all(BioAccessTheme.paddingMedium),
                          child: Column(
                            children: [
                              const Icon(Icons.record_voice_over, size: 28),
                              const SizedBox(height: BioAccessTheme.paddingSmall),
                              const Text(
                                'Please read the following sentence clearly:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: BioAccessTheme.paddingMedium),
                              Text(
                                _challengeSentence!,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: BioAccessTheme.paddingLarge),
                      ],
                      
                      // Voice recorder or loading
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_isLoading) ...[
                              // Loading state
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: BioAccessTheme.paddingLarge),
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: BioAccessTheme.paddingMedium),
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
                              const SizedBox(height: BioAccessTheme.paddingMedium),
                              Container(
                                padding: const EdgeInsets.all(BioAccessTheme.paddingMedium),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(BioAccessTheme.borderRadiusMedium),
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
                            ],
                          ],
                        ),
                      ),
                      
                      // Instructions
                      const SizedBox(height: BioAccessTheme.paddingLarge),
                      GlassCard(
                        padding: const EdgeInsets.all(BioAccessTheme.paddingMedium),
                        child: Column(
                          children: [
                            const Icon(Icons.info_outline, size: 24),
                            const SizedBox(height: BioAccessTheme.paddingSmall),
                            const Text(
                              'Speak clearly in a normal voice. Make sure you are in a quiet environment for best results.',
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