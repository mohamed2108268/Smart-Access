// lib/screens/admin/room_management_screen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/theme.dart';
import 'package:go_router/go_router.dart';

class RoomManagementScreen extends StatefulWidget {
  const RoomManagementScreen({super.key});
  @override
  State<RoomManagementScreen> createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingRooms = false;
  bool _isLoadingGroups = false;
  List<dynamic> _rooms = [];
  List<dynamic> _roomGroups = [];
  String? _errorMessage;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _roomIdController = TextEditingController();
  final _descriptionController = TextEditingController();
  int? _selectedGroupId;

  // Company info display
  String? _companyName;
  int? _companyId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize company data and fetch rooms/groups
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authService = context.read<AuthService>();
      
      try {
        // Ensure auth service is initialized
        await authService.initializationComplete;
        
        // If we don't have company data, try to fetch it
        if (authService.companyData == null && authService.isAdmin) {
          await authService.getCompanyDetails();
        }
        
        // Get company info from auth service
        final companyData = authService.companyData;
        if (mounted) {
          setState(() {
            _companyName = companyData?['name'] ?? 'Your Company';
            _companyId = companyData?['id']; // Get the company ID
          });
          
          // Fetch data only after we have company info
          _fetchAllData();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to initialize: ${e.toString()}';
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose(); 
    _nameController.dispose(); 
    _roomIdController.dispose(); 
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isLoading => _isLoadingRooms || _isLoadingGroups;

  Future<void> _fetchAllData() async { 
    await Future.wait([_fetchRoomGroups(), _fetchRooms()]); 
  }

  Future<void> _fetchRooms() async {
    if (_isLoadingRooms) return;
    setState(() { _isLoadingRooms = true; _errorMessage = null; });
    final authService = context.read<AuthService>();
    try {
      final response = await authService.dioInstance.get('manage/rooms/');
      if (response.statusCode == 200) { 
        if (mounted) setState(() { 
          _rooms = response.data is List ? response.data : []; 
        }); 
      }
      else if (response.statusCode == 401 || response.statusCode == 403) { 
        authService.logout(); 
        if (mounted) context.go('/login'); 
        return; 
      }
      else { 
        throw Exception('Failed to fetch rooms: Status ${response.statusCode}'); 
      }
    } catch (e) { 
      if (mounted) { 
        if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) { 
          authService.logout(); 
          context.go('/login'); 
          return; 
        } 
        setState(() { 
          _errorMessage = 'Failed to fetch rooms: ${e.toString().replaceFirst("Exception: ", "")}'; 
        }); 
      }
    } finally { 
      if (mounted) setState(() { _isLoadingRooms = false; }); 
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
          _roomGroups = response.data is List ? response.data : []; 
        }); 
      }
      else if (response.statusCode == 401 || response.statusCode == 403) { 
        authService.logout(); 
        if (mounted) context.go('/login'); 
        return; 
      }
      else { 
        throw Exception('Failed to fetch groups: Status ${response.statusCode}'); 
      }
    } catch (e) { 
      if (mounted) { 
        if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) { 
          authService.logout(); 
          context.go('/login'); 
          return; 
        } 
        setState(() { 
          _errorMessage = 'Failed to fetch groups: ${e.toString().replaceFirst("Exception: ", "")}'; 
        }); 
      }
    } finally { 
      if (mounted) setState(() { _isLoadingGroups = false; }); 
    }
  }

  String _parseError(dynamic error) {
    if (error is DioException && error.response?.data != null) {
      final data = error.response!.data; 
      if (data is Map) { 
        if (data.containsKey('detail')) return data['detail']; 
        if (data.containsKey('error')) return data['error']; 
        String fieldErrors = data.entries
          .where((e) => e.value is List && (e.value as List).isNotEmpty)
          .map((e) => '${e.key}: ${(e.value as List).join(", ")}')
          .join("; "); 
        if (fieldErrors.isNotEmpty) return fieldErrors; 
      } 
      return data.toString();
    } else if (error is Exception) { 
      return error.toString().replaceFirst("Exception: ", ""); 
    } 
    return error.toString();
  }

  // Method to toggle room lock status
  // Method to toggle room lock status
  Future<void> _toggleRoomLock(Map<String, dynamic> room) async {
  final bool currentlyLocked = !(room['is_unlocked'] ?? false);
  final String roomId = room['room_id'] ?? '';
  final String roomName = room['name'] ?? 'Unnamed room';
  final String actionText = currentlyLocked ? 'unlock' : 'lock';
  
  if (roomId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Room ID is missing'), 
        backgroundColor: BioAccessTheme.errorColor
      )
    );
    return;
  }
  
  setState(() { _isLoadingRooms = true; });
  
  final authService = context.read<AuthService>();
  try {
    // Ensure we have a CSRF token
    if (authService.csrfToken == null) {
      await authService.fetchCsrfToken();
    }
    
    print("Toggling room lock for $roomId with action: ${currentlyLocked ? 'unlock' : 'lock'}");
    
    final response = await authService.dioInstance.post(
      'rooms/${roomId}/toggle-lock/',
      data: {
        'action': currentlyLocked ? 'unlock' : 'lock',
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );
    
    if (response.statusCode == 200) {
      if (mounted) {
        // Parse the response data
        final responseData = response.data;
        
        // Update the room status in the local list immediately
        setState(() {
          for (int i = 0; i < _rooms.length; i++) {
            if (_rooms[i]['room_id'] == roomId) {
              _rooms[i]['is_unlocked'] = currentlyLocked;
              _rooms[i]['unlock_timestamp'] = responseData['unlock_timestamp'];
              break;
            }
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${roomName} ${currentlyLocked ? 'unlocked' : 'locked'} successfully'),
            backgroundColor: BioAccessTheme.successColor,
          )
        );
        
        // Refresh the rooms list to show updated status
        await _fetchRooms();
      }
    } else {
      throw Exception('Failed to ${actionText} room: Status ${response.statusCode}');
    }
  } catch (e) {
    if (mounted) {
      print("Error toggling room lock: $e");
      print("Error details: ${(e as DioException).response?.data}");
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ${actionText} room: ${_parseError(e)}'),
          backgroundColor: BioAccessTheme.errorColor,
        )
      );
    }
  } finally {
    if (mounted) setState(() { _isLoadingRooms = false; });
  }
  }

  // Method to check the live status of a specific room
  Future<void> _checkRoomStatus(Map<String, dynamic> room) async {
    final String roomId = room['room_id'] ?? '';
    if (roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room ID is missing'), 
          backgroundColor: BioAccessTheme.errorColor
        )
      );
      return;
    }
    
    final authService = context.read<AuthService>();
    try {
      final response = await authService.dioInstance.get('rooms/${roomId}/status/');
      
      if (response.statusCode == 200 && response.data is Map) {
        final statusData = response.data as Map;
        final bool isUnlocked = statusData['is_unlocked'] ?? false;
        final String unlockTime = statusData['unlock_timestamp'] ?? 'N/A';
        
        if (mounted) {
          // Update the room status in the local list
          setState(() {
            for (int i = 0; i < _rooms.length; i++) {
              if (_rooms[i]['room_id'] == roomId) {
                _rooms[i]['is_unlocked'] = isUnlocked;
                _rooms[i]['unlock_timestamp'] = statusData['unlock_timestamp'];
                break;
              }
            }
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Room ${room['name']} is currently ${isUnlocked ? 'UNLOCKED' : 'LOCKED'}'
                '${isUnlocked ? ' since $unlockTime' : ''}',
              ),
              backgroundColor: isUnlocked ? Colors.green : Colors.blue,
              duration: const Duration(seconds: 5),
            )
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to check room status: ${_parseError(e)}'),
            backgroundColor: BioAccessTheme.errorColor,
          )
        );
      }
    }
  }

  Future<void> _addOrUpdateRoom({Map<String, dynamic>? existingRoom}) async {
    if (!_formKey.currentState!.validate()) return;
    
    // Ensure we have company ID
    if (_companyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company information not available. Please try again.'), 
          backgroundColor: BioAccessTheme.errorColor
        )
      );
      return;
    }
    
    final authService = context.read<AuthService>();
    final isUpdating = existingRoom != null;
    final String? idToUpdate = isUpdating ? existingRoom['id']?.toString() : null;
    
    // Include company ID in the data
    final data = { 
      'name': _nameController.text, 
      'room_id': _roomIdController.text, 
      'group': _selectedGroupId,
      'company': _companyId, // Add company ID explicitly
    };
    
    final successMessage = isUpdating ? 'Room updated successfully' : 'Room added successfully';
    final failureMessage = isUpdating ? 'Failed to update room' : 'Failed to add room';

    setState(() { _isLoadingRooms = true; }); 
    Navigator.of(context).pop();
    
    try {
      await authService.addOrUpdateRoom(data: data, roomId: idToUpdate);
      
      if (mounted) { 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage), backgroundColor: BioAccessTheme.successColor)
        ); 
        
        // Refresh the rooms list to show updated data
        await _fetchRooms(); 
      }
    } catch (e) { 
      if (mounted) { 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$failureMessage: ${_parseError(e)}'), 
            backgroundColor: BioAccessTheme.errorColor
          )
        ); 
        setState(() { _isLoadingRooms = false; }); 
      } 
    }
  }

  Future<void> _addOrUpdateRoomGroup({Map<String, dynamic>? existingGroup}) async {
    if (!_formKey.currentState!.validate()) return;
    
    // Ensure we have company ID
    if (_companyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company information not available. Please try again.'), 
          backgroundColor: BioAccessTheme.errorColor
        )
      );
      return;
    }
    
    final authService = context.read<AuthService>();
    final isUpdating = existingGroup != null;
    final String? idToUpdate = isUpdating ? existingGroup['id']?.toString() : null;
    
    // Include company ID in the data
    final data = { 
      'name': _nameController.text, 
      'description': _descriptionController.text,
      'company': _companyId, // Add company ID explicitly
    };
    
    final successMessage = isUpdating ? 'Group updated successfully' : 'Group added successfully';
    final failureMessage = isUpdating ? 'Failed to update group' : 'Failed to add group';

    setState(() { _isLoadingGroups = true; }); 
    Navigator.of(context).pop();
    
    try {
      await authService.addOrUpdateRoomGroup(data: data, groupId: idToUpdate);
      
      if (mounted) { 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage), backgroundColor: BioAccessTheme.successColor)
        ); 
        
        // Refresh the room groups list to show updated data
        await _fetchRoomGroups(); 
      }
    } catch (e) { 
      if (mounted) { 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$failureMessage: ${_parseError(e)}'), 
            backgroundColor: BioAccessTheme.errorColor
          )
        ); 
        setState(() { _isLoadingGroups = false; }); 
      } 
    }
  }

  Future<void> _deleteItem(String type, int id, String name) async {
    final authService = context.read<AuthService>();
    final failureMessage = 'Failed to delete $type';
    final successMessage = '${type[0].toUpperCase()}${type.substring(1)} "$name" deleted successfully';
    final String idString = id.toString();

    setState(() { 
      if (type == 'room') _isLoadingRooms = true; 
      else _isLoadingGroups = true; 
    });
    
    try {
      await authService.deleteResource(type, idString);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage), backgroundColor: BioAccessTheme.successColor)
        );
        if (type == 'room') await _fetchRooms(); 
        else await _fetchRoomGroups();
      }
    } catch (e) { 
      if (mounted) { 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$failureMessage: ${_parseError(e)}'), 
            backgroundColor: BioAccessTheme.errorColor
          )
        ); 
        setState(() { 
          if (type == 'room') _isLoadingRooms = false; 
          else _isLoadingGroups = false; 
        }); 
      } 
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = MediaQuery.of(context).size.width > 600 ? 40.0 : 20.0;
    
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company name display
            if (_companyName != null) ...[
              Text(
                _companyName!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BioAccessTheme.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
            ],
            
            Text('Room Management', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Manage rooms and groups for access control',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Rooms'),
                Tab(text: 'Room Groups'),
              ],
            ),
            const Divider(height: 1),
            
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BioAccessTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BioAccessTheme.errorColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: BioAccessTheme.errorColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: BioAccessTheme.errorColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: BioAccessTheme.errorColor,
                      onPressed: () => setState(() => _errorMessage = null),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRoomsTab(),
                  _buildRoomGroupsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) _showAddEditRoomDialog();
          else _showAddEditRoomGroupDialog();
        },
        tooltip: 'Add New',
        icon: const Icon(Icons.add),
        label: const Text('Add New'),
      ),
    );
  }

  Widget _buildRoomsTab() {
    if (_isLoadingRooms && _rooms.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_rooms.isEmpty && !_isLoadingRooms) {
      return _buildEmptyState(
        icon: Icons.meeting_room_outlined,
        title: 'No Rooms Found',
        message: 'Add a room using the button below.',
        onAction: _showAddEditRoomDialog,
        actionLabel: 'Add Room',
      );
    }
    
    return RefreshIndicator(
      onRefresh: _fetchRooms,
      color: BioAccessTheme.primaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _rooms.length,
        itemBuilder: (context, index) {
          final room = _rooms[index];
          final group = _roomGroups.firstWhere(
            (g) => g['id'] == room['group'],
            orElse: () => {'name': 'Unknown'},
          );
          final groupName = group['name']?.toString() ?? 'Unknown';
          
          // Extract lock status
          final bool isUnlocked = room['is_unlocked'] ?? false;
          final String unlockTimestamp = room['unlock_timestamp'] ?? '';
          
          return Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: BioAccessTheme.primaryBlue.withOpacity(0.1),
                    child: Icon(
                      Icons.sensor_door_outlined,
                      color: BioAccessTheme.primaryBlue,
                    ),
                  ),
                  title: Text(
                    room['name'] ?? 'Unnamed',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ID: ${room['room_id'] ?? 'N/A'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Group: $groupName',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      // Show company info if available
                      if (room['company_name'] != null) ...[
                        Text(
                          'Company: ${room['company_name']}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: BioAccessTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit Room',
                        onPressed: () => _showAddEditRoomDialog(existingRoom: room),
                        color: Colors.grey.shade600,
                        splashRadius: 20,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete Room',
                        onPressed: () => _showDeleteConfirmationDialog(
                          'room',
                          room['name'] ?? 'this',
                          () => _deleteItem('room', room['id'], room['name']),
                        ),
                        color: BioAccessTheme.errorColor,
                        splashRadius: 20,
                      ),
                    ],
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10.0,
                    horizontal: 16.0,
                  ),
                ),
                
                // Add status information and lock/unlock buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 16),
                      Row(
                        children: [
                          // Status indicator
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0, 
                              vertical: 4.0,
                            ),
                            decoration: BoxDecoration(
                              color: isUnlocked
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isUnlocked
                                    ? Colors.green
                                    : Colors.orange,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isUnlocked
                                      ? Icons.lock_open
                                      : Icons.lock,
                                  size: 16,
                                  color: isUnlocked
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isUnlocked ? 'Unlocked' : 'Locked',
                                  style: TextStyle(
                                    color: isUnlocked
                                        ? Colors.green
                                        : Colors.orange,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Last unlock timestamp if available
                          if (isUnlocked && unlockTimestamp.isNotEmpty) ...[
                            Expanded(
                              child: Text(
                                'Unlocked at: $unlockTimestamp',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _toggleRoomLock(room),
                              icon: Icon(
                                isUnlocked ? Icons.lock : Icons.lock_open,
                                size: 18,
                              ),
                              label: Text(isUnlocked ? 'Lock Room' : 'Unlock Room'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isUnlocked
                                    ? Colors.orange
                                    : Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _checkRoomStatus(room),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Check Status'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: BioAccessTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoomGroupsTab() {
    if (_isLoadingGroups && _roomGroups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_roomGroups.isEmpty && !_isLoadingGroups) {
      return _buildEmptyState(
        icon: Icons.group_work_outlined,
        title: 'No Groups Found',
        message: 'Add a group to organize rooms.',
        onAction: _showAddEditRoomGroupDialog,
        actionLabel: 'Add Group',
      );
    }
    
    return RefreshIndicator(
      onRefresh: _fetchRoomGroups,
      color: BioAccessTheme.primaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _roomGroups.length,
        itemBuilder: (context, index) {
          final group = _roomGroups[index];
          final roomsInGroup = _rooms.where((room) => room['group'] == group['id']).toList();
          
          return Card(
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: BioAccessTheme.lightBlue.withOpacity(0.1),
                child: Icon(Icons.folder_copy_outlined, color: BioAccessTheme.lightBlue),
              ),
              title: Text(
                group['name'] ?? 'Unnamed',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${roomsInGroup.length} room(s)'),
                  // Show company info if available
                  if (group['company_name'] != null) ...[
                    Text(
                      'Company: ${group['company_name']}',
                      style: TextStyle(
                        color: BioAccessTheme.primaryBlue,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit Group',
                    onPressed: () => _showAddEditRoomGroupDialog(existingGroup: group),
                    color: Colors.grey.shade600,
                    splashRadius: 20,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete Group',
                    onPressed: () => _showDeleteConfirmationDialog(
                      'group',
                      group['name'] ?? 'this',
                      () => _deleteItem('room group', group['id'], group['name']),
                    ),
                    color: BioAccessTheme.errorColor,
                    splashRadius: 20,
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 16),
                      Text(
                        'Description:',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: BioAccessTheme.textOnSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        group['description'] ?? 'None',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Rooms in group:',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: BioAccessTheme.textOnSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (roomsInGroup.isEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'No rooms in this group.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      ] else ...[
                        ...roomsInGroup.map((room) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.meeting_room_outlined,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${room['name'] ?? '?'} (ID: ${room['room_id'] ?? '?'})',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        )),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    required VoidCallback onAction,
    required String actionLabel,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  void _showAddEditRoomDialog({Map<String, dynamic>? existingRoom}) {
    final bool isEditing = existingRoom != null;
    _formKey.currentState?.reset();
    _nameController.text = isEditing ? existingRoom['name'] ?? '' : '';
    _roomIdController.text = isEditing ? existingRoom['room_id'] ?? '' : '';
    _descriptionController.clear();
    _selectedGroupId = isEditing ? existingRoom['group'] : null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Room' : 'Add Room'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Room Name',
                    hintText: 'e.g., Conference Room A',
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Please enter room name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _roomIdController,
                  decoration: const InputDecoration(
                    labelText: 'Room ID (Unique)',
                    hintText: 'e.g., CONF-A-101',
                    prefixIcon: Icon(Icons.tag),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Please enter unique room ID' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Room Group',
                    prefixIcon: Icon(Icons.folder_copy_outlined),
                  ),
                  value: _selectedGroupId,
                  items: _roomGroups.map<DropdownMenuItem<int>>((group) => 
                    DropdownMenuItem<int>(
                      value: group['id'],
                      child: Text(group['name'] ?? 'Unnamed'),
                    )
                  ).toList(),
                  onChanged: (value) {
                    _selectedGroupId = value;
                  },
                  validator: (v) => (v == null) ? 'Please select a room group' : null,
                  isExpanded: true,
                ),
                // Display current company context
                const SizedBox(height: 16),
                if (_companyName != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: BioAccessTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.business,
                          size: 16,
                          color: BioAccessTheme.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Company: $_companyName',
                          style: TextStyle(
                            color: BioAccessTheme.primaryBlue,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _addOrUpdateRoom(existingRoom: existingRoom),
            child: Text(isEditing ? 'Update' : 'Add Room'),
          ),
        ],
      ),
    );
  }

  void _showAddEditRoomGroupDialog({Map<String, dynamic>? existingGroup}) {
    final bool isEditing = existingGroup != null;
    _formKey.currentState?.reset();
    _nameController.text = isEditing ? existingGroup['name'] ?? '' : '';
    _descriptionController.text = isEditing ? existingGroup['description'] ?? '' : '';
    _roomIdController.clear();
    _selectedGroupId = null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Group' : 'Add Group'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Group Name (Unique)',
                  hintText: 'e.g., Research Labs',
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Please enter group name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g., West wing laboratory rooms',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                maxLines: 3,
              ),
              // Display current company context
              const SizedBox(height: 16),
              if (_companyName != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: BioAccessTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.business,
                        size: 16,
                        color: BioAccessTheme.primaryBlue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Company: $_companyName',
                        style: TextStyle(
                          color: BioAccessTheme.primaryBlue,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _addOrUpdateRoomGroup(existingGroup: existingGroup),
            child: Text(isEditing ? 'Update' : 'Add Group'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(String itemType, String itemName, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm Delete',
          style: TextStyle(color: BioAccessTheme.errorColor),
        ),
        content: Text('Are you sure you want to delete $itemType "$itemName"?\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: BioAccessTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}