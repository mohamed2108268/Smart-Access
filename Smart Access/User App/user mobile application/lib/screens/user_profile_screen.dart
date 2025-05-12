// lib/screens/user_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../widgets/glass_card.dart';
import '../theme/theme.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
  }

  void _logout() async {
    try {
      await Provider.of<AuthService>(context, listen: false).logout();
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: ${e.toString()}')),
      );
    }
  }

  void _showUpdateProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon'),
        content: const Text('Profile updates will be available in a future update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showBiometricUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon'),
        content: const Text('Biometric data updates will be available in a future update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('User not found')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BioAccessTheme.paddingLarge),
        child: Column(
          children: [
            // Profile header
            Center(
              child: Column(
                children: [
                  // Profile picture
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: BioAccessTheme.primaryColor,
                    child: Text(
                      _currentUser!.fullName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: BioAccessTheme.paddingMedium),
                  
                  // Full name
                  Text(
                    _currentUser!.fullName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  // Username
                  Text(
                    '@${_currentUser!.username}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
                    ),
                  ),
                  
                  // Company
                  if (_currentUser!.companyName != null) ...[
                    const SizedBox(height: BioAccessTheme.paddingSmall),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BioAccessTheme.paddingMedium,
                        vertical: BioAccessTheme.paddingSmall,
                      ),
                      decoration: BoxDecoration(
                        color: BioAccessTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(BioAccessTheme.borderRadiusMedium),
                      ),
                      child: Text(
                        _currentUser!.companyName!,
                        style: const TextStyle(
                          color: BioAccessTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  
                  // Admin badge
                  if (_currentUser!.isAdmin) ...[
                    const SizedBox(height: BioAccessTheme.paddingSmall),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BioAccessTheme.paddingMedium,
                        vertical: BioAccessTheme.paddingSmall,
                      ),
                      decoration: BoxDecoration(
                        color: BioAccessTheme.secondaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(BioAccessTheme.borderRadiusMedium),
                      ),
                      child: const Text(
                        'Admin',
                        style: TextStyle(
                          color: BioAccessTheme.secondaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: BioAccessTheme.paddingLarge),
            
            // Contact Information
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.contact_mail, size: 20),
                      SizedBox(width: BioAccessTheme.paddingSmall),
                      Text(
                        'Contact Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildInfoRow(Icons.email, 'Email', _currentUser!.email),
                  _buildInfoRow(Icons.phone, 'Phone', _currentUser!.phoneNumber),
                ],
              ),
            ),
            const SizedBox(height: BioAccessTheme.paddingMedium),
            
            // Account Information
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_circle, size: 20),
                      SizedBox(width: BioAccessTheme.paddingSmall),
                      Text(
                        'Account Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildInfoRow(Icons.badge, 'Username', _currentUser!.username),
                  _buildInfoRow(
                    Icons.business,
                    'Company',
                    _currentUser!.companyName ?? 'Not assigned',
                  ),
                  _buildInfoRow(
                    Icons.admin_panel_settings,
                    'Role',
                    _currentUser!.isAdmin ? 'Administrator' : 'User',
                  ),
                  _buildInfoRow(
                    Icons.lock,
                    'Account Status',
                    _currentUser!.isFrozen ? 'Frozen' : 'Active',
                  ),
                ],
              ),
            ),
            const SizedBox(height: BioAccessTheme.paddingMedium),
            
            // Biometric Information
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.fingerprint, size: 20),
                      SizedBox(width: BioAccessTheme.paddingSmall),
                      Text(
                        'Biometric Data',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildInfoRow(
                    Icons.face,
                    'Face Reference',
                    'Registered',
                    trailingIcon: Icons.update,
                    onTrailingTap: _showBiometricUpdateDialog,
                  ),
                  _buildInfoRow(
                    Icons.record_voice_over,
                    'Voice Reference',
                    'Registered',
                    trailingIcon: Icons.update,
                    onTrailingTap: _showBiometricUpdateDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: BioAccessTheme.paddingLarge),
            
            // Buttons
            ElevatedButton.icon(
              onPressed: _showUpdateProfileDialog,
              icon: const Icon(Icons.edit),
              label: const Text('Update Profile'),
            ),
            const SizedBox(height: BioAccessTheme.paddingMedium),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: BioAccessTheme.errorColor,
                side: const BorderSide(color: BioAccessTheme.errorColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    IconData? trailingIcon,
    VoidCallback? onTrailingTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BioAccessTheme.paddingSmall),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: BioAccessTheme.paddingSmall),
          Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: BioAccessTheme.paddingSmall),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          if (trailingIcon != null) ...[
            IconButton(
              icon: Icon(trailingIcon, size: 18),
              onPressed: onTrailingTap,
            ),
          ],
        ],
      ),
    );
  }
}