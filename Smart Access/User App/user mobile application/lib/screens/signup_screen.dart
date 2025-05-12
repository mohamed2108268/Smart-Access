// lib/screens/signup_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/camera_widget.dart';
import '../widgets/voice_recorder_widget.dart';
import '../theme/theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _isLoading = false;
  bool _createCompany = false;
  bool _useInviteToken = false;
  String? _errorMessage;
  
  // Registration steps
  int _currentStep = 0;
  
  // Biometric data
  Uint8List? _faceImage;
  Uint8List? _voiceRecording;
  
  // Invite token data (if we came from token verification)
  Map<String, dynamic>? _tokenData;
  
  // Services
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkForTokenData();
  }
  
  void _checkForTokenData() {
    // Check if we came from token verification screen with token data
    final router = GoRouter.of(context);
    final queryParams = router.routeInformationProvider.value.uri.queryParameters;
    
    if (queryParams.isNotEmpty) {
      _tokenController.text = queryParams['token'] ?? '';
      _emailController.text = queryParams['email'] ?? '';
      
      if (_tokenController.text.isNotEmpty) {
        setState(() {
          _useInviteToken = true;
        });
      }
    } else {
      // No token provided, redirect back to token verification
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/verify-token');
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _fullNameController.dispose();
    _companyNameController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      // Validate current step before proceeding
      if (_currentStep == 0) {
        // Explicitly check each field individually instead of using _validateBasicInfo
        bool isValid = true;
        
        // Check required fields
        if (_fullNameController.text.isEmpty) {
          setState(() {
            _errorMessage = 'Please enter your full name';
          });
          isValid = false;
        } else if (_phoneController.text.isEmpty) {
          setState(() {
            _errorMessage = 'Please enter your phone number';
          });
          isValid = false;
        } else if (_usernameController.text.isEmpty) {
          setState(() {
            _errorMessage = 'Please enter a username';
          });
          isValid = false;
        } else if (_usernameController.text.length < 4) {
          setState(() {
            _errorMessage = 'Username must be at least 4 characters';
          });
          isValid = false;
        } else if (_passwordController.text.isEmpty) {
          setState(() {
            _errorMessage = 'Please enter a password';
          });
          isValid = false;
        } else if (_passwordController.text.length < 8) {
          setState(() {
            _errorMessage = 'Password must be at least 8 characters';
          });
          isValid = false;
        } else if (_confirmPasswordController.text.isEmpty) {
          setState(() {
            _errorMessage = 'Please confirm your password';
          });
          isValid = false;
        } else if (_passwordController.text != _confirmPasswordController.text) {
          setState(() {
            _errorMessage = 'Passwords do not match';
          });
          isValid = false;
        } else if (_tokenController.text.isEmpty) {
          setState(() {
            _errorMessage = 'Missing invitation token. Please go back to the invitation verification page.';
          });
          isValid = false;
        }
        
        if (!isValid) {
          return;
        }
        
        // Clear any previous error message if all is valid
        setState(() {
          _errorMessage = null;
        });
      }
      
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  bool _validateBasicInfo() {
    // Validate form fields if the form is available
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return false;
    }
    
    // Check if password and confirm password match
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return false;
    }
    
    // Check if token is provided
    if (_tokenController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Missing invitation token. Please go back to the invitation verification page.';
      });
      return false;
    }
    
    // Clear any previous error message
    setState(() {
      _errorMessage = null;
    });
    
    return true;
  }

  void _onFaceImageCaptured(Uint8List imageData) {
    setState(() {
      _faceImage = imageData;
    });
  }

  void _onVoiceRecordingComplete(Uint8List recordingData) {
    setState(() {
      _voiceRecording = recordingData;
    });
  }

  void _register() async {
    // Manually validate all required fields
    bool isValid = true;
    
    // First step validation
    if (_fullNameController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your full name';
        _currentStep = 0;
      });
      isValid = false;
    } else if (_emailController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Email is required';
        _currentStep = 0;
      });
      isValid = false;
    } else if (_phoneController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your phone number';
        _currentStep = 0;
      });
      isValid = false;
    } else if (_usernameController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a username';
        _currentStep = 0;
      });
      isValid = false;
    } else if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a password';
        _currentStep = 0;
      });
      isValid = false;
    } else if (_confirmPasswordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please confirm your password';
        _currentStep = 0;
      });
      isValid = false;
    } else if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
        _currentStep = 0;
      });
      isValid = false;
    } else if (_tokenController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Missing invitation token';
        _currentStep = 0;
      });
      isValid = false;
    }
    
    // Check biometric data
    if (isValid && _faceImage == null) {
      setState(() {
        _errorMessage = 'Face image is required';
        _currentStep = 1; // Go to face capture step
      });
      isValid = false;
    }
    
    if (isValid && _voiceRecording == null) {
      setState(() {
        _errorMessage = 'Voice recording is required';
        _currentStep = 2; // Go to voice recording step
      });
      isValid = false;
    }
    
    if (!isValid) {
      return;
    }
    
    // All validation passed
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await _authService.register(
        username: _usernameController.text,
        password: _passwordController.text,
        email: _emailController.text,
        phoneNumber: _phoneController.text,
        fullName: _fullNameController.text,
        faceImage: _faceImage!,
        voiceRecording: _voiceRecording!,
        inviteToken: _tokenController.text, // Always use the token
        createCompany: false, // Never create company
        companyName: null,
      );
      
      // Navigate to dashboard on success
      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildBasicInfoStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Personal Information
          const Text(
            'Personal Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: BioAccessTheme.paddingMedium),
          
          // Full Name
          TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your full name';
              }
              return null;
            },
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: BioAccessTheme.paddingMedium),
          
          // Email
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Please enter a valid email address';
              }
              return null;
            },
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: BioAccessTheme.paddingMedium),
          
          // Phone
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your phone number';
              }
              return null;
            },
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: BioAccessTheme.paddingLarge),
          
          // Account Information
          const Text(
            'Account Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: BioAccessTheme.paddingMedium),
          
          // Username
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.account_circle),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a username';
              }
              if (value.length < 4) {
                return 'Username must be at least 4 characters';
              }
              return null;
            },
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: BioAccessTheme.paddingMedium),
          
          // Password
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock),
            ),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: BioAccessTheme.paddingMedium),
          
          // Confirm Password
          TextFormField(
            controller: _confirmPasswordController,
            decoration: const InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: BioAccessTheme.paddingLarge),
          
          // Company Information
          const Text(
            'Company Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: BioAccessTheme.paddingMedium),
          
          // Company options
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('Create Company'),
                  value: true,
                  groupValue: _createCompany,
                  onChanged: _useInviteToken 
                      ? null 
                      : (value) {
                          setState(() {
                            _createCompany = value!;
                            if (value) {
                              _useInviteToken = false;
                            }
                          });
                        },
                  dense: true,
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('Join Company'),
                  value: true,
                  groupValue: _useInviteToken,
                  onChanged: _createCompany 
                      ? null 
                      : (value) {
                          setState(() {
                            _useInviteToken = value!;
                            if (value) {
                              _createCompany = false;
                            }
                          });
                        },
                  dense: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: BioAccessTheme.paddingMedium),
          
          // Conditional company fields
          if (_createCompany) ...[
            TextFormField(
              controller: _companyNameController,
              decoration: const InputDecoration(
                labelText: 'Company Name',
                prefixIcon: Icon(Icons.business),
              ),
              validator: _createCompany 
                  ? (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a company name';
                      }
                      return null;
                    }
                  : null,
              textInputAction: TextInputAction.done,
            ),
          ] else if (_useInviteToken) ...[
            TextFormField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Invitation Token',
                prefixIcon: Icon(Icons.vpn_key),
              ),
              validator: _useInviteToken 
                  ? (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your invitation token';
                      }
                      return null;
                    }
                  : null,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: BioAccessTheme.paddingSmall),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.go('/verify-token'),
                child: const Text('Verify Token'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFaceCaptureStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Setup Face Recognition',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: BioAccessTheme.paddingMedium),
        const Text(
          'We need to capture your face.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: BioAccessTheme.paddingLarge),
        
        // Face capture
        if (_faceImage != null) ...[
          AspectRatio(
            aspectRatio: 3/4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(BioAccessTheme.borderRadiusMedium),
              child: Image.memory(
                _faceImage!,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: BioAccessTheme.paddingMedium),
          OutlinedButton.icon(
            onPressed: () => setState(() { _faceImage = null; }),
            icon: const Icon(Icons.refresh),
            label: const Text('Take Again'),
          ),
        ] else ...[
          // Camera widget for capturing
          ClipRRect(
            borderRadius: BorderRadius.circular(BioAccessTheme.borderRadiusMedium),
            child: CameraWidget(
              onImageCaptured: _onFaceImageCaptured,
            ),
          ),
          const SizedBox(height: BioAccessTheme.paddingMedium),
          const Text(
            'Position your face and and look directly at the camera.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
        ],
        
        const SizedBox(height: BioAccessTheme.paddingLarge),
        
        // Instructions
        GlassCard(
          padding: const EdgeInsets.all(BioAccessTheme.paddingMedium),
          child: Column(
            children: [
              const Icon(Icons.info_outline, size: 24),
              const SizedBox(height: BioAccessTheme.paddingSmall),
              const Text(
                'Make sure your face is clear and visible. Avoid wearing hats or glasses.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceCaptureStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Voice Recognition Setup',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: BioAccessTheme.paddingMedium),
        const Text(
          'We need to record your voice',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: BioAccessTheme.paddingLarge),
        
        // Challenge sentence
        GlassCard(
          padding: const EdgeInsets.all(BioAccessTheme.paddingMedium),
          child: Column(
            children: [
              const Icon(Icons.record_voice_over, size: 28),
              const SizedBox(height: BioAccessTheme.paddingSmall),
              const Text(
                'Please read the following sentence :',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BioAccessTheme.paddingMedium),
              const Text(
                'I am recording my voice to setup voice verification, i have made sure to Speak clearly in my normal voice, And i have made sure  i am in quit room that has no echos.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: BioAccessTheme.paddingLarge),
        
        // Voice recorder
        VoiceRecorderWidget(
          onRecordingComplete: _onVoiceRecordingComplete,
          isRecording: false,
        ),
        
        const SizedBox(height: BioAccessTheme.paddingLarge),
        
        // Instructions
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
    );
  }

  List<Widget> _buildStepIndicator() {
    return List.generate(3, (index) {
      return Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: index == _currentStep
              ? BioAccessTheme.primaryColor
              : BioAccessTheme.primaryColor.withOpacity(0.3),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Step ${_currentStep + 1} of 3',
          style: const TextStyle(fontSize: 16),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: _currentStep == 0
              ? () => context.go('/')
              : _previousStep,
        ),
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
                      // Step indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _buildStepIndicator(),
                      ),
                      const SizedBox(height: BioAccessTheme.paddingLarge),
                      
                      // Current step title
                      Text(
                        _currentStep == 0
                            ? 'Create Account'
                            : _currentStep == 1
                                ? 'Face Setup'
                                : 'Voice Setup',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: BioAccessTheme.paddingSmall),
                      Text(
                        _currentStep == 0
                            ? 'Fill out your account details'
                            : _currentStep == 1
                                ? 'Set up facial recognition'
                                : 'Set up voice recognition',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: BioAccessTheme.paddingLarge),
                      
                      // Error message
                      if (_errorMessage != null) ...[
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
                        const SizedBox(height: BioAccessTheme.paddingMedium),
                      ],
                      
                      // Main content card
                      GlassCard(
                        child: _isLoading
                            ? const Center(
                                child: Column(
                                  children: [
                                    SizedBox(height: BioAccessTheme.paddingMedium),
                                    CircularProgressIndicator(),
                                    SizedBox(height: BioAccessTheme.paddingMedium),
                                    Text('Creating your account...'),
                                    SizedBox(height: BioAccessTheme.paddingMedium),
                                  ],
                                ),
                              )
                            : _currentStep == 0
                                ? _buildBasicInfoStep()
                                : _currentStep == 1
                                    ? _buildFaceCaptureStep()
                                    : _buildVoiceCaptureStep(),
                      ),
                      
                      // Navigation buttons
                      const SizedBox(height: BioAccessTheme.paddingLarge),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_currentStep > 0) ...[
                            SizedBox(
                              width: 100,
                              child: OutlinedButton(
                                onPressed: _previousStep,
                                child: const Text('Previous'),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(width: 100),
                          ],
                          
                          SizedBox(
                            width: 100,
                            child: _currentStep < 2
                                ? ElevatedButton(
                                    onPressed: _nextStep,
                                    child: const Text('Next'),
                                  )
                                : ElevatedButton(
                                    onPressed: _register,
                                    child: const Text('Register'),
                                  ),
                          ),
                        ],
                      ),
                      
                      // Login link
                      const SizedBox(height: BioAccessTheme.paddingLarge),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Already have an account?"),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: const Text('Login'),
                          ),
                        ],
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