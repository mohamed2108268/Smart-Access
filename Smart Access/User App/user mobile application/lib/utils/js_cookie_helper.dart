// lib/utils/js_cookie_helper.dart
import 'dart:js' as js;
import 'dart:html' as html;

/// Helper class to interact with cookies in the browser directly using JavaScript
class JsCookieHelper {
  /// Get all cookies as a Map from the browser
  static Map<String, String> getAllCookies() {
    final cookieString = html.document.cookie ?? '';
    final Map<String, String> cookies = {};
    
    if (cookieString.isNotEmpty) {
      final cookieParts = cookieString.split(';');
      for (var part in cookieParts) {
        final keyValue = part.trim().split('=');
        if (keyValue.length == 2) {
          cookies[keyValue[0]] = keyValue[1];
        }
      }
    }
    
    return cookies;
  }
  
  /// Set a cookie in the browser
  static void setCookie(String name, String value, {int? maxAgeDays}) {
    String cookie = '$name=$value; path=/';
    
    if (maxAgeDays != null) {
      cookie += '; max-age=${maxAgeDays * 24 * 60 * 60}';
    }
    
    html.document.cookie = cookie;
  }
  
  /// Get a cookie value by name
  static String? getCookie(String name) {
    final cookies = getAllCookies();
    return cookies[name];
  }
  
  /// Delete a cookie by name
  static void deleteCookie(String name) {
    html.document.cookie = '$name=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT';
  }
  
  /// Get the session ID (Django's sessionid cookie)
  static String? getSessionId() {
    return getCookie('sessionid');
  }
  
  /// Get the CSRF token (Django's csrftoken cookie)
  static String? getCsrfToken() {
    return getCookie('csrftoken');
  }
  
  /// Log all cookies to console for debugging
  static void logCookies() {
    final cookies = getAllCookies();
    print('=== Browser Cookies ===');
    if (cookies.isEmpty) {
      print('No cookies found');
    } else {
      cookies.forEach((key, value) {
        print('$key: $value');
      });
    }
    print('=====================');
  }
}