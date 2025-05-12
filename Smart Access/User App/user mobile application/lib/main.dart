// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/room_service.dart';
import 'routes/router.dart';
import 'theme/theme.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set URL strategy for cleaner URLs
  setUrlStrategy(PathUrlStrategy());
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Create the auth service
  final authService = AuthService();
  
  // Wait for the auth service to initialize (cookie jar, etc.)
  await authService.initializationComplete;
  
  // Create room service - FIX: use positional parameter instead of named
  final roomService = RoomService(authService);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: authService),
        // FIX: Also provide the roomService directly 
        ChangeNotifierProvider<RoomService>.value(value: roomService),
        // We don't need the proxy provider since we're providing the RoomService directly
      ],
      child: const BioAccessApp(),
    ),
  );
}

class BioAccessApp extends StatelessWidget {
  const BioAccessApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Smart Access',
      theme: BioAccessTheme.lightTheme,
      darkTheme: BioAccessTheme.darkTheme,
      themeMode: ThemeMode.system, // Respect system theme
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}