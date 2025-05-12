// lib/screens/room_access_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/room_service.dart';
import '../theme/theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';
import '../models/room.dart';

class RoomAccessScreen extends StatefulWidget {
  final String roomId;

  const RoomAccessScreen({
    super.key,
    required this.roomId,
  });

  @override
  State<RoomAccessScreen> createState() => _RoomAccessScreenState();
}

class _RoomAccessScreenState extends State<RoomAccessScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  Room? _room;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRoomStatus();
    });
  }
  
  Future<void> _loadRoomStatus() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });
    
    try {
      final roomService = Provider.of<RoomService>(context, listen: false);
      
      // First, get the room status
      _room = await roomService.getRoomStatus(widget.roomId);
      
      // If the room is already unlocked, no need for verification
      if (_room!.isUnlocked) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          // Show success message before redirecting
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room is already unlocked'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Delay a bit before going back to dashboard
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              context.go('/dashboard');
            }
          });
        }
        return;
      }
      
      // If room is not unlocked, start the access request process
      await _requestAccess();
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _requestAccess() async {
    try {
      final roomService = Provider.of<RoomService>(context, listen: false);
      
      // Request access to the room
      await roomService.requestRoomAccess(widget.roomId);
      
      // Navigate to face verification step
      if (mounted) {
        context.go('/room/${widget.roomId}/face-verification');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_room?.name ?? 'Room ${widget.roomId}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const AnimatedBackground(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isLoading) ...[
                      // Loading state
                      GlassCard(
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            const CircularProgressIndicator(),
                            const SizedBox(height: 24),
                            Text(
                              'Requesting access to ${_room?.name ?? 'Room ${widget.roomId}'}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Please wait while we verify your permissions...',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ] else if (_hasError) ...[
                      // Error state
                      GlassCard(
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Access Error',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                _errorMessage ?? 'Unknown error occurred',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () => context.go('/dashboard'),
                              child: const Text('Back to Dashboard'),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _loadRoomStatus,
                              child: const Text('Try Again'),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ] else if (_room?.isUnlocked ?? false) ...[
                      // Already unlocked state
                      GlassCard(
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            const Icon(
                              Icons.check_circle,
                              size: 64,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Room Already Unlocked',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'The room ${_room?.name ?? widget.roomId} is already unlocked.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () => context.go('/dashboard'),
                              child: const Text('Back to Dashboard'),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}