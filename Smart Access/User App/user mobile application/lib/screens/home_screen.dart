// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../theme/theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Stack(
        children: [
          const AnimatedBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(BioAccessTheme.paddingLarge),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo and branding
                      Hero(
                        tag: 'app-logo',
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: const BoxDecoration(
                            color: BioAccessTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.fingerprint,
                            size: 72,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: BioAccessTheme.paddingLarge),
                      
                      // App name and tagline
                      const Text(
                        'Smart Access',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: BioAccessTheme.paddingSmall),
                      const Text(
                        ' ',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: BioAccessTheme.paddingXL),
                      
                      // Main content card
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Title
                            Text(
                              'Welcome',
                              style: Theme.of(context).textTheme.headlineMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: BioAccessTheme.paddingMedium),
                            
                            // Description
                            Text(
                              'Access Your Rooms',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: BioAccessTheme.paddingLarge),
                            
                            // Login button
                            ElevatedButton.icon(
                              onPressed: () => context.go('/login'),
                              icon: const Icon(Icons.login),
                              label: const Text('Login'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                            const SizedBox(height: BioAccessTheme.paddingMedium),
                            
                            // Have an invite button
                            OutlinedButton.icon(
                              onPressed: () => context.go('/verify-token'),
                              icon: const Icon(Icons.vpn_key),
                              label: const Text('I Have an Invitation'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                            const SizedBox(height: BioAccessTheme.paddingMedium),
                          ],
                        ),
                      ),
                      
                      // Footer
                      const SizedBox(height: BioAccessTheme.paddingLarge),
                      const Text(
                        '© 2025 Smart Access, MIU University.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}