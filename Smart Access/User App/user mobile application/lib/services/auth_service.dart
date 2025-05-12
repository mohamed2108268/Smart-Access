// lib/services/auth_service.dart
import 'package:flutter/foundation.dart'; // Use foundation for kIsWeb
import 'package:flutter/material.dart'; // Required for ChangeNotifier
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' show Directory;
import 'dart:async'; // For Completer
import 'dart:typed_data'; // For Uint8List
import '../models/user.dart'; // Your User model

class AuthService extends ChangeNotifier {
  late Dio _dio;
  bool _isAuthenticated = false;
  bool _isAdmin = false;
  String? _username;
  Map<String, dynamic>? _userData;
  String? _csrfToken;
  User? _currentUser;
  
  // Login state
  String? _loginUsername;
  int _loginStep = 0;
  int _remainingTime = 0;
  String? _challengeSentence;
  
  // Session token for maintaining state between screens
  String? _sessionToken;
  
  // Room access state
  String? _accessRoomId;
  int _accessStep = 0;

  CookieJar? _cookieJar;

  final Completer<void> _initializationCompleter = Completer<void>();
  Future<void> get initializationComplete => _initializationCompleter.future;
  
  // Authentication state stream controller
  final _authStateController = StreamController<bool>.broadcast();
  Stream<bool> get authStateChanges => _authStateController.stream;

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
    // --- Configure Dio defaults for web ---
    _dio.options.extra = {
      ..._dio.options.extra,
      'withCredentials': true,
    };

    // --- Conditional CookieJar Initialization ---
    if (!kIsWeb) {
      String? cookiePath;
      try {
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
        print("Could not initialize persistent CookieJar: $e. Using non-persistent for non-web.");
        _cookieJar = CookieJar();
        _dio.interceptors.add(CookieManager(_cookieJar!));
      }
    } else {
      print("Running on Web: Browser will handle cookies.");
      _cookieJar = null; // Ensure null on web
    }

    // --- CSRF and Credentials Interceptor ---
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Always ensure withCredentials is true
          options.extra['withCredentials'] = true;
          
          // Add standard headers
          if (!options.headers.containsKey(Headers.contentTypeHeader) && 
              !options.headers.containsKey('content-type') &&
              options.contentType != Headers.multipartFormDataContentType) {
            options.headers[Headers.contentTypeHeader] = Headers.jsonContentType;
          }
          
          // Add Accept header if not present
          if (!options.headers.containsKey(Headers.acceptHeader)) {
            options.headers[Headers.acceptHeader] = Headers.jsonContentType;
          }
          
          final method = options.method.toUpperCase();
          
          // Add session token to maintain context between screens if available
          if (_sessionToken != null) {
            options.headers['X-Session-Token'] = _sessionToken;
          }
          
          // Add username to help maintain session context
          if (_loginUsername != null) {
            // Add username to query parameters for all requests during login flow
            if (!options.queryParameters.containsKey('username')) {
              options.queryParameters['username'] = _loginUsername;
            }
            
            // For form data, add username if not already added
            if (options.data is FormData) {
              final formData = options.data as FormData;
              bool hasUsername = false;
              for (var field in formData.fields) {
                if (field.key == 'username') {
                  hasUsername = true;
                  break;
                }
              }
              if (!hasUsername) {
                (options.data as FormData).fields.add(MapEntry('username', _loginUsername!));
              }
            }
            // For JSON data, add username if not already added
            else if (options.data is Map && !options.data.containsKey('username')) {
              options.data['username'] = _loginUsername;
            }
          }

          if (kIsWeb) {
            print("[REQUEST] ${method} ${options.path} (withCredentials: ${options.extra['withCredentials']})");
            print("[REQUEST HEADERS] ${options.headers}");
            
            // Print query parameters if any
            if (options.queryParameters.isNotEmpty) {
              print("[REQUEST QUERY] ${options.queryParameters}");
            }
          }

          if (_csrfToken != null && ['POST', 'PUT', 'DELETE', 'PATCH'].contains(method)) {
            options.headers['X-CSRFToken'] = _csrfToken;
            print("[AUTH INTERCEPTOR] Adding header X-CSRFToken: ${_csrfToken?.substring(0, 6)}... for ${options.method} ${options.path}");
          } else if (['POST', 'PUT', 'DELETE', 'PATCH'].contains(method)) {
            print("[AUTH INTERCEPTOR] Warning: CSRF token is NULL for modifying method ${options.method} ${options.path}. Request might fail.");
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kIsWeb) {
            print("[RESPONSE] ${response.statusCode} for ${response.requestOptions.path}");
            print("[RESPONSE HEADERS] ${response.headers.map}");
            
            // Check for session token in response
            if (response.headers.map.containsKey('x-session-token')) {
              _sessionToken = response.headers.value('x-session-token');
              print("[SESSION] Found session token in response: ${_sessionToken?.substring(0, 8)}...");
            }
            
            // Check specifically for Set-Cookie headers
            if (response.headers.map.containsKey('set-cookie')) {
              print("[COOKIES SET] Found in response: ${response.headers.map['set-cookie']}");
            }
          }
          
          _extractCsrfTokenFromResponse(response);
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          print("!!! Error Status: ${e.response?.statusCode} for ${e.requestOptions.path}");
          print("!!! Error Data: ${e.response?.data}");
          
          if (kIsWeb && e.response != null) {
            print("!!! Error Headers: ${e.response!.headers.map}");
          }
          
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

    // Try to fetch current user profile to check if already logged in
    try {
      final response = await _dio.get('user/profile/');
      if (response.statusCode == 200) {
        _userData = response.data;
        _isAuthenticated = true;
        _username = response.data['username'];
        _isAdmin = response.data['is_admin'] ?? false;
        _currentUser = User.fromJson(response.data);
        _authStateController.add(true);
      }
    } catch (e) {
      print('Not logged in: $e');
    }

    if (!_initializationCompleter.isCompleted) {
      _initializationCompleter.complete();
      print("AuthService initialization complete (Web: $kIsWeb).");
      await fetchCsrfToken();
      print("Initial CSRF fetch attempt finished. Current token: ${_csrfToken == null ? 'NULL' : '${_csrfToken?.substring(0,6)}...'}");
    }
    
    notifyListeners();
  }

  void _extractCsrfTokenFromResponse(Response response) {
    String? foundToken;
    String? source;

    // 1. Check response data
    if (response.data is Map && response.data.containsKey('csrfToken') && response.data['csrfToken'] is String) {
      foundToken = response.data['csrfToken'];
      source = "response data body";
    }

    // 2. Check 'set-cookie' headers
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

    // 3. Check for X-CSRFToken header
    if (foundToken == null) {
      final csrfHeader = response.headers.value('x-csrftoken');
      if (csrfHeader != null && csrfHeader.isNotEmpty) {
        foundToken = csrfHeader;
        source = "x-csrftoken header";
      }
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
  User? get currentUser => _currentUser;
  
  // Login state getters
  String? get challengeSentence => _challengeSentence;
  int get remainingTime => _remainingTime;
  int get loginStep => _loginStep;
  String? get sessionToken => _sessionToken;
  
  // Room access state getters
  int get accessStep => _accessStep;
  String? get accessRoomId => _accessRoomId;

  // --- Auth Flow Methods ---
  Future<void> fetchCsrfToken() async {
    if (!_initializationCompleter.isCompleted) await initializationComplete;
    try {
      print(">>> Attempting to fetch/refresh CSRF token via GET /api/auth/csrf/...");
      await _dio.get('auth/csrf/');
      print(">>> GET /api/auth/csrf/ completed. Current token: ${_csrfToken == null ? 'NULL' : '${_csrfToken?.substring(0,6)}...'}");
    } catch (e) { print('!!! Error during explicit CSRF token fetch: $e'); }
  }

  // Reset login state
  void resetLoginState() {
    _loginUsername = null;
    _loginStep = 0;
    _challengeSentence = null;
    _sessionToken = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>> loginStep1(String username, String password) async {
    await initializationComplete;
    if (_csrfToken == null) await fetchCsrfToken();
    print(">>> POST /auth/login/step1/ (CSRF: ${_csrfToken != null})");
    
    // Save username in memory for session context between screens
    _loginUsername = username;
    
    try {
      final response = await _dio.post(
        'auth/login/step1/', 
        data: {
          'username': username, 
          'password': password,
        },
        options: Options(
          headers: {
            'X-CSRFToken': _csrfToken,
          },
          extra: {
            'withCredentials': true,
          }
        )
      );
      
      if (response.statusCode == 200) {
        // Store login state in memory
        _loginStep = 1;
        _remainingTime = response.data['remaining_time'] ?? 20;
        
        // Check for session token in the response
        if (response.data['session_token'] != null) {
          _sessionToken = response.data['session_token'];
          print(">>> Received session token: ${_sessionToken?.substring(0, 8)}...");
        }
        
        return response.data;
      } else {
        throw DioException(
          requestOptions: response.requestOptions, 
          response: response, 
          error: response.data?['error'] ?? 'Login step 1 failed'
        );
      }
    } on DioException catch (e) {
      print("!!! Login step 1 failed: ${e.response?.statusCode}, ${e.response?.data}");
      throw Exception(e.response?.data?['error'] ?? e.message ?? 'Login step 1 failed');
    } catch (e) {
      print("!!! Unexpected error in login step 1: $e");
      throw Exception('An unexpected error occurred during login step 1.');
    }
  }

  Future<Map<String, dynamic>> loginStep2(Uint8List faceImage) async {
    await initializationComplete;
    if (_csrfToken == null) {
      await fetchCsrfToken();
      if (_csrfToken == null) throw Exception("CSRF token required for step 2.");
    }
    print(">>> POST /auth/login/step2/ (CSRF: true)");
    
    // Ensure we have username saved
    if (_loginUsername == null) {
      throw Exception("Login state lost. Please start the login process again.");
    }
    
    try {
      final formData = FormData.fromMap({
        'face_image': MultipartFile.fromBytes(faceImage, filename: 'face.jpg'),
        'username': _loginUsername, // Explicit username
        'login_step': '1',         // Explicit step
      });
      
      // Add session token if available
      final headers = <String, dynamic>{
        'X-CSRFToken': _csrfToken,
        'X-Username': _loginUsername,
      };
      
      if (_sessionToken != null) {
        headers['X-Session-Token'] = _sessionToken;
      }
      
      final response = await _dio.post(
        'auth/login/step2/', 
        queryParameters: {'username': _loginUsername}, // Explicit in query params
        data: formData,
        options: Options(
          headers: headers,
          contentType: Headers.multipartFormDataContentType,
          extra: {
            'withCredentials': true,
          }
        )
      );
      
      if (response.statusCode == 200) {
        // Update state
        _loginStep = 2;
        _remainingTime = response.data['remaining_time'] ?? 30;
        _challengeSentence = response.data['challenge_sentence'];
        
        // Update session token if provided
        if (response.data['session_token'] != null) {
          _sessionToken = response.data['session_token'];
          print(">>> Updated session token: ${_sessionToken?.substring(0, 8)}...");
        }

        return response.data;
      } else {
        throw DioException(
          requestOptions: response.requestOptions, 
          response: response, 
          error: response.data?['error'] ?? 'Face verification failed'
        );
      }
    } on DioException catch (e) {
      print("!!! Login step 2 error: ${e.response?.statusCode}, ${e.response?.data}");
      print("!!! Request path: ${e.requestOptions.path}");
      print("!!! Request headers: ${e.requestOptions.headers}");
      throw Exception(e.response?.data?['error'] ?? e.message ?? 'Face verification failed');
    } catch (e) {
      print("!!! Login step 2 unexpected error: $e");
      throw Exception('An unexpected error occurred during face verification.');
    }
  }

  Future<void> loginStep3(Uint8List voiceRecording) async {
    await initializationComplete;
    if (_csrfToken == null) {
      await fetchCsrfToken();
      if (_csrfToken == null) throw Exception("CSRF token required for step 3.");
    }
    print(">>> POST /auth/login/step3/ (CSRF: true)");
    
    // Ensure we have username and challenge saved
    if (_loginUsername == null || _challengeSentence == null) {
      throw Exception("Login state lost. Please start the login process again.");
    }
    
    try {
      final formData = FormData.fromMap({
        'voice_recording': MultipartFile.fromBytes(voiceRecording, filename: 'voice.wav'),
        'username': _loginUsername,      // Explicit username
        'login_step': '2',               // Explicit step
        'challenge_sentence': _challengeSentence,  // Include challenge sentence
      });
      
      // Add session token if available
      final headers = <String, dynamic>{
        'X-CSRFToken': _csrfToken,
      };
      
      if (_sessionToken != null) {
        headers['X-Session-Token'] = _sessionToken;
      }
      
      final response = await _dio.post(
        'auth/login/step3/', 
        data: formData,
        options: Options(
          headers: headers,
          contentType: Headers.multipartFormDataContentType,
          extra: {
            'withCredentials': true,
          }
        )
      );
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData['user'] != null && responseData['user'] is Map) {
          print(">>> Login Step 3 Successful. Setting auth state.");
          _setAuthStatus(
            isAuthenticated: true, 
            isAdmin: responseData['user']['is_admin'] ?? false, 
            username: responseData['user']['username'], 
            userData: responseData['user']
          );
          
          // Convert userData to User object if needed
          if (_userData != null) {
            _currentUser = User.fromJson(_userData!);
          }
          
          _authStateController.add(true);
          
          // Clear login state data after successful login
          _loginStep = 0;
          _sessionToken = null; // Clear temporary token
          _challengeSentence = null;
          
          // Refresh CSRF token after successful login
          await fetchCsrfToken();
        } else {
          _setAuthStatus(isAuthenticated: false);
          throw Exception('Login step 3 successful but response missing user data.');
        }
      } else {
        throw DioException(
          requestOptions: response.requestOptions, 
          response: response, 
          error: response.data?['error'] ?? 'Voice verification failed'
        );
      }
    } on DioException catch (e) {
      _setAuthStatus(isAuthenticated: false);
      final errorData = e.response?.data;
      final bool isFrozen = (errorData is Map && errorData['is_frozen'] == true);
      
      print("!!! Login step 3 error: ${e.response?.statusCode}, ${e.response?.data}");
      print("!!! Request path: ${e.requestOptions.path}");
      print("!!! Request headers: ${e.requestOptions.headers}");
      
      if (isFrozen) {
        throw Exception('Account is frozen.');
      }
      throw Exception(errorData?['error'] ?? e.message ?? 'Voice verification failed');
    } catch (e) {
      _setAuthStatus(isAuthenticated: false);
      print("!!! Login step 3 unexpected error: $e");
      throw Exception('An unexpected error occurred during voice verification.');
    }
  }

  void _setAuthStatus({
    required bool isAuthenticated,
    bool isAdmin = false,
    String? username,
    Map<String, dynamic>? userData,
  }) {
    if (_isAuthenticated == isAuthenticated && _isAdmin == isAdmin && _username == username) return;
    _isAuthenticated = isAuthenticated;
    if (!isAuthenticated) {
      _isAdmin = false;
      _username = null;
      _userData = null;
      _currentUser = null;
      _loginUsername = null;
      _sessionToken = null;
    } else {
      _isAdmin = isAdmin;
      _username = username;
      _loginUsername = username;
      _userData = userData;
      if (userData != null) {
        _currentUser = User.fromJson(userData);
      }
    }
    print("Auth Status Updated: isAuthenticated=$_isAuthenticated, isAdmin=$_isAdmin, username=$_username");
    notifyListeners();
  }
  
  // Logout
  Future<void> logout() async {
    await initializationComplete;
    final originalAuthState = _isAuthenticated;
    try {
      print(">>> Attempting logout POST...");
      await _dio.post('auth/logout/'); // Interceptor adds CSRF if available
      print(">>> Logout POST completed or ignored.");
    } catch (e) {
      print('Logout API call failed: $e');
    } finally {
      _setAuthStatus(isAuthenticated: false);
      _csrfToken = null; // Clear CSRF token on logout
      _currentUser = null;
      _loginUsername = null;
      _sessionToken = null;
      _authStateController.add(false);
      
      if (!kIsWeb && _cookieJar != null) {
        try {
          await _cookieJar!.deleteAll();
          print("Local cookies deleted (non-web).");
        } catch(cookieError) {
          print("Error deleting cookies (non-web): $cookieError");
        }
      } else {
        print("Skipping cookie deletion (Web or no CookieJar).");
      }
      print(">>> Local auth state cleared.");
    }
  }
  
  // Registration
  Future<User> register({
    required String username,
    required String password,
    required String email,
    required String phoneNumber,
    required String fullName,
    required Uint8List faceImage,
    required Uint8List voiceRecording,
    String? inviteToken,
    bool createCompany = false,
    String? companyName,
  }) async {
    await initializationComplete;
    if (_csrfToken == null) await fetchCsrfToken();
    print(">>> POST /auth/register/ (CSRF: ${_csrfToken != null})");
    
    try {
      // Create FormData for multipart request
      final formData = FormData.fromMap({
        'username': username,
        'password': password,
        'email': email,
        'phone_number': phoneNumber,
        'full_name': fullName,
        'create_company': createCompany.toString(),
      });
      
      // Add conditional fields
      if (inviteToken != null && inviteToken.isNotEmpty) {
        formData.fields.add(MapEntry('invite_token', inviteToken));
      }
      if (createCompany && companyName != null && companyName.isNotEmpty) {
        formData.fields.add(MapEntry('company_name', companyName));
      }
      
      // Add biometric data files
      formData.files.add(MapEntry(
        'face_image',
        MultipartFile.fromBytes(faceImage, filename: 'face.jpg'),
      ));
      
      formData.files.add(MapEntry(
        'voice_recording',
        MultipartFile.fromBytes(voiceRecording, filename: 'voice.wav'),
      ));
      
      // Send the registration request
      final response = await _dio.post(
        'auth/register/',
        data: formData,
        options: Options(
          headers: {
            'X-CSRFToken': _csrfToken,
          },
          contentType: Headers.multipartFormDataContentType,
          extra: {
            'withCredentials': true,
          }
        ),
      );
      
      if (response.statusCode == 201) {
        final userData = response.data['user'];
        final user = User.fromJson(userData);
        
        return user;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: response.data?['error'] ?? 'Registration failed'
        );
      }
    } on DioException catch (e) {
      if (e.response?.data is Map && e.response?.data['errors'] is Map) {
        // Format the field errors nicely
        final errors = e.response?.data['errors'] as Map;
        final errorMessages = errors.entries
            .map((entry) => "${entry.key}: ${entry.value.join(', ')}")
            .join('; ');
        throw Exception(errorMessages);
      }
      throw Exception(e.response?.data?['error'] ?? e.message ?? 'Registration failed');
    } catch (e) {
      throw Exception('An unexpected error occurred during registration: $e');
    }
  }
  
  // Token verification
  Future<Map<String, dynamic>> verifyToken(String token) async {
    await initializationComplete;
    if (_csrfToken == null) await fetchCsrfToken();
    print(">>> POST /auth/verify-token/ (CSRF: ${_csrfToken != null})");
    
    try {
      final response = await _dio.post(
        'auth/verify-token/',
        data: {'token': token},
        options: Options(
          headers: {
            'X-CSRFToken': _csrfToken,
          },
        ),
      );
      
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
      throw Exception(e.response?.data?['error'] ?? e.message ?? 'Token verification failed');
    } catch (e) {
      throw Exception('An unexpected error occurred during token verification: $e');
    }
  }

  // Room Access
  Future<Map<String, dynamic>> requestRoomAccess(String roomId) async {
    await initializationComplete;
    if (!_isAuthenticated) throw Exception("User not authenticated.");
    if (_csrfToken == null) {
      await fetchCsrfToken();
      if (_csrfToken == null) throw Exception("CSRF token required.");
    }
    print(">>> POST /rooms/access/request/ (CSRF: true)");
    try {
      final response = await _dio.post(
        'rooms/access/request/', 
        data: {'room_id': roomId},
        options: Options(
          headers: {
            'X-CSRFToken': _csrfToken,
          },
        ),
      );
      
      if (response.statusCode == 200) {
        // Store room access state
        _accessRoomId = roomId;
        _accessStep = 1;
        _remainingTime = response.data['remaining_time'] ?? 20; // Default 20 seconds
        
        return response.data;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: response.data?['error'] ?? 'Room access request failed'
        );
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data?['error'] ?? e.message ?? 'Requesting room access failed');
    }
  }

  Future<Map<String, dynamic>> roomFaceVerify(Uint8List faceImage) async {
    await initializationComplete;
    if (!_isAuthenticated) throw Exception("User not authenticated.");
    if (_csrfToken == null) {
      await fetchCsrfToken();
      if (_csrfToken == null) throw Exception("CSRF token required.");
    }
    print(">>> POST /rooms/access/face-verify/ (CSRF: true)");
    try {
      final formData = FormData.fromMap({
        'face_image': MultipartFile.fromBytes(faceImage, filename: 'face.jpg'),
        'room_id': _accessRoomId, // Add room ID to maintain context
      });
      
      final response = await _dio.post(
        'rooms/access/face-verify/',
        data: formData,
        options: Options(
          headers: {
            'X-CSRFToken': _csrfToken,
          },
          contentType: Headers.multipartFormDataContentType,
        )
      );
      
      if (response.statusCode == 200) {
        // Update room access state
        _accessStep = 2;
        _remainingTime = response.data['remaining_time'] ?? 30; // Default 30 seconds
        _challengeSentence = response.data['challenge_sentence'];
        
        return response.data;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: response.data?['error'] ?? 'Face verification failed'
        );
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data?['error'] ?? e.message ?? 'Face verification failed');
    }
  }

  Future<Map<String, dynamic>> roomVoiceVerify(Uint8List voiceRecording) async {
    await initializationComplete;
    if (!_isAuthenticated) throw Exception("User not authenticated.");
    if (_csrfToken == null) {
      await fetchCsrfToken();
      if (_csrfToken == null) throw Exception("CSRF token required.");
    }
    print(">>> POST /rooms/access/voice-verify/ (CSRF: true)");
    try {
      final formData = FormData.fromMap({
        'voice_recording': MultipartFile.fromBytes(voiceRecording, filename: 'voice.wav'),
        'room_id': _accessRoomId, // Add room ID to maintain context
        'challenge_sentence': _challengeSentence, // Include challenge sentence for verification
      });
      
      final response = await _dio.post(
        'rooms/access/voice-verify/',
        data: formData,
        options: Options(
          headers: {
            'X-CSRFToken': _csrfToken,
          },
          contentType: Headers.multipartFormDataContentType,
        )
      );
      
      if (response.statusCode == 200) {
        // Reset room access state
        _accessRoomId = null;
        _accessStep = 0;
        _challengeSentence = null;
        
        return response.data;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: response.data?['error'] ?? 'Voice verification failed'
        );
      }
    } on DioException catch (e) {
      final errorData = e.response?.data;
      final bool isFrozen = (errorData is Map && errorData['is_frozen'] == true);
      if (isFrozen) {
        _setAuthStatus(isAuthenticated: false);
        throw Exception('Account is frozen.');
      }
      throw Exception(errorData?['error'] ?? e.message ?? 'Voice verification failed');
    } catch (e) {
      throw Exception('An unexpected error occurred during voice verification: $e');
    }
  }

  Future<Map<String, dynamic>> getRoomStatus(String roomId) async {
  await initializationComplete;
  print(">>> GET /rooms/$roomId/status/");
  
  try {
    final response = await _dio.get('rooms/$roomId/status/');
    
    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: response.data?['error'] ?? 'Failed to get room status'
      );
    }
  } on DioException catch (e) {
    print("!!! Get Room Status Error: ${e.response?.statusCode} - ${e.response?.data}");
    throw Exception(e.response?.data?['error'] ?? e.message ?? 'Failed to get room status');
  }
}

// Get user's accessible rooms
Future<List<Map<String, dynamic>>> getUserRooms() async {
  await initializationComplete;
  if (!_isAuthenticated) throw Exception("User not authenticated.");
  
  try {
    final response = await _dio.get('user/rooms/');
    
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
        error: response.data?['error'] ?? 'Failed to get user rooms'
      );
    }
  } on DioException catch (e) {
    print("!!! Get User Rooms Error: ${e.response?.statusCode} - ${e.response?.data}");
    throw Exception(e.response?.data?['error'] ?? e.message ?? 'Failed to get user rooms');
  }
}
  
  // Debug login state
  void printLoginState() {
    print('=== Login State ===');
    print('Login Username: $_loginUsername');
    print('Login Step: $_loginStep');
    print('Remaining Time: $_remainingTime');
    print('Challenge Sentence: $_challengeSentence');
    print('CSRF Token: ${_csrfToken != null ? "${_csrfToken!.substring(0, 6)}..." : "NULL"}');
    print('Session Token: ${_sessionToken != null ? "${_sessionToken!.substring(0, 8)}..." : "NULL"}');
    print('==================');
  }
}