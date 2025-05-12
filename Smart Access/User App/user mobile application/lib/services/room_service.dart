// lib/services/room_service.dart
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';
import '../models/room.dart';
import 'auth_service.dart';

class RoomService extends ChangeNotifier {
  final AuthService _authService;
  String? _selectedRoomId;
  String? _challengeSentence;
  bool _isLoading = false;
  
  RoomService(this._authService);
  
  String? get selectedRoomId => _selectedRoomId;
  String? get challengeSentence => _challengeSentence;
  bool get isLoading => _isLoading;
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  Future<void> selectRoom(String roomId) async {
    _selectedRoomId = roomId;
    notifyListeners();
  }
  
  Future<Room> getRoomStatus(String roomId) async {
  await _authService.initializationComplete;
  
  try {
    final response = await _authService.dioInstance.get(
      'rooms/$roomId/status/',
      options: Options(
        headers: {
          'Accept': 'application/json',
        },
      ),
    );
    
    if (response.statusCode == 200) {
      // Print the response to debug
      print('Room status response: ${response.data}');
      
      // Create a default room data if needed
      Map<String, dynamic> roomData = response.data is Map 
        ? response.data as Map<String, dynamic>
        : {
            'room_id': roomId,
            'name': 'Room $roomId',
            'is_unlocked': false
          };
          
      // Ensure the required fields exist
      if (!roomData.containsKey('room_id')) {
        roomData['room_id'] = roomId;
      }
      
      if (!roomData.containsKey('name')) {
        roomData['name'] = 'Room $roomId';
      }
      
      // Create the Room object
      return Room.fromJson(roomData);
    } else {
      throw Exception('Failed to get room status');
    }
  } catch (e) {
    print('Error getting room status: $e');
    // Return a default Room object to avoid crashing
    return Room(
      roomId: roomId,
      name: 'Room $roomId',
      isUnlocked: false,
    );
  }
}
  
  Future<Map<String, dynamic>> requestRoomAccess(String roomId) async {
    await _authService.initializationComplete;
    _setLoading(true);
    
    try {
      // Ensure we have a CSRF token
      if (_authService.csrfToken == null) {
        await _authService.fetchCsrfToken();
      }
      
      final response = await _authService.dioInstance.post(
        'rooms/access/request/',
        data: {'room_id': roomId},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        _selectedRoomId = roomId;
        notifyListeners();
        return response.data;
      } else {
        throw Exception(response.data?['error'] ?? 'Failed to request room access');
      }
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data?['error'] ?? e.message ?? 'Failed to request room access');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  Future<Map<String, dynamic>> roomFaceVerify(Uint8List faceImage) async {
    await _authService.initializationComplete;
    _setLoading(true);
    
    try {
      // Ensure we have a CSRF token
      if (_authService.csrfToken == null) {
        await _authService.fetchCsrfToken();
      }
      
      final formData = FormData.fromMap({
        'face_image': MultipartFile.fromBytes(
          faceImage,
          filename: 'face.jpg',
        ),
      });
      
      final response = await _authService.dioInstance.post(
        'rooms/access/face-verify/',
        data: formData,
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        // Store the challenge sentence for voice verification
        _challengeSentence = response.data['challenge_sentence'];
        notifyListeners();
        return response.data;
      } else {
        throw Exception(response.data?['error'] ?? 'Face verification failed');
      }
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data?['error'] ?? e.message ?? 'Face verification failed');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  Future<Map<String, dynamic>> roomVoiceVerify(Uint8List voiceRecording) async {
    await _authService.initializationComplete;
    _setLoading(true);
    
    try {
      // Ensure we have a CSRF token
      if (_authService.csrfToken == null) {
        await _authService.fetchCsrfToken();
      }
      
      final formData = FormData.fromMap({
        'voice_recording': MultipartFile.fromBytes(
          voiceRecording,
          filename: 'voice.wav',
        ),
      });
      
      final response = await _authService.dioInstance.post(
        'rooms/access/voice-verify/',
        data: formData,
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        // Clear session data after successful verification
        _selectedRoomId = null;
        _challengeSentence = null;
        notifyListeners();
        return response.data;
      } else {
        throw Exception(response.data?['error'] ?? 'Voice verification failed');
      }
    } catch (e) {
      if (e is DioException) {
        final errorData = e.response?.data;
        
        // Check if account is frozen
        if (errorData is Map && errorData['is_frozen'] == true) {
          throw Exception('Account is frozen. Please contact an administrator.');
        }
        
        throw Exception(errorData?['error'] ?? e.message ?? 'Voice verification failed');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  // Method to get list of accessible rooms
  Future<List<Room>> getAccessibleRooms() async {
    await _authService.initializationComplete;
    
    try {
      final response = await _authService.dioInstance.get(
        'user/rooms/',
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
      );
      
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((roomData) => Room.fromJson(roomData))
            .toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Error getting accessible rooms: $e');
      return [];
    }
  }
  
  // Alternative name for the same functionality (for compatibility)
  Future<List<Room>> getUserRooms() async {
    return getAccessibleRooms();
  }
  
  // Clear session data (useful when going back to dashboard)
  void clearSession() {
    _selectedRoomId = null;
    _challengeSentence = null;
    notifyListeners();
  }
}