// lib/screens/admin/user_permissions_screen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/theme.dart';
import 'package:go_router/go_router.dart';

class UserPermissionsScreen extends StatefulWidget {
  const UserPermissionsScreen({super.key});
  @override
  State<UserPermissionsScreen> createState() => _UserPermissionsScreenState();
}

class _UserPermissionsScreenState extends State<UserPermissionsScreen> {
  bool _isLoadingUsers = false;
  bool _isLoadingGroups = false;
  bool _isLoadingPermissions = false;
  bool _isLoadingCompany = false;
  List<dynamic> _users = [];
  List<dynamic> _roomGroups = [];
  String? _errorMessage;
  String? _searchQuery;
  Map<String, dynamic>? _selectedUser;
  List<String> _selectedUserPermissions = [];
  Map<String, dynamic>? _companyData;

  @override
  void initState() {
    super.initState();
    final authService = context.read<AuthService>();
    authService.initializationComplete.then((_) {
      if (mounted) {
        _fetchCompanyData();
        _fetchInitialData();
      } 
    });
  }

  Future<void> _fetchInitialData() async {
    await Future.wait([_fetchUsers(), _fetchRoomGroups()]);
    if (_selectedUser != null) _fetchUserPermissions(_selectedUser!['username']);
  }

  Future<void> _fetchCompanyData() async {
    if (_isLoadingCompany) return;
    setState(() { _isLoadingCompany = true; });
    final authService = context.read<AuthService>();
    
    try {
      // If companyData is already in AuthService, use that
      if (authService.companyData != null) {
        setState(() { 
          _companyData = authService.companyData;
          _isLoadingCompany = false;
        });
        return;
      }
      
      // Otherwise fetch it
      _companyData = await authService.getCompanyDetails();
      setState(() { _isLoadingCompany = false; });
    } catch (e) {
      if (mounted) {
        if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
          authService.logout();
          context.go('/login');
          return;
        }
        setState(() { 
          _errorMessage = 'Failed to load company data: ${e.toString().replaceFirst("Exception: ", "")}';
          _isLoadingCompany = false;
        });
      }
    }
  }

  Future<void> _fetchUsers() async {
    if (_isLoadingUsers) return;
    setState(() { _isLoadingUsers = true; _errorMessage = null; });
    final authService = context.read<AuthService>();
    try {
      final response = await authService.dioInstance.get('admin/users/');
      if (response.statusCode == 200) {
        if (mounted) setState(() { 
          // Users are now filtered by company on the backend
          _users = response.data is List ? response.data : []; 
        });
      } else if (response.statusCode == 401 || response.statusCode == 403) { 
        authService.logout(); 
        if (mounted) context.go('/login'); 
        return; 
      } else { 
        throw Exception('Failed users: Status ${response.statusCode}'); 
      }
    } catch (e) { 
      if (mounted) { 
        if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) { 
          authService.logout(); 
          context.go('/login'); 
          return; 
        } 
        setState(() { 
          _errorMessage = 'Failed users: ${e.toString().replaceFirst("Exception: ", "")}'; 
        }); 
      }
    } finally { 
      if (mounted) setState(() { _isLoadingUsers = false; }); 
    }
  }

  Future<void> _fetchRoomGroups() async {
    if (_isLoadingGroups) return;
    setState(() { _isLoadingGroups = true; _errorMessage = null; });
    final authService = context.read<AuthService>();
    try {
      final response = await authService.dioInstance.get('manage/room-groups/');
      if (response.statusCode == 200) { 
        if (mounted) setState(() { 
          // Room groups are now filtered by company on the backend
          _roomGroups = response.data is List ? response.data : []; 
        }); 
      } else if (response.statusCode == 401 || response.statusCode == 403) { 
        authService.logout(); 
        if (mounted) context.go('/login'); 
        return; 
      } else { 
        throw Exception('Failed groups: Status ${response.statusCode}'); 
      }
    } catch (e) { 
      if (mounted) { 
        if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) { 
          authService.logout(); 
          context.go('/login'); 
          return; 
        } 
        setState(() { 
          _errorMessage = 'Failed groups: ${e.toString().replaceFirst("Exception: ", "")}'; 
        }); 
      }
    } finally { 
      if (mounted) setState(() { _isLoadingGroups = false; }); 
    }
  }

  Future<void> _fetchUserPermissions(String username) async {
    if (_isLoadingPermissions) return;
    setState(() { _isLoadingPermissions = true; });
    final authService = context.read<AuthService>();
    try {
      final response = await authService.dioInstance.get('admin/user-permissions/$username/');
      if (response.statusCode == 200) { 
        if (mounted) setState(() { 
          if (response.data is Map && response.data['group_names'] is List) { 
            _selectedUserPermissions = List<String>.from(response.data['group_names']); 
          } else { 
            _selectedUserPermissions = []; 
          } 
        }); 
      } else if (response.statusCode == 404) { 
        if (mounted) setState(() { 
          _errorMessage = "User '$username' not found for permissions."; 
          _selectedUser = null; 
          _selectedUserPermissions = []; 
        }); 
      } else if (response.statusCode == 401 || response.statusCode == 403) { 
        authService.logout(); 
        if (mounted) context.go('/login'); 
        return; 
      } else { 
        throw Exception('Failed perms: Status ${response.statusCode}'); 
      }
    } catch (e) { 
      if (mounted) { 
        if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) { 
          authService.logout(); 
          context.go('/login'); 
          return; 
        } 
        setState(() { 
          _errorMessage = 'Failed perms for $username: ${e.toString().replaceFirst("Exception: ", "")}'; 
          _selectedUser = null; 
          _selectedUserPermissions = []; 
        }); 
      }
    } finally { 
      if (mounted) setState(() { _isLoadingPermissions = false; }); 
    }
  }

  Future<void> _updateUserPermission(String username, String groupName, bool grant) async {
    if (_isLoadingPermissions) return;
    setState(() { _isLoadingPermissions = true; });
    final authService = context.read<AuthService>();

    try {
      // Use the AuthService helper
      await authService.updateUserPermission(username, groupName, grant);

      if (mounted) {
        setState(() { // Update local state immediately
          if (grant) { 
            if (!_selectedUserPermissions.contains(groupName)) _selectedUserPermissions.add(groupName); 
          } else { 
            _selectedUserPermissions.remove(groupName); 
          }
          _isLoadingPermissions = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${grant ? 'Granted' : 'Revoked'} access to $groupName for $username'),
            backgroundColor: grant ? BioAccessTheme.successColor : Colors.orange.shade700
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: BioAccessTheme.errorColor
          )
        );
        setState(() { _isLoadingPermissions = false; });
      }
    }
  }

  List<dynamic> get _filteredUsers {
    if (_searchQuery == null || _searchQuery!.isEmpty) return _users;
    final query = _searchQuery!.toLowerCase();
    return _users.where((user) {
      final username = user['username']?.toString().toLowerCase() ?? '';
      final fullName = user['full_name']?.toString().toLowerCase() ?? '';
      return username.contains(query) || fullName.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = MediaQuery.of(context).size.width > 600 ? 40.0 : 20.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool showTwoColumns = screenWidth >= 900;
    
    // Get company name for header
    final companyName = _companyData != null ? _companyData!['name'] : 'Your Company';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('User Permissions', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Manage which users can access which room groups in $companyName', 
                      style: TextStyle(color: Colors.grey.shade600)
                    ),
                  ],
                ),
              ),
              
              // Add refresh button for complete data refresh
              IconButton(
                icon: _isLoadingCompany || _isLoadingUsers || _isLoadingGroups 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                tooltip: 'Refresh All Data',
                onPressed: _isLoadingCompany || _isLoadingUsers || _isLoadingGroups
                    ? null
                    : () {
                        _fetchCompanyData();
                        _fetchInitialData();
                      },
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: BioAccessTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BioAccessTheme.errorColor.withOpacity(0.3))
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: BioAccessTheme.errorColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: BioAccessTheme.errorColor, fontWeight: FontWeight.bold)
                    )
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: BioAccessTheme.errorColor,
                    onPressed: () => setState(() => _errorMessage = null)
                  ),
                ]
              )
            ),
          ],
          Expanded(
            child: showTwoColumns ? _buildTwoColumnLayout() : _buildSingleColumnLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildTwoColumnLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 350,
          child: _buildUserListPanel()
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _selectedUser != null ? _buildPermissionsPanel() : _buildPermissionsPlaceholder()
        ),
      ]
    );
  }

  Widget _buildSingleColumnLayout() {
    return _selectedUser == null ? _buildUserListPanel() : _buildPermissionsPanel();
  }

  Widget _buildUserListPanel() {
    bool isSingleColumn = MediaQuery.of(context).size.width < 900;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search users...',
              prefixIcon: const Icon(Icons.search),
              isDense: true
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          )
        ),
        Expanded(
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.people_outline, color: BioAccessTheme.primaryBlue),
                  title: const Text('Users', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  trailing: IconButton(
                    icon: _isLoadingUsers 
                        ? const SizedBox(width:18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) 
                        : const Icon(Icons.refresh),
                    tooltip: 'Refresh Users',
                    onPressed: _isLoadingUsers ? null : _fetchUsers,
                    splashRadius: 20
                  )
                ),
                const Divider(height: 1),
                Expanded(
                  child: _buildUsersList(isSingleColumn)
                ),
              ]
            )
          )
        ),
      ]
    );
  }

  Widget _buildUsersList(bool isSingleColumn) {
    if (_isLoadingUsers && _users.isEmpty) return const Center(child: CircularProgressIndicator());
    
    final usersToShow = _filteredUsers;
    
    if (usersToShow.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _searchQuery != null && _searchQuery!.isNotEmpty 
                  ? 'No users match search' 
                  : 'No Users Found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
            ),
            if (_searchQuery == null || _searchQuery!.isEmpty) 
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'User accounts will appear here.',
                  style: TextStyle(color: Colors.grey.shade600)
                )
              )
          ]
        )
      );
    }
    
    return ListView.separated(
      itemCount: usersToShow.length,
      separatorBuilder: (context, index) => const Divider(height: 1, indent: 56),
      itemBuilder: (context, index) {
        final user = usersToShow[index];
        final username = user['username']?.toString() ?? 'N/A';
        final fullName = user['full_name']?.toString() ?? 'No name';
        final bool isSelected = _selectedUser != null && _selectedUser!['username'] == username;
        final bool isAdmin = user['is_admin'] == true;
        
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isSelected 
                ? BioAccessTheme.primaryBlue 
                : Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            child: Text(
              (username.isNotEmpty ? username[0] : '?').toUpperCase(),
              style: TextStyle(
                color: isSelected ? Colors.white : BioAccessTheme.primaryBlue,
                fontWeight: FontWeight.bold
              )
            )
          ),
          title: Row(
            children: [
              Text(
                username,
                style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)
              ),
              if (isAdmin) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Admin',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(fullName),
          selected: isSelected,
          selectedTileColor: BioAccessTheme.primaryBlue.withOpacity(0.08),
          onTap: () {
            setState(() {
              _selectedUser = user;
              _selectedUserPermissions = [];
              _errorMessage = null;
            });
            _fetchUserPermissions(username);
          },
          contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        );
      }
    );
  }

  Widget _buildPermissionsPanel() {
    if (_selectedUser == null) return _buildPermissionsPlaceholder();
    
    final username = _selectedUser!['username']?.toString() ?? 'N/A';
    final fullName = _selectedUser!['full_name']?.toString() ?? 'No Name';
    final isAdmin = _selectedUser!['is_admin'] == true;
    bool isSingleColumn = MediaQuery.of(context).size.width < 900;
    
    return Card(
      elevation: isSingleColumn ? 4 : 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: BioAccessTheme.primaryBlue,
              radius: 20,
              child: Text(
                (username.isNotEmpty ? username[0] : '?').toUpperCase(),
                style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)
              )
            ),
            title: Row(
              children: [
                Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                if (isAdmin) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Admin',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(fullName, style: const TextStyle(color: Colors.grey)),
            trailing: isSingleColumn
                ? IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Back to User List',
                    onPressed: () {
                      setState(() {
                        _selectedUser = null;
                        _selectedUserPermissions = [];
                      });
                    }
                  )
                : null,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Room Group Permissions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
            )
          ),
          if (isAdmin) 
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade900),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Admin users automatically have access to all room groups.',
                        style: TextStyle(color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoadingPermissions)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(child: CircularProgressIndicator())
            )
          else if (_isLoadingGroups)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(child: Text("Loading room groups..."))
            )
          else
            Expanded(
              child: _buildPermissionsList(isAdmin)
            ),
        ]
      )
    );
  }

  Widget _buildPermissionsList([bool isAdmin = false]) {
    if (_roomGroups.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No room groups configured.', textAlign: TextAlign.center)
        )
      );
    }
    
    return ListView.separated(
      itemCount: _roomGroups.length,
      padding: const EdgeInsets.only(bottom: 16),
      separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        final group = _roomGroups[index];
        final groupName = group['name']?.toString() ?? 'Unnamed Group';
        final groupDesc = group['description']?.toString() ?? 'No description';
        final hasAccess = _selectedUserPermissions.contains(groupName) || isAdmin;
        
        return ListTile(
          leading: Icon(
            Icons.folder_shared_outlined,
            color: hasAccess ? BioAccessTheme.successColor : Colors.grey.shade500
          ),
          title: Text(groupName),
          subtitle: Text(groupDesc, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Switch(
            value: hasAccess,
            onChanged: isAdmin 
                ? null // Admins can't have permissions modified
                : (_isLoadingPermissions 
                    ? null 
                    : (value) {
                        if (_selectedUser != null) {
                          _updateUserPermission(
                            _selectedUser!['username'],
                            groupName,
                            value
                          );
                        }
                      }
                  ),
            activeColor: BioAccessTheme.successColor,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
        );
      }
    );
  }

  Widget _buildPermissionsPlaceholder() {
    return Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_search_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text('Select a User', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Select a user from the list to view and manage their permissions.',
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center
              ),
            ]
          )
        )
      )
    );
  }
}