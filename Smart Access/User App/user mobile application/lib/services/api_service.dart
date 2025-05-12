// lib/services/api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/js_cookie_helper.dart';

class ApiService {
  // Base URL for API requests
  static const String baseUrl = 'http://localhost:8000/api';
  
  // HTTP client
  final http.Client _client = http.Client();
  
  // CSRF token for Django
  String? _csrfToken;
  
  // Getter for CSRF token (for debugging)
  String? get csrfToken => _csrfToken;
  
  // Headers
  Map<String, String> get headers {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
    };
    
    // Get CSRF token from browser cookies or cached value
    final browserCsrf = JsCookieHelper.getCsrfToken();
    if (browserCsrf != null) {
      _csrfToken = browserCsrf;
    }
    
    // Add CSRF token if available
    if (_csrfToken != null) {
      headers['X-CSRFToken'] = _csrfToken!;
    }
    
    return headers;
  }
  
  // Method to expose cookies for debugging
  Map<String, String> getCookieDebugInfo() {
    return JsCookieHelper.getAllCookies();
  }
  
  // Initialize API service (fetch CSRF token)
  Future<void> initialize() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/auth/csrf/'),
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _csrfToken = data['csrfToken'];
        print('Initialized CSRF token: $_csrfToken');
        
        // Log browser cookies for debugging
        JsCookieHelper.logCookies();
      } else {
        print('Failed to get CSRF token: ${response.statusCode}');
      }
    } catch (e) {
      print('Error initializing API service: $e');
    }
  }
  
  // Method to reset CSRF token
  Future<void> resetCsrf() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/auth/csrf/'),
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _csrfToken = data['csrfToken'];
        print('Refreshed CSRF token: $_csrfToken');
        
        // Log browser cookies for debugging
        JsCookieHelper.logCookies();
      } else {
        print('Failed to refresh CSRF token: ${response.statusCode}');
      }
    } catch (e) {
      print('Error refreshing CSRF: $e');
    }
  }
  
  // Helper to build URIs
  Uri buildUri(String path, [Map<String, dynamic>? queryParams]) {
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: queryParams?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }
  
  // Debug method to log all active cookies and session state
  void logSessionState() {
    print('====== Current Session State ======');
    print('CSRF Token: $_csrfToken');
    print('Browser Cookies:');
    JsCookieHelper.logCookies();
    print('==================================');
  }
  
  // GET request
  Future<http.Response> get(String path, {Map<String, dynamic>? queryParams}) async {
    final uri = buildUri(path, queryParams);
    print('GET request to: $uri');
    print('With headers: $headers');
    
    // Log session state before request
    if (kDebugMode) {
      print('Before GET request:');
      logSessionState();
    }
    
    final response = await _client.get(
      uri,
      headers: headers,
    );
    
    // Log response headers for debugging
    if (kDebugMode) {
      print('Response status: ${response.statusCode}');
      print('Response headers:');
      response.headers.forEach((key, value) {
        print('  $key: $value');
      });
    }
    
    // Log session state after request
    if (kDebugMode) {
      print('After GET request:');
      logSessionState();
    }
    
    return response;
  }
  
  // POST request
  Future<http.Response> post(String path, {Map<String, dynamic>? body}) async {
    final uri = buildUri(path);
    if (kDebugMode) {
      print('POST request to: $uri');
      print('With headers: $headers');
      if (body != null) {
        print('With body: $body');
      }
    }
    
    // Log session state before request
    if (kDebugMode) {
      print('Before POST request:');
      logSessionState();
    }
    
    final response = await _client.post(
      uri,
      headers: headers,
      body: body != null ? json.encode(body) : null,
    );
    
    // Log response headers for debugging
    if (kDebugMode) {
      print('Response status: ${response.statusCode}');
      print('Response headers:');
      response.headers.forEach((key, value) {
        print('  $key: $value');
      });
    }
    
    // Log session state after request
    if (kDebugMode) {
      print('After POST request:');
      logSessionState();
    }
    
    return response;
  }
  
  // POST multipart request
  Future<http.Response> postMultipart(String path, http.MultipartRequest request) async {
    // Add necessary headers for session persistence
    final requestHeaders = {...headers};
    
    // Remove content-type header as it will be set by MultipartRequest
    requestHeaders.remove('Content-Type');
    
    request.headers.addAll(requestHeaders);
    
    if (kDebugMode) {
      print('POST multipart request to: ${request.url}');
      print('With headers: ${request.headers}');
    }
    
    // Log session state before request
    if (kDebugMode) {
      print('Before multipart request:');
      logSessionState();
    }
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    // Log response headers for debugging
    if (kDebugMode) {
      print('Response status: ${response.statusCode}');
      print('Response headers:');
      response.headers.forEach((key, value) {
        print('  $key: $value');
      });
    }
    
    // Log session state after request
    if (kDebugMode) {
      print('After multipart request:');
      logSessionState();
    }
    
    return response;
  }
  
  // PUT request
  Future<http.Response> put(String path, {Map<String, dynamic>? body}) async {
    final uri = buildUri(path);
    
    // Log session state before request
    if (kDebugMode) {
      print('Before PUT request:');
      logSessionState();
    }
    
    final response = await _client.put(
      uri,
      headers: headers,
      body: body != null ? json.encode(body) : null,
    );
    
    // Log session state after request
    if (kDebugMode) {
      print('After PUT request:');
      logSessionState();
    }
    
    return response;
  }
  
  // DELETE request
  Future<http.Response> delete(String path) async {
    final uri = buildUri(path);
    
    // Log session state before request
    if (kDebugMode) {
      print('Before DELETE request:');
      logSessionState();
    }
    
    final response = await _client.delete(uri, headers: headers);
    
    // Log session state after request
    if (kDebugMode) {
      print('After DELETE request:');
      logSessionState();
    }
    
    return response;
  }
}