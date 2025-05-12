// lib/widgets/cookie_debug_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'dart:html' as html;

class CookieDebugView extends StatefulWidget {
  const CookieDebugView({Key? key}) : super(key: key);

  @override
  State<CookieDebugView> createState() => _CookieDebugViewState();
}

class _CookieDebugViewState extends State<CookieDebugView> {
  String _cookieData = 'Loading...';
  String _sessionInfo = 'Loading...';
  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _updateDebugInfo();
  }

  void _updateDebugInfo() {
    // Get current cookies
    setState(() {
      _cookieData = html.document.cookie ?? 'No cookies found';
      
      // Get auth service info
      final isAuth = _authService.isAuthenticated;
      final csrfToken = _authService.csrfToken;
      final username = _authService.username;
      final loginStep = _authService.loginStep;
      
      _sessionInfo = '''
Authentication State:
- Is Authenticated: $isAuth
- CSRF Token: ${csrfToken != null ? "${csrfToken.substring(0, 6)}..." : "NULL"}
- Username: $username
- Login Step: $loginStep
      ''';
    });
  }

  Future<void> _fetchCsrfToken() async {
    try {
      await _authService.fetchCsrfToken();
      _updateDebugInfo();
    } catch (e) {
      setState(() {
        _sessionInfo += '\nError fetching CSRF token: $e';
      });
    }
  }

  Future<void> _checkProfile() async {
    try {
      final dio = _authService.dioInstance;
      final response = await dio.get('user/profile/');
      setState(() {
        _sessionInfo += '\n\nProfile Check Response: ${response.statusCode}';
        _sessionInfo += '\nProfile Data: ${response.data}';
      });
    } catch (e) {
      setState(() {
        _sessionInfo += '\n\nProfile Check Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Debug Session Info'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Browser Cookies:', style: TextStyle(fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4.0),
              ),
              width: double.infinity,
              child: Text(_cookieData, style: const TextStyle(fontFamily: 'monospace')),
            ),
            const SizedBox(height: 16.0),
            const Text('Session State:', style: TextStyle(fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4.0),
              ),
              width: double.infinity,
              child: Text(_sessionInfo, style: const TextStyle(fontFamily: 'monospace')),
            ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _fetchCsrfToken,
                  child: const Text('Fetch CSRF'),
                ),
                ElevatedButton(
                  onPressed: _checkProfile,
                  child: const Text('Check Profile'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () {
            _updateDebugInfo();
          },
          child: const Text('Refresh'),
        ),
      ],
    );
  }
}