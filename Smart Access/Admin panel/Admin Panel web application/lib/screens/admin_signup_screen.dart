// lib/screens/admin_signup_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../services/auth_service.dart';
import '../widgets/animated_background.dart';
import '../widgets/fade_slide_transition.dart';
import '../widgets/camera_widget.dart';
import '../widgets/voice_recorder_widget.dart';

class AdminSignupScreen extends StatefulWidget {
  const AdminSignupScreen({super.key});

  @override
  State<AdminSignupScreen> createState() => _AdminSignupScreenState();
}

class _AdminSignupScreenState extends State<AdminSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _inviteTokenController = TextEditingController();

  Uint8List? _faceImage;
  Uint8List? _voiceRecording;
  
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, List<String>>? _fieldErrors;
  
  // Company creation mode - true for create new company, false for use invite token
  bool _createCompanyMode = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _fullNameController.dispose();
    _companyNameController.dispose();
    _inviteTokenController.dispose();
    super.dispose();
  }

  Future<void> _verifyToken() async {
    if (_inviteTokenController.text.isEmpty) {
      setState(() {
        _fieldErrors = {
          'invite_token': ['Please enter an invite token']
        };
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _fieldErrors = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final tokenData = await authService.verifyInviteToken(_inviteTokenController.text);
      
      // Pre-fill email if available in token
      if (tokenData['email'] != null) {
        setState(() {
          _emailController.text = tokenData['email'];
        });
      }
      
      // Show success message
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Token verified for ${tokenData['company']['name']}!'),
          backgroundColor: Colors.green,
        ),
      );
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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_faceImage == null) {
      setState(() {
        _errorMessage = "Please capture your face image";
      });
      return;
    }
    
    if (_voiceRecording == null) {
      setState(() {
        _errorMessage = "Please record your voice";
      });
      return;
    }

    // Validate company-specific fields
    if (_createCompanyMode) {
      if (_companyNameController.text.isEmpty) {
        setState(() {
          _fieldErrors = {
            'company_name': ['Please enter a company name']
          };
        });
        return;
      }
    } else {
      if (_inviteTokenController.text.isEmpty) {
        setState(() {
          _fieldErrors = {
            'invite_token': ['Please enter an invite token']
          };
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _fieldErrors = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      await authService.registerAdmin(
        username: _usernameController.text,
        password: _passwordController.text,
        email: _emailController.text,
        phoneNumber: _phoneController.text,
        fullName: _fullNameController.text,
        faceImage: _faceImage!,
        voiceRecording: _voiceRecording!,
        createCompany: _createCompanyMode,
        companyName: _createCompanyMode ? _companyNameController.text : null,
        inviteToken: !_createCompanyMode ? _inviteTokenController.text : null,
      );
      
      // Show success message
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful! You can now log in.'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Redirect to login
      context.go('/login');
    } catch (e) {
      setState(() {
        if (e is Exception) {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          
          // Try to parse field errors if available in the error message
          if (_errorMessage!.contains('errors') && _errorMessage!.contains('{') && _errorMessage!.contains('}')) {
            try {
              // Extract JSON-like string from error message
              final errorsStr = _errorMessage!.substring(_errorMessage!.indexOf('{'), _errorMessage!.lastIndexOf('}') + 1);
              
              // Use dart:convert to parse the JSON string
              final errorJson = jsonDecode(errorsStr);
              
              if (errorJson is Map<String, dynamic>) {
                _fieldErrors = {};
                errorJson.forEach((key, value) {
                  if (value is List) {
                    _fieldErrors![key] = List<String>.from(value.map((item) => item.toString()));
                  } else {
                    _fieldErrors![key] = [value.toString()];
                  }
                });
                
                // Remove extracted part from the main error message
                _errorMessage = _errorMessage!.replaceAll(errorsStr, '').replaceAll('errors: ', '');
              }
            } catch (parsingError) {
              // Parsing failed, keep the original error message
              print('Failed to parse field errors: $parsingError');
            }
          }
        } else {
          _errorMessage = 'Registration failed: ${e.toString()}';
        }
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
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

  String? _getFieldError(String fieldName) {
    if (_fieldErrors != null && _fieldErrors!.containsKey(fieldName)) {
      return _fieldErrors![fieldName]!.join(', ');
    }
    return null;
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
                        const Text(
                          'Create Admin Account',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Complete all fields including biometric data',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Company selection mode toggle
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _createCompanyMode = true;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _createCompanyMode 
                                          ? Colors.blue.shade500 
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Create Company',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _createCompanyMode 
                                            ? Colors.white 
                                            : Colors.blue.shade800,
                                        fontWeight: _createCompanyMode 
                                            ? FontWeight.bold 
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _createCompanyMode = false;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: !_createCompanyMode 
                                          ? Colors.blue.shade500 
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Use Invite Token',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: !_createCompanyMode 
                                            ? Colors.white 
                                            : Colors.blue.shade800,
                                        fontWeight: !_createCompanyMode 
                                            ? FontWeight.bold 
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Company-specific fields
                              if (_createCompanyMode) ...[
                                // Company Name field
                                TextFormField(
                                  controller: _companyNameController,
                                  decoration: InputDecoration(
                                    labelText: 'Company Name',
                                    prefixIcon: const Icon(Icons.business),
                                    errorText: _getFieldError('company_name'),
                                  ),
                                  validator: (value) {
                                    if (_createCompanyMode && (value == null || value.isEmpty)) {
                                      return 'Please enter a company name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                              ] else ...[
                                // Invite Token field
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _inviteTokenController,
                                        decoration: InputDecoration(
                                          labelText: 'Invite Token',
                                          prefixIcon: const Icon(Icons.vpn_key),
                                          errorText: _getFieldError('invite_token'),
                                        ),
                                        validator: (value) {
                                          if (!_createCompanyMode && (value == null || value.isEmpty)) {
                                            return 'Please enter an invite token';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _isLoading ? null : _verifyToken,
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                      child: _isLoading && _inviteTokenController.text.isNotEmpty
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Text('Verify'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                              
                              // Common user fields
                              TextFormField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  prefixIcon: const Icon(Icons.person),
                                  errorText: _getFieldError('username'),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a username';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _fullNameController,
                                decoration: InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon: const Icon(Icons.badge),
                                  errorText: _getFieldError('full_name'),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your full name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: const Icon(Icons.email),
                                  errorText: _getFieldError('email'),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                      .hasMatch(value)) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _phoneController,
                                decoration: InputDecoration(
                                  labelText: 'Phone Number',
                                  prefixIcon: const Icon(Icons.phone),
                                  errorText: _getFieldError('phone_number'),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your phone number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock),
                                  errorText: _getFieldError('password'),
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
                              ),
                              const SizedBox(height: 16),
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
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Face Image',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_getFieldError('face_image') != null) ...[
                                Text(
                                  _getFieldError('face_image')!,
                                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                              ],
                              const SizedBox(height: 16),
                              CameraWidget(
                                onImageCaptured: _onFaceImageCaptured,
                                capturedImage: _faceImage,
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Voice Recording',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_getFieldError('voice_recording') != null) ...[
                                Text(
                                  _getFieldError('voice_recording')!,
                                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                              ],
                              const SizedBox(height: 16),
                              const Text(
                                'Please speak clearly for a few seconds to record your voice.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              VoiceRecorderWidget(
                                onRecordingComplete: _onVoiceRecorded,
                                isRecording: false,
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _register,
                                  child: _isLoading
                                      ? const CircularProgressIndicator()
                                      : const Text('Sign Up'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Already have an account?'),
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
          ),
        ],
      ),
    );
  }
}