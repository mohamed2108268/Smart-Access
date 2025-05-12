// lib/routes/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/login_face_verification_screen.dart';
import '../screens/login_voice_verification_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/room_access_screen.dart';
import '../screens/room_face_verification_screen.dart';
import '../screens/room_voice_verification_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/token_verification_screen.dart';
import '../services/auth_service.dart';

// Custom route observer for analytics
class AppRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    print('Route pushed: ${route.settings.name}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    print('Route popped: ${route.settings.name}');
  }
}

// Custom refresh listenable for auth state changes
class GoRouterAuthRefreshStream extends ChangeNotifier {
  GoRouterAuthRefreshStream(Stream<bool> stream) {
    notifyListeners();
    stream.listen((_) => notifyListeners());
  }
}

// Router configuration
final appRouter = GoRouter(
  observers: [AppRouteObserver()],
  initialLocation: '/',
  refreshListenable: GoRouterAuthRefreshStream(AuthService().authStateChanges),
  redirect: (BuildContext context, GoRouterState state) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isLoggedIn = authService.isAuthenticated;
    
    // If the user is logged in, redirect them from auth screens to dashboard
    if (isLoggedIn) {
      if (state.matchedLocation == '/' || 
          state.matchedLocation == '/login' || 
          state.matchedLocation.startsWith('/signup') || 
          state.matchedLocation.startsWith('/verify-token')) {
        return '/dashboard';
      }
    } else {
      // If the user is not logged in, redirect them from protected screens to home
      if (state.matchedLocation.startsWith('/dashboard') || 
          state.matchedLocation.startsWith('/room') || 
          state.matchedLocation == '/profile') {
        return '/';
      }
      
      // If trying to access signup directly, redirect to token verification first
      if (state.matchedLocation == '/signup' && 
          !state.uri.queryParameters.containsKey('token')) {
        return '/verify-token';
      }
    }
    
    // Allow the page to load normally
    return null;
  },
  routes: [
    // Public routes
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
      routes: [
        GoRoute(
          path: 'face-verification',
          name: 'login-face-verification',
          builder: (context, state) => const LoginFaceVerificationScreen(),
        ),
        GoRoute(
          path: 'voice-verification',
          name: 'login-voice-verification',
          builder: (context, state) => const LoginVoiceVerificationScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/signup',
      name: 'signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/verify-token',
      name: 'verify-token',
      builder: (context, state) {
        final params = state.uri.queryParameters;
        final token = params['token'];
        return TokenVerificationScreen(token: token);
      },
    ),
    
    // Protected routes
    GoRoute(
      path: '/dashboard',
      name: 'dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/room/:roomId',
      name: 'room-access',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId']!;
        return RoomAccessScreen(roomId: roomId);
      },
      routes: [
        GoRoute(
          path: 'face-verification',
          name: 'room-face-verification',
          builder: (context, state) {
            final roomId = state.pathParameters['roomId']!;
            return RoomFaceVerificationScreen(roomId: roomId);
          },
        ),
        GoRoute(
          path: 'voice-verification',
          name: 'room-voice-verification',
          builder: (context, state) {
            final roomId = state.pathParameters['roomId']!;
            return RoomVoiceVerificationScreen(roomId: roomId);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const UserProfileScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Not Found')),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Page Not Found',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'The requested page does not exist.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text('Go to Home'),
          ),
        ],
      ),
    ),
  ),
);