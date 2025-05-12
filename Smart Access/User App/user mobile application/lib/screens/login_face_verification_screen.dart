// lib/screens/login_face_verification_screen.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/camera_widget.dart';
import '../theme/theme.dart';
import '../widgets/cookie_debug_view.dart'; // Import the debug view

class LoginFaceVerificationScreen extends StatefulWidget {
  const LoginFaceVerificationScreen({super.key});

  @override
  State<LoginFaceVerificationScreen> createState() => _LoginFaceVerificationScreenState();
}

class _LoginFaceVerificationScreenState extends State<LoginFaceVerificationScreen> {
  bool _isLoading = false;
  bool _hasCaptured = false;
  Uint8List? _capturedImage;
  String? _errorMessage;
  int _remainingTime = 20; // Default 20 seconds
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
      if (_authService.loginStep != 1) {
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
      
      if (_remainingTime > 0 && !_isLoading && !_hasCaptured) {
        _startCountdown();
      } else if (_remainingTime <= 0 && !_isLoading) {
        // Time's up - show error
        setState(() {
          _errorMessage = 'Face verification timed out. Please try again.';
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

  void _onImageCaptured(Uint8List imageData) {
    setState(() {
      _capturedImage = imageData;
      _hasCaptured = true;
    });
    
    // Proceed with verification
    _verifyFace();
  }

  void _retakePhoto() {
    setState(() {
      _capturedImage = null;
      _hasCaptured = false;
      _errorMessage = null;
    });
  }

  void _verifyFace() async {
    if (_capturedImage == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      if (kDebugMode) {
        print('Sending face verification request with image of size: ${_capturedImage!.length} bytes');
      }
      
      final result = await _authService.loginStep2(_capturedImage!);
      
      if (kDebugMode) {
        print('Face verification successful: $result');
        _authService.printLoginState();
      }
      
      // Navigate to voice verification
      if (mounted) {
        context.go('/login/voice-verification');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Face verification error: $e');
      }
      
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _hasCaptured = false;
        _capturedImage = null;
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
          onPressed: () => context.go('/login'),
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
                        'Face Verification',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: BioAccessTheme.paddingSmall),
                      const Text(
                        'Step 2: Verify your identity',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: BioAccessTheme.paddingLarge),
                      
                      // Time remaining
                      if (_remainingTime > 0 && !_hasCaptured && !_isLoading) ...[
                        Text(
                          'Time remaining: $_remainingTime seconds',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: BioAccessTheme.paddingMedium),
                      ],
                      
                      // Main camera or captured image
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
                                  borderRadius: BorderRadius.circular(BioAccessTheme.borderRadiusMedium),
                                  child: Image.memory(
                                    _capturedImage!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: BioAccessTheme.paddingMedium),
                              OutlinedButton.icon(
                                onPressed: _retakePhoto,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Take Again'),
                              ),
                            ] else ...[
                              // Camera widget for capturing
                              ClipRRect(
                                borderRadius: BorderRadius.circular(BioAccessTheme.borderRadiusMedium),
                                child: CameraWidget(
                                  onImageCaptured: _onImageCaptured,
                                ),
                              ),
                              const SizedBox(height: BioAccessTheme.paddingMedium),
                              const Text(
                                'Position your face within the frame and look directly at the camera.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14),
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