// lib/screens/admin/invite_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/admin_drawer.dart';
import '../../widgets/loading_overlay.dart';

class InviteManagementScreen extends StatefulWidget {
  const InviteManagementScreen({super.key});

  @override
  State<InviteManagementScreen> createState() => _InviteManagementScreenState();
}

class _InviteManagementScreenState extends State<InviteManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String _selectedRole = 'user';
  
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  
  List<Map<String, dynamic>> _inviteTokens = [];
  
  @override
  void initState() {
    super.initState();
    _initialize();
  }
  
  Future<void> _initialize() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Ensure company data is loaded
      if (authService.companyData == null) {
        await authService.getCompanyDetails();
      }
      
      // Load invite tokens
      await _loadInviteTokens();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
  
  Future<void> _loadInviteTokens() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final tokens = await authService.getInviteTokens();
      
      setState(() {
        _inviteTokens = tokens;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load invite tokens: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _createInviteToken() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Check if company data is available
      if (authService.companyData == null) {
        throw Exception('Company information not available. Please try again.');
      }
      
      await authService.createInviteToken(_emailController.text, _selectedRole);
      
      setState(() {
        _successMessage = 'Invite token created and sent to ${_emailController.text}';
        _emailController.clear();
      });
      
      // Reload the token list
      await _loadInviteTokens();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create invite token: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _copyToClipboard(String token) {
    Clipboard.setData(ClipboardData(text: token));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Token copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final companyData = authService.companyData;
    final companyName = companyData != null ? companyData['name'] : 'Your Company';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Management'),
      ),
      drawer: const AdminDrawer(currentPage: 'invites'),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create New Invite for $companyName',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      if (_errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      if (_successMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _successMessage!,
                            style: TextStyle(color: Colors.green.shade700),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      Form(
                        key: _formKey,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email Address',
                                  hintText: 'Enter recipient\'s email',
                                  prefixIcon: Icon(Icons.email),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter an email address';
                                  }
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                    return 'Please enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedRole,
                                decoration: const InputDecoration(
                                  labelText: 'Role',
                                  prefixIcon: Icon(Icons.badge),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'user',
                                    child: Text('Regular User'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'admin',
                                    child: Text('Administrator'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedRole = value;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: (_isLoading || companyData == null) ? null : _createInviteToken,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              ),
                              child: const Text('Create & Send Invite'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              Text(
                'Active Invite Tokens',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              
              Expanded(
                child: Card(
                  elevation: 2,
                  child: _inviteTokens.isEmpty
                      ? const Center(
                          child: Text(
                            'No active invite tokens',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _inviteTokens.length,
                          itemBuilder: (context, index) {
                            final token = _inviteTokens[index];
                            final isUsed = token['is_used'] ?? false;
                            final isExpired = DateTime.parse(token['expires_at']).isBefore(DateTime.now());
                            final isValid = !isUsed && !isExpired;
                            
                            return ListTile(
                              title: Text(token['email']),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Role: ${token['role'] == 'admin' ? 'Administrator' : 'Regular User'}'),
                                  Text(
                                    'Created: ${DateTime.parse(token['created_at']).toLocal().toString().substring(0, 16)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    'Expires: ${DateTime.parse(token['expires_at']).toLocal().toString().substring(0, 16)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              leading: CircleAvatar(
                                backgroundColor: isValid
                                    ? Colors.green.shade100
                                    : Colors.grey.shade200,
                                child: Icon(
                                  isValid ? Icons.mark_email_unread : Icons.email_outlined,
                                  color: isValid ? Colors.green : Colors.grey,
                                ),
                              ),
                              trailing: isValid
                                  ? IconButton(
                                      icon: const Icon(Icons.copy),
                                      tooltip: 'Copy Token',
                                      onPressed: () => _copyToClipboard(token['token']),
                                    )
                                  : Chip(
                                      label: Text(
                                        isUsed ? 'Used' : 'Expired',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      backgroundColor: Colors.grey.shade200,
                                    ),
                              isThreeLine: true,
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}