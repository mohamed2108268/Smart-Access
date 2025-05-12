// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'routes/admin_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Create auth service instance
  final authService = AuthService();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => authService,
      child: BioAccessAdminApp(authService: authService),
    ),
  );
}

class BioAccessAdminApp extends StatelessWidget {
  final AuthService authService;
  
  const BioAccessAdminApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    // Create the admin router using the authService
    final router = getAdminRouter(authService);
    
    return MaterialApp.router(
      title: 'BioAccess Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue,
          secondary: Colors.amber,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        cardTheme: CardTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      routerConfig: router, // Use the created admin router
    );
  }
}