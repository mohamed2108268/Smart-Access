// lib/widgets/admin_drawer.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class AdminDrawer extends StatelessWidget {
  final String currentPage;
  
  const AdminDrawer({
    super.key,
    required this.currentPage,
  });

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final companyData = authService.companyData;
    final companyName = companyData != null ? companyData['name'] : 'Your Company';
    final username = authService.username ?? 'Admin';
    
    return Drawer(
      child: Column(
        children: [
          // Drawer header with company info
          UserAccountsDrawerHeader(
            accountName: Text(companyName),
            accountEmail: Text('Logged in as: $username'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                companyName.isNotEmpty ? companyName[0].toUpperCase() : 'C',
                style: const TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
              ),
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
          ),
          
          // Dashboard
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            selected: currentPage == 'dashboard',
            onTap: () {
              if (currentPage != 'dashboard') {
                context.go('/admin-dashboard');
              }
              Navigator.pop(context);
            },
          ),
          
          // Invite Management
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Invite Management'),
            selected: currentPage == 'invites',
            onTap: () {
              if (currentPage != 'invites') {
                context.go('/admin/invites');
              }
              Navigator.pop(context);
            },
          ),
          
          const Divider(),
          
          // Logout
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              Navigator.pop(context);
              
              try {
                await authService.logout();
                // After logout, redirect to login page
                if (context.mounted) {
                  context.go('/login');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error during logout: $e')),
                  );
                }
              }
            },
          ),
          
          const Spacer(),
          
          // App version at the bottom
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'BioAccess Admin v1.0',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}