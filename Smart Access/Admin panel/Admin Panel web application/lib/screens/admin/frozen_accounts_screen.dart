// --- START OF FILE lib/screens/admin/frozen_accounts_screen.dart ---
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../theme/theme.dart';
import 'package:go_router/go_router.dart';

class FrozenAccountsScreen extends StatefulWidget {
  const FrozenAccountsScreen({super.key});

  @override
  State<FrozenAccountsScreen> createState() => _FrozenAccountsScreenState();
}

class _FrozenAccountsScreenState extends State<FrozenAccountsScreen> {
  bool _isLoading = false;
  List<dynamic> _frozenAccounts = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final authService = context.read<AuthService>();
    authService.initializationComplete.then((_) {
       if (mounted) {
          _fetchFrozenAccounts();
       }
    });
  }

  Future<void> _fetchFrozenAccounts() async {
     if (_isLoading) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    final authService = context.read<AuthService>();
    await authService.initializationComplete;

    try {
      final response = await authService.dioInstance.get('admin/frozen-accounts/');
       if (response.statusCode == 200) {
           if (mounted) setState(() { _frozenAccounts = response.data is List ? response.data : []; });
       } else if (response.statusCode == 401 || response.statusCode == 403) {
           authService.logout(); if (mounted) context.go('/login'); return;
       } else { throw Exception('Failed load: Status ${response.statusCode}'); }
    } catch (e) {
       if (mounted) {
          if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
             authService.logout(); context.go('/login'); return;
          }
          setState(() { _errorMessage = 'Load failed: ${e.toString().replaceFirst("Exception: ", "")}'; });
       }
    } finally { if (mounted) setState(() { _isLoading = false; }); }
  }

  Future<void> _unfreezeAccount(String username) async {
     if (_isLoading) return;
     setState(() {_isLoading = true;});
    final authService = context.read<AuthService>();

    try {
      // Use the AuthService method
      await authService.unfreezeAccount(username);
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Account "$username" has been unfrozen.'),
              backgroundColor: BioAccessTheme.successColor,
              behavior: SnackBarBehavior.floating,
            )
         );
         await _fetchFrozenAccounts(); // Refresh list (will reset isLoading)
      }
    } catch (e) {
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
                content: Text('Unfreeze failed: ${e.toString().replaceFirst("Exception: ", "")}'),
                backgroundColor: BioAccessTheme.errorColor,
                behavior: SnackBarBehavior.floating,
             )
          );
           setState(() {_isLoading = false;}); // Reset loading on error
       }
    }
  }

   String _formatDate(String? dateString) {
      if (dateString == null) return 'Unknown';
      try {
         final dateTime = DateTime.parse(dateString);
         return DateFormat.yMMMd().add_jm().format(dateTime.toLocal());
      } catch (e) { return dateString; }
   }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = MediaQuery.of(context).size.width > 600 ? 40.0 : 20.0;
    return Padding(
       padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Frozen Accounts', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Manage accounts frozen due to failed login attempts', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),

          if (_errorMessage != null) ...[ // Error display
            Container(
              width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: BioAccessTheme.errorColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: BioAccessTheme.errorColor.withOpacity(0.3))),
              child: Row( children: [
                  Icon(Icons.error_outline, color: BioAccessTheme.errorColor), const SizedBox(width: 12),
                  Expanded(child: Text(_errorMessage!, style: const TextStyle(color: BioAccessTheme.errorColor, fontWeight: FontWeight.bold))),
                  IconButton(icon: const Icon(Icons.close, size: 18), color: BioAccessTheme.errorColor, onPressed: () => setState(() => _errorMessage = null)),
              ]),
            ),
          ],
          Card( // Info card
             color: BioAccessTheme.lightBlue.withOpacity(0.1),
             child: Padding( padding: const EdgeInsets.all(16.0), child: Row( children: [
                 Icon(Icons.info_outline, color: BioAccessTheme.lightBlue), const SizedBox(width: 12),
                 Expanded(child: Text('Accounts are frozen after 3 failed attempts. Unfreezing resets the counter.', style: TextStyle(color: BioAccessTheme.primaryBlue))), // Corrected text color
             ])),
          ),
          const SizedBox(height: 24),
          Row( // Header row
            children: [
              Text('Total Frozen: ${_frozenAccounts.length}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              OutlinedButton.icon(
                 onPressed: _isLoading ? null : _fetchFrozenAccounts,
                 icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2,)) : const Icon(Icons.refresh, size: 18),
                 label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded( // List area
            child: _isLoading && _frozenAccounts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _buildFrozenAccountsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFrozenAccountsList() {
    if (_frozenAccounts.isEmpty && !_isLoading) { // Empty state
      return Center( child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.lock_open_outlined, size: 64, color: Colors.grey.shade400), const SizedBox(height: 16),
          Text('No Frozen Accounts', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
          Text('All accounts are currently active.', style: TextStyle(color: Colors.grey.shade600)),
      ]));
    }
     if (_isLoading && _frozenAccounts.isEmpty){ return const Center(child: CircularProgressIndicator()); } // Loading state

    return RefreshIndicator( // List view
      onRefresh: _fetchFrozenAccounts, color: BioAccessTheme.primaryBlue,
      child: ListView.separated(
        itemCount: _frozenAccounts.length, separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final account = _frozenAccounts[index];
          final username = account['username']?.toString() ?? 'Unknown User';
          final fullName = account['full_name']?.toString() ?? 'No name provided';
          final frozenAtText = _formatDate(account['frozen_at']?.toString());
          final failedAttempts = account['failed_attempts']?.toString() ?? 'N/A';
          return ListTile(
             leading: CircleAvatar( backgroundColor: BioAccessTheme.errorColor.withOpacity(0.1), child: Icon( Icons.lock_person_outlined, color: BioAccessTheme.errorColor )),
             title: Text(username, style: const TextStyle(fontWeight: FontWeight.w600)),
             subtitle: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                 Text(fullName), const SizedBox(height: 2),
                 Text('Frozen: $frozenAtText', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                 Text('Failed attempts: $failedAttempts', style: Theme.of(context).textTheme.bodySmall),
             ]),
             trailing: ElevatedButton.icon( // Unfreeze button
                onPressed: _isLoading ? null : () => _showUnfreezeConfirmationDialog(account),
                icon: const Icon(Icons.lock_open_outlined, size: 18), label: const Text('Unfreeze'),
                style: ElevatedButton.styleFrom(backgroundColor: BioAccessTheme.successColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
             ),
             isThreeLine: true, contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
          );
        },
      ),
    );
  }

  void _showUnfreezeConfirmationDialog(Map<String, dynamic> account) { // Dialog
     final username = account['username']?.toString() ?? 'this user';
    showDialog( context: context, builder: (context) => AlertDialog(
         title: const Text('Confirm Unfreeze'),
         content: Column( mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
             Text('Are you sure you want to unfreeze the account for "$username"?'), const SizedBox(height: 16),
             Text('This will reset their failed attempts and allow them to log in.', style: Theme.of(context).textTheme.bodySmall),
         ]),
         actions: [
           TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
           ElevatedButton.icon(
             onPressed: () { Navigator.of(context).pop(); _unfreezeAccount(account['username']); },
             icon: const Icon(Icons.lock_open_outlined, size: 18), label: const Text('Unfreeze'),
             style: ElevatedButton.styleFrom(backgroundColor: BioAccessTheme.successColor, foregroundColor: Colors.white),
           ),
         ],
      ),
    );
  }
}
// --- END OF FILE screens/admin/frozen_accounts_screen.dart ---