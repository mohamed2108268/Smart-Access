// lib/routes/admin_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

// Admin Screens
import '../screens/admin_login_screen.dart';
import '../screens/admin_signup_screen.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/admin/invite_management_screen.dart';

// Create a function to get the router with auth service
GoRouter getAdminRouter(AuthService authService) {
  return GoRouter(
    refreshListenable: authService, // Refresh routes when auth state changes
    initialLocation: '/login',
    redirect: (context, state) {
      final bool isLoggedIn = authService.isAuthenticated;
      final bool isAdmin = authService.isAdmin;
      
      // Use state.matchedLocation or state.uri.path instead of state.location
      final String currentPath = state.uri.path;
      final bool isLoginRoute = currentPath == '/login';
      final bool isSignupRoute = currentPath == '/admin-signup';
      final bool isAdminRoute = currentPath.startsWith('/admin/');
      
      // If not logged in and trying to access protected route, redirect to login
      if (!isLoggedIn && (isAdminRoute || currentPath == '/admin-dashboard')) {
        return '/login';
      }
      
      // If logged in but not admin and trying to access admin route, redirect to login
      if (isLoggedIn && !isAdmin && (isAdminRoute || currentPath == '/admin-dashboard')) {
        return '/login';
      }
      
      // If logged in as admin and trying to access login/signup, redirect to dashboard
      if (isLoggedIn && isAdmin && (isLoginRoute || isSignupRoute)) {
        return '/admin-dashboard';
      }
      
      // Allow the user to proceed
      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: '/admin-signup',
        builder: (context, state) => const AdminSignupScreen(),
      ),
      
      // Admin dashboard
      GoRoute(
        path: '/admin-dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      
      // Admin feature routes
      GoRoute(
        path: '/admin/invites',
        builder: (context, state) => const InviteManagementScreen(),
      ),
      // Add other admin routes here as needed
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Route not found: ${state.uri.path}'),
      ),
    ),
  );
}