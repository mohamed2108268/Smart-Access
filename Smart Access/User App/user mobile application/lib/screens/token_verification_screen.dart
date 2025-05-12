// lib/screens/token_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../theme/theme.dart';

class TokenVerificationScreen extends StatefulWidget {
  final String? token;

  const TokenVerificationScreen({
    super.key,
    this.token,
  });

  @override
  State<TokenVerificationScreen> createState() => _TokenVerificationScreenState();
}

class _TokenVerificationScreenState extends State<TokenVerificationScreen> {
  final TextEditingController _tokenController = TextEditingController();
  bool _isLoading = false;
  bool _isVerified = false;
  Map<String, dynamic>? _tokenData;
  String? _errorMessage;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    
    // If token was provided in URL, set it and verify
    if (widget.token != null && widget.token!.isNotEmpty) {
      _tokenController.text = widget.token!;
      _verifyToken();
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _verifyToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a token';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.verifyToken(token);
      
      if (result['valid'] == true) {
        setState(() {
          _isVerified = true;
          _tokenData = result;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Invalid token';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _goToSignup() {
    // Navigate to signup with token data as query parameters
    final queryParams = {
      'token': _tokenController.text,
      'email': _tokenData?['email'] ?? '',
      'company_id': _tokenData?['company']?['id']?.toString() ?? '',
      'company_name': _tokenData?['company']?['name'] ?? '',
      'role': _tokenData?['role'] ?? 'user',
    };
    
    // Build query string
    final queryString = queryParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
        
    context.go('/signup?$queryString');
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
          onPressed: () => context.go('/'),
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
                      // Logo
                      Hero(
                        tag: 'app-logo',
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: const BoxDecoration(
                            color: BioAccessTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.vpn_key,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: BioAccessTheme.paddingLarge),
                      
                      // Title
                      Text(
                        'Invitation Verification',
                        style: Theme.of(context).textTheme.displaySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: BioAccessTheme.paddingSmall),
                      const Text(
                        'Verify your invitation token to join a company',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: BioAccessTheme.paddingLarge),
                      
                      // Token input or verification result
                      if (_isVerified && _tokenData != null) ...[
                        // Verified token info
                        GlassCard(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: BioAccessTheme.successColor,
                                size: 48,
                              ),
                              const SizedBox(height: BioAccessTheme.paddingMedium),
                              const Text(
                                'Invitation Verified!',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: BioAccessTheme.successColor,
                                ),
                              ),
                              const SizedBox(height: BioAccessTheme.paddingLarge),
                              
                              // Token information
                              _buildInfoRow(
                                'Email',
                                _tokenData!['email'] ?? 'Not specified',
                              ),
                              _buildInfoRow(
                                'Company',
                                _tokenData!['company']?['name'] ?? 'Not specified',
                              ),
                              _buildInfoRow(
                                'Role',
                                _tokenData!['role'] == 'admin'
                                    ? 'Administrator'
                                    : 'Regular User',
                              ),
                              
                              const SizedBox(height: BioAccessTheme.paddingLarge),
                              
                              // Continue button
                              ElevatedButton(
                                onPressed: _goToSignup,
                                child: const Text('Continue to Registration'),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Token input form
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _tokenController,
                                decoration: const InputDecoration(
                                  labelText: 'Invitation Token',
                                  hintText: 'Enter the token from your invitation email',
                                  prefixIcon: Icon(Icons.vpn_key),
                                ),
                                enabled: !_isLoading,
                              ),
                              
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
                              
                              const SizedBox(height: BioAccessTheme.paddingLarge),
                              
                              // Verify button
                              ElevatedButton(
                                onPressed: _isLoading ? null : _verifyToken,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Verify Token'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      // Info card
                      const SizedBox(height: BioAccessTheme.paddingLarge),
                      GlassCard(
                        padding: const EdgeInsets.all(BioAccessTheme.paddingMedium),
                        child: Column(
                          children: [
                            const Icon(Icons.info_outline, size: 24),
                            const SizedBox(height: BioAccessTheme.paddingSmall),
                            const Text(
                              'You need a valid invitation token to register. If you are registering as a company admin, please create a new company during registration instead.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      
                      // Sign up link for company admins
                      const SizedBox(height: BioAccessTheme.paddingLarge),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Creating a new company?"),
                          TextButton(
                            onPressed: () => context.go('/signup'),
                            child: const Text('Register Here'),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BioAccessTheme.paddingMedium,
        vertical: BioAccessTheme.paddingSmall,
      ),
      child: Row(
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: BioAccessTheme.paddingSmall),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}