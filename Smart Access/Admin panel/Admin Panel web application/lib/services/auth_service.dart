// lib/services/auth_service.dart
import 'package:flutter/foundation.dart'; // Use foundation for kIsWeb
import 'package:flutter/material.dart'; // Required for ChangeNotifier if foundation isn't used
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
// Conditional import for dart:io using platform checks is complex.
// Instead, guard usage of Directory and Cookie with kIsWeb.
import 'dart:io' show Directory, Cookie;
import 'dart:async'; // For Completer
import 'dart:typed_data'; // For Uint8List

class AuthService extends ChangeNotifier {
  late Dio _dio;
  bool _isAuthenticated = false;
  bool _isAdmin = false;
  String? _username;
  Map<String, dynamic>? _userData;
  String? _csrfToken;
  // Company info
  Map<String, dynamic>? _companyData;

  CookieJar? _cookieJar;

  final Completer<void> _initializationCompleter = Completer<void>();
  Future<void> get initializationComplete => _initializationCompleter.future;

  AuthService() {
    _dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:8000/api/',
      contentType: 'application/json',
      receiveDataWhenStatusError: true,
      validateStatus: (status) => status != null && status < 500,
    ));
    _initialize();
  }

  Future<void> _initialize() async {
    // --- Conditional CookieJar Initialization ---
    if (!kIsWeb) {
      String? cookiePath;
      try {
        // path_provider is needed for non-web persistent storage
        Directory appDocDir = await getApplicationDocumentsDirectory();
        cookiePath = "${appDocDir.path}/.cookies/";
        print("Attempting persistent CookieJar for non-web at: $cookiePath");
        _cookieJar = PersistCookieJar(
          ignoreExpires: true,
          storage: FileStorage(cookiePath)
        );
        _dio.interceptors.add(CookieManager(_cookieJar!));
        print("CookieManager added for non-web.");
      } catch (e) {
        print("Could not initialize persistent CookieJar (path: $cookiePath): $e. Using non-persistent for non-web.");
        _cookieJar = CookieJar();
        _dio.interceptors.add(CookieManager(_cookieJar!));
      }
    } else {
      print("Running on Web: Skipping CookieManager. Browser will handle cookies.");
      _cookieJar = null; // Ensure null on web
    }

    // --- CSRF and Credentials Interceptor ---
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.extra['withCredentials'] = true; // Crucial for browser cookies & CORS
          final method = options.method.toUpperCase();

          if (_csrfToken != null && ['POST', 'PUT', 'DELETE', 'PATCH'].contains(method)) {
            options.headers['X-CSRFToken'] = _csrfToken;
            print("[AUTH INTERCEPTOR] Adding header X-CSRFToken: ${_csrfToken?.substring(0, 6)}... for ${options.method} ${options.path}");
          } else if (['POST', 'PUT', 'DELETE', 'PATCH'].contains(method)) {
            print("[AUTH INTERCEPTOR] Warning: CSRF token is NULL for modifying method ${options.method} ${options.path}. Request might fail.");
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _extractCsrfTokenFromResponse(response);
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          print("!!! Error Status: ${e.response?.statusCode} for ${e.requestOptions.path}");
          print("!!! Error Data: ${e.response?.data}");
          if (e.response != null) {
            _extractCsrfTokenFromResponse(e.response!);
            if (e.response?.statusCode == 403 && e.response?.data.toString().contains('CSRF') == true) {
              print("!!! CSRF verification likely failed. Clearing local token '$_csrfToken' to force refetch.");
              _csrfToken = null;
              notifyListeners();
            }
          }
          return handler.next(e);
        }
      ),
    );

    if (!_initializationCompleter.isCompleted) {
      _initializationCompleter.complete();
      print("AuthService initialization complete (Web: $kIsWeb).");
      // Fetch initial CSRF after setup is fully complete
      await fetchCsrfToken();
      print("Initial CSRF fetch attempt finished. Current token: ${_csrfToken == null ? 'NULL' : '${_csrfToken?.substring(0,6)}...'}");
    }
  }

  void _extractCsrfTokenFromResponse(Response response) {
    String? foundToken;
    String? source;

    // 1. Check response data
    if (response.data is Map && response.data.containsKey('csrfToken') && response.data['csrfToken'] is String) {
      foundToken = response.data['csrfToken'];
      source = "response data body";
    }

    // 2. Check 'set-cookie' headers (Primary way browser gets it)
    if (foundToken == null) {
      final cookies = response.headers.map['set-cookie'];
      if (cookies != null) {
        for (final cookie in cookies) {
          final parts = cookie.split(';');
          final firstPart = parts[0].trim();
          if (firstPart.startsWith('csrftoken=')) {
            final tokenValue = firstPart.substring('csrftoken='.length);
            if (tokenValue.isNotEmpty && tokenValue != "null" && tokenValue != "\"\"") {
              foundToken = tokenValue;
              source = "set-cookie header";
              break;
            }
          }
        }
      }
    }

    // 3. Check cookies via CookieJar (Only non-web) - Less critical now
    if (!kIsWeb && _cookieJar != null && foundToken == null) {
      // This part remains less reliable and might not be needed often
      // For brevity, can be commented out if header/body extraction works
      // ... (cookie jar logic as before) ...
    }

    // Update state only if a new, *different*, valid token was found
    if (foundToken != null && foundToken != _csrfToken) {
       print(">>> CSRF token updated from $source: ${foundToken.substring(0, 6)}...");
       _csrfToken = foundToken;
       notifyListeners();
    } else if (foundToken != null && _csrfToken == null) {
        print(">>> Initial CSRF token set from $source: ${foundToken.substring(0, 6)}...");
        _csrfToken = foundToken;
        notifyListeners();
    }
 }

  // --- Getters ---
  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _isAdmin;
  String? get username => _username;
  Map<String, dynamic>? get userData => _userData;
  String? get csrfToken => _csrfToken;
  Dio get dioInstance => _dio;
  Map<String, dynamic>? get companyData => _companyData;

  // --- Auth Flow Methods ---
  Future<void> fetchCsrfToken() async {
    if (!_initializationCompleter.isCompleted) await initializationComplete;
    try {
      print(">>> Attempting to fetch/refresh CSRF token via GET /api/auth/csrf/...");
      await _dio.get('auth/csrf/'); // Interceptor handles extraction
      print(">>> GET /api/auth/csrf/ completed. Current token: ${_csrfToken == null ? 'NULL' : '${_csrfToken?.substring(0,6)}...'}");
    } catch (e) { print('!!! Error during explicit CSRF token fetch: $e'); }
  }

  Future<Map<String, dynamic>> loginStep1(String username, String password) async {
      await initializationComplete;
      if (_csrfToken == null) await fetchCsrfToken();
      print(">>> POST /auth/login/step1/ (CSRF: ${_csrfToken != null})");
      try {
         final response = await _dio.post('auth/login/step1/', data: {'username': username, 'password': password,});
         if (response.statusCode == 200) { return response.data; }
         else { throw DioException(requestOptions: response.requestOptions, response: response, error: response.data?['error'] ?? 'Login step 1 failed'); }
      } on DioException catch (e) { throw Exception(e.response?.data?['error'] ?? e.message ?? 'Login step 1 failed'); }
      catch (e) { throw Exception('An unexpected error occurred during login step 1.'); }
   }

   Future<Map<String, dynamic>> loginStep2(Uint8List faceImage) async {
      await initializationComplete;
      if (_csrfToken == null) { await fetchCsrfToken(); if (_csrfToken == null) throw Exception("CSRF token required for step 2."); }
      print(">>> POST /auth/login/step2/ (CSRF: true)");
      try {
         final formData = FormData.fromMap({'face_image': MultipartFile.fromBytes(faceImage, filename: 'face.jpg'),});
         final response = await _dio.post('auth/login/step2/', data: formData, options: Options(contentType: Headers.multipartFormDataContentType));
         if (response.statusCode == 200) { return response.data; }
         else { throw DioException(requestOptions: response.requestOptions, response: response, error: response.data?['error'] ?? 'Face verification failed'); }
      } on DioException catch (e) { throw Exception(e.response?.data?['error'] ?? e.message ?? 'Face verification failed'); }
      catch (e) { throw Exception('An unexpected error occurred during face verification.'); }
   }

   Future<void> loginStep3(Uint8List voiceRecording) async {
      await initializationComplete;
      if (_csrfToken == null) { await fetchCsrfToken(); if (_csrfToken == null) throw Exception("CSRF token required for step 3."); }
       print(">>> POST /auth/login/step3/ (CSRF: true)");
      try {
         final formData = FormData.fromMap({'voice_recording': MultipartFile.fromBytes(voiceRecording, filename: 'voice.wav'),});
         final response = await _dio.post('auth/login/step3/', data: formData, options: Options(contentType: Headers.multipartFormDataContentType));
         if (response.statusCode == 200) {
            final responseData = response.data;
            if (responseData['user'] != null && responseData['user'] is Map) {
              print(">>> Login Step 3 Successful. Setting auth state.");
              _setAuthStatus(isAuthenticated: true, isAdmin: responseData['user']['is_admin'] ?? false, username: responseData['user']['username'], userData: responseData['user']);
              await fetchCsrfToken(); // Refresh token after successful login
              
              // Fetch company details if admin
              if (_isAdmin) {
                try {
                  await getCompanyDetails();
                } catch (e) {
                  print("Warning: Failed to fetch company details after login: $e");
                }
              }
            } else {
              _setAuthStatus(isAuthenticated: false); throw Exception('Login step 3 successful but response missing user data.');
            }
         } else { throw DioException(requestOptions: response.requestOptions, response: response, error: response.data?['error'] ?? 'Voice verification failed'); }
      } on DioException catch (e) {
         _setAuthStatus(isAuthenticated: false);
         final errorData = e.response?.data; final bool isFrozen = (errorData is Map && errorData['is_frozen'] == true);
         if (isFrozen) { throw Exception('Account is frozen.'); }
         throw Exception(errorData?['error'] ?? e.message ?? 'Voice verification failed');
      } catch (e) { _setAuthStatus(isAuthenticated: false); throw Exception('An unexpected error occurred during voice verification.'); }
   }

   Future<void> logout() async {
      await initializationComplete;
      final originalAuthState = _isAuthenticated;
      try {
         print(">>> Attempting logout POST...");
         await _dio.post('auth/logout/'); // Interceptor adds CSRF if available
         print(">>> Logout POST completed or ignored.");
      } catch (e) { print('Logout API call failed: $e'); }
      finally {
         _setAuthStatus(isAuthenticated: false);
         _csrfToken = null; // Clear CSRF token on logout
         _companyData = null; // Clear company data
         if (!kIsWeb && _cookieJar != null) {
            try { await _cookieJar!.deleteAll(); print("Local cookies deleted (non-web)."); }
            catch(cookieError) { print("Error deleting cookies (non-web): $cookieError"); }
         } else { print("Skipping cookie deletion (Web or no CookieJar)."); }
         print(">>> Local auth state cleared.");
      }
   }

   void _setAuthStatus({ required bool isAuthenticated, bool isAdmin = false, String? username, Map<String, dynamic>? userData, }) {
      if (_isAuthenticated == isAuthenticated && _isAdmin == isAdmin && _username == username) return;
      _isAuthenticated = isAuthenticated;
      if (!isAuthenticated) { _isAdmin = false; _username = null; _userData = null; }
      else { _isAdmin = isAdmin; _username = username; _userData = userData; }
      print("Auth Status Updated: isAuthenticated=$_isAuthenticated, isAdmin=$_isAdmin, username=$_username");
      notifyListeners();
   }

   // --- Company-Related Methods ---

   // For Admin App - Creating a company or joining with invite token
   Future<void> registerAdmin({
     required String username,
     required String password,
     required String email,
     required String phoneNumber,
     required String fullName,
     required Uint8List faceImage,
     required Uint8List voiceRecording,
     required bool createCompany,
     String? companyName,
     String? inviteToken,
   }) async {
     await initializationComplete;
     if (_csrfToken == null) await fetchCsrfToken();
     print(">>> POST /auth/register/ (CSRF: ${_csrfToken != null})");
     
     try {
       final formData = FormData.fromMap({
         'username': username,
         'password': password,
         'email': email,
         'phone_number': phoneNumber,
         'full_name': fullName,
         'face_image': MultipartFile.fromBytes(faceImage, filename: 'face.jpg'),
         'voice_recording': MultipartFile.fromBytes(voiceRecording, filename: 'voice.wav'),
         'create_company': createCompany,
         'company_name': createCompany ? companyName : '',
         'invite_token': !createCompany ? inviteToken : '',
       });
       
       final response = await _dio.post(
         'auth/register/',
         data: formData,
         options: Options(contentType: Headers.multipartFormDataContentType)
       );
       
       if (response.statusCode == 201) {
         print(">>> Registration successful. User should log in.");
         return;
       } else {
         throw DioException(
           requestOptions: response.requestOptions,
           response: response,
           error: response.data?['error'] ?? 'Registration failed'
         );
       }
     } on DioException catch (e) {
       print("!!! Admin Registration Error: ${e.response?.statusCode} - ${e.response?.data}");
       throw Exception(e.response?.data?['error'] ?? e.message ?? 'Registration failed');
     }
   }

   // Verifying invite token
   Future<Map<String, dynamic>> verifyInviteToken(String token) async {
     await initializationComplete;
     if (_csrfToken == null) await fetchCsrfToken();
     print(">>> POST /auth/verify-token/ (CSRF: ${_csrfToken != null})");
     
     try {
       final response = await _dio.post('auth/verify-token/', data: {'token': token});
       
       if (response.statusCode == 200) {
         return response.data;
       } else {
         throw DioException(
           requestOptions: response.requestOptions,
           response: response,
           error: response.data?['error'] ?? 'Token verification failed'
         );
       }
     } on DioException catch (e) {
       print("!!! Token Verification Error: ${e.response?.statusCode} - ${e.response?.data}");
       throw Exception(e.response?.data?['error'] ?? e.message ?? 'Token verification failed');
     }
   }
   
   // Create invite token
   Future<Map<String, dynamic>> createInviteToken(String email, String role) async {
     await initializationComplete;
     if (!_isAuthenticated || !_isAdmin) throw Exception("Admin privileges required.");
     if (_csrfToken == null) { 
       await fetchCsrfToken(); 
       if (_csrfToken == null) throw Exception("CSRF token required for creating invite token.");
     }
     
     // Make sure we have company data
     if (_companyData == null || _companyData!['id'] == null) {
       // Try to fetch company data if not already loaded
       await getCompanyDetails();
       if (_companyData == null || _companyData!['id'] == null) {
         throw Exception("Company information is required but not available.");
       }
     }
     
     print(">>> POST /admin/create-invite/ (Admin) (CSRF: true)");
     
     try {
       final response = await _dio.post('admin/create-invite/', data: {
         'email': email,
         'role': role, // 'admin' or 'user'
         'company': _companyData!['id'], // Add the company ID
       });
       
       if (response.statusCode! >= 200 && response.statusCode! < 300) {
         print(">>> Invite token created successfully");
         return response.data;
       } else {
         throw DioException(
           requestOptions: response.requestOptions,
           response: response,
           error: response.data?['error'] ?? 'Failed to create invite token'
         );
       }
     } on DioException catch (e) {
       print("!!! Create Invite Error: ${e.response?.statusCode} - ${e.response?.data}");
       throw Exception(e.response?.data?['error'] ?? e.message ?? 'Failed to create invite token');
     }
   }

   // List all invite tokens
   Future<List<Map<String, dynamic>>> getInviteTokens() async {
     await initializationComplete;
     if (!_isAuthenticated || !_isAdmin) throw Exception("Admin privileges required.");
     
     try {
       final response = await _dio.get('manage/invite-tokens/');
       
       if (response.statusCode == 200) {
         if (response.data is List) {
           return List<Map<String, dynamic>>.from(response.data);
         } else {
           return [];
         }
       } else {
         throw DioException(
           requestOptions: response.requestOptions,
           response: response,
           error: response.data?['error'] ?? 'Failed to fetch invite tokens'
         );
       }
     } on DioException catch (e) {
       print("!!! Get Invite Tokens Error: ${e.response?.statusCode} - ${e.response?.data}");
       throw Exception(e.response?.data?['error'] ?? e.message ?? 'Failed to fetch invite tokens');
     }
   }

   // Get company details
   Future<Map<String, dynamic>> getCompanyDetails() async {
     await initializationComplete;
     if (!_isAuthenticated || !_isAdmin) throw Exception("Admin privileges required.");
     
     try {
       final response = await _dio.get('admin/company/');
       
       if (response.statusCode == 200) {
         _companyData = response.data;
         notifyListeners();
         return response.data;
       } else {
         throw DioException(
           requestOptions: response.requestOptions,
           response: response,
           error: response.data?['error'] ?? 'Failed to fetch company details'
         );
       }
     } on DioException catch (e) {
       print("!!! Get Company Details Error: ${e.response?.statusCode} - ${e.response?.data}");
       throw Exception(e.response?.data?['error'] ?? e.message ?? 'Failed to fetch company details');
     }
   }

  // --- Room Access Methods ---
   Future<Map<String, dynamic>> requestRoomAccess(String roomId) async {
      await initializationComplete;
      if (!_isAuthenticated) throw Exception("User not authenticated.");
      if (_csrfToken == null) { await fetchCsrfToken(); if (_csrfToken == null) throw Exception("CSRF token required."); }
       print(">>> POST /rooms/access/request/ (CSRF: true)");
      try {
         final response = await _dio.post('rooms/access/request/', data: {'room_id': roomId});
         if (response.statusCode == 200) { return response.data; }
         else { throw DioException(requestOptions: response.requestOptions, response: response, error: response.data?['error'] ?? 'Room access request failed'); }
      } on DioException catch (e) { throw Exception(e.response?.data?['error'] ?? e.message ?? 'Requesting room access failed'); }
   }

   Future<Map<String, dynamic>> submitRoomFace(Uint8List faceImage) async {
       await initializationComplete;
       if (!_isAuthenticated) throw Exception("User not authenticated.");
       if (_csrfToken == null) { await fetchCsrfToken(); if (_csrfToken == null) throw Exception("CSRF token required."); }
       print(">>> POST /rooms/access/face-verify/ (CSRF: true)");
       try {
          final formData = FormData.fromMap({'face_image': MultipartFile.fromBytes(faceImage, filename: 'face.jpg'),});
          final response = await _dio.post('rooms/access/face-verify/', data: formData, options: Options(contentType: Headers.multipartFormDataContentType));
          if (response.statusCode == 200) { return response.data; }
          else { throw DioException(requestOptions: response.requestOptions, response: response, error: response.data?['error'] ?? 'Room face verification failed'); }
       } on DioException catch (e) { throw Exception(e.response?.data?['error'] ?? e.message ?? 'Room face verification failed'); }
    }

   Future<Map<String, dynamic>> submitRoomVoice(Uint8List voiceRecording) async {
       await initializationComplete;
       if (!_isAuthenticated) throw Exception("User not authenticated.");
       if (_csrfToken == null) { await fetchCsrfToken(); if (_csrfToken == null) throw Exception("CSRF token required."); }
        print(">>> POST /rooms/access/voice-verify/ (CSRF: true)");
       try {
          final formData = FormData.fromMap({'voice_recording': MultipartFile.fromBytes(voiceRecording, filename: 'voice.wav'),});
          final response = await _dio.post('rooms/access/voice-verify/', data: formData, options: Options(contentType: Headers.multipartFormDataContentType));
          if (response.statusCode == 200) { return response.data; }
          else { throw DioException(requestOptions: response.requestOptions, response: response, error: response.data?['error'] ?? 'Room voice verification failed'); }
       } on DioException catch (e) {
          final errorData = e.response?.data; final bool isFrozen = (errorData is Map && errorData['is_frozen'] == true);
          if (isFrozen) { _setAuthStatus(isAuthenticated: false); throw Exception('Account is frozen.'); }
          throw Exception(errorData?['error'] ?? e.message ?? 'Room voice verification failed');
       }
    }

  // --- Admin Action Helper Methods ---

  /// Generic helper for authenticated admin POST requests
  Future<Response<dynamic>> postAdminAction(String path, Map<String, dynamic> data) async {
     await initializationComplete;
     if (!_isAuthenticated || !_isAdmin) throw Exception("Admin privileges required.");
     if (_csrfToken == null) { await fetchCsrfToken(); if (_csrfToken == null) throw Exception("CSRF token required for admin action."); }
     print(">>> POST /$path (Admin) (CSRF: true)");
     try {
         final response = await _dio.post(path, data: data);
         // Check for success status codes (e.g., 200 OK, 201 Created, 204 No Content)
         if (response.statusCode! >= 200 && response.statusCode! < 300) { return response; }
         else { throw DioException(requestOptions: response.requestOptions, response: response, error: response.data?['error'] ?? response.data?['detail'] ?? 'Admin action failed'); }
     } on DioException catch(e) {
         print("!!! Admin POST Error: ${e.response?.statusCode} - ${e.response?.data}");
         throw Exception(e.response?.data?['error'] ?? e.response?.data?['detail'] ?? e.message ?? 'Admin POST action failed');
     }
  }

   /// Generic helper for authenticated admin DELETE requests
   Future<Response<dynamic>> deleteAdminAction(String path) async {
      await initializationComplete;
      if (!_isAuthenticated || !_isAdmin) throw Exception("Admin privileges required.");
      if (_csrfToken == null) { await fetchCsrfToken(); if (_csrfToken == null) throw Exception("CSRF token required for admin delete."); }
       print(">>> DELETE /$path (Admin) (CSRF: true)");
      try {
          final response = await _dio.delete(path);
           // Check for success status codes (e.g., 204 No Content, 200 OK, 202 Accepted)
          if (response.statusCode! >= 200 && response.statusCode! < 300) { return response; }
          else { throw DioException(requestOptions: response.requestOptions, response: response, error: response.data?['error'] ?? response.data?['detail'] ?? 'Admin delete action failed'); }
      } on DioException catch(e) {
          print("!!! Admin DELETE Error: ${e.response?.statusCode} - ${e.response?.data}");
          throw Exception(e.response?.data?['error'] ?? e.response?.data?['detail'] ?? e.message ?? 'Admin DELETE action failed');
      }
   }

   /// Generic helper for authenticated admin PUT requests
   Future<Response<dynamic>> putAdminAction(String path, Map<String, dynamic> data) async {
      await initializationComplete;
      if (!_isAuthenticated || !_isAdmin) throw Exception("Admin privileges required.");
      if (_csrfToken == null) { await fetchCsrfToken(); if (_csrfToken == null) throw Exception("CSRF token required for admin update."); }
       print(">>> PUT /$path (Admin) (CSRF: true)");
      try {
          final response = await _dio.put(path, data: data);
           // Check for success status codes (e.g., 200 OK)
          if (response.statusCode! >= 200 && response.statusCode! < 300) { return response; }
          else { throw DioException(requestOptions: response.requestOptions, response: response, error: response.data?['error'] ?? response.data?['detail'] ?? 'Admin update action failed'); }
      } on DioException catch(e) {
          print("!!! Admin PUT Error: ${e.response?.statusCode} - ${e.response?.data}");
          throw Exception(e.response?.data?['error'] ?? e.response?.data?['detail'] ?? e.message ?? 'Admin PUT action failed');
      }
   }

    // --- Specific Admin Actions using Helpers ---

    Future<void> unfreezeAccount(String targetUsername) async {
       await postAdminAction('admin/unfreeze-account/', {'username': targetUsername});
       print("AuthService: Account $targetUsername unfreeze request sent.");
    }

    Future<void> updateUserPermission(String targetUsername, String groupName, bool grant) async {
       await postAdminAction('admin/user-permissions/', {
         'username': targetUsername,
         'group_name': groupName,
         'action': grant ? 'grant' : 'revoke',
       });
        print("AuthService: Permission update request sent for $targetUsername on $groupName.");
    }

    Future<void> addOrUpdateRoom({required Map<String, dynamic> data, String? roomId}) async {
      final path = roomId == null ? 'manage/rooms/' : 'manage/rooms/$roomId/';
      if (roomId == null) {
         await postAdminAction(path, data);
      } else {
         await putAdminAction(path, data);
      }
       print("AuthService: Room save request sent.");
    }

    Future<void> addOrUpdateRoomGroup({required Map<String, dynamic> data, String? groupId}) async {
      final path = groupId == null ? 'manage/room-groups/' : 'manage/room-groups/$groupId/';
      if (groupId == null) {
          await postAdminAction(path, data);
      } else {
          await putAdminAction(path, data);
      }
       print("AuthService: Room Group save request sent.");
    }

    Future<void> deleteResource(String type, String id) async {
       final path = (type.toLowerCase() == 'room') ? 'manage/rooms/$id/' : 'manage/room-groups/$id/';
       await deleteAdminAction(path);
       print("AuthService: Delete request sent for $type $id.");
    }
}