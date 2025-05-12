// lib/screens/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../widgets/fade_slide_transition.dart';
import 'admin/room_management_screen.dart';
import 'admin/access_logs_screen.dart';
import 'admin/user_permissions_screen.dart';
import 'admin/frozen_accounts_screen.dart';
import 'admin/invite_management_screen.dart';
import '../theme/theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<Widget> _screens = [
    const RoomManagementScreen(),
    const AccessLogsScreen(),
    const UserPermissionsScreen(),
    const FrozenAccountsScreen(),
    const InviteManagementScreen(),
  ];

  final List<String> _screenTitles = [
    'Room Management',
    'Access Logs',
    'Permissions Management',
    'Frozen Accounts',
    'Invite Management'
  ];

  final List<IconData> _screenIcons = [
    Icons.meeting_room,
    Icons.list_alt,
    Icons.people,
    Icons.lock,
    Icons.mail,
  ];

  final List<IconData> _outlinedIcons = [
    Icons.meeting_room_outlined,
    Icons.list_alt_outlined,
    Icons.people_outline,
    Icons.lock_outline,
    Icons.mail_outline,
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      _animationController.reverse().then((_) {
        setState(() {
          _selectedIndex = index;
        });
        _animationController.forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    // Redirect if not authenticated or not admin
    if (!authService.isAuthenticated || !authService.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Go to login or potentially a generic user dashboard if logged in but not admin
          context.go('/login');
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Use LayoutBuilder for responsiveness
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 800; // Wider breakpoint for admin

        return Scaffold(
          appBar: AppBar(
            backgroundColor: BioAccessTheme.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.admin_panel_settings, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'Admin Panel - ${_screenTitles[_selectedIndex]}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            actions: [
              // Status indicator
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'System Online',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // User info and logout
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.shield, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      authService.username ?? 'Admin',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await authService.logout();
                        if (mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout, size: 16),
                      label: const Text('Logout'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white.withOpacity(0.9),
                        side: BorderSide(color: Colors.white.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: Row(
            children: [
              // Show NavigationRail only on wider screens
              if (isDesktop)
                NavigationRail(
                  backgroundColor: BioAccessTheme.primaryBlue.withOpacity(0.95),
                  minExtendedWidth: 230,
                  extended: true,
                  elevation: 4,
                  destinations: List.generate(
                    _screenTitles.length,
                    (index) => NavigationRailDestination(
                      icon: Icon(_outlinedIcons[index]),
                      selectedIcon: Icon(_screenIcons[index]),
                      label: Text(_screenTitles[index]),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                  selectedIconTheme: const IconThemeData(
                    color: Colors.white,
                    size: 24,
                  ),
                  unselectedIconTheme: IconThemeData(
                    color: Colors.white.withOpacity(0.7),
                    size: 22,
                  ),
                  selectedLabelTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  unselectedLabelTextStyle: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                  useIndicator: true,
                  indicatorColor: Colors.white.withOpacity(0.15),
                  leading: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.security,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Smart-Access',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Security Console',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Divider(
                          color: Colors.white24,
                          thickness: 1,
                        ),
                        const SizedBox(height: 16),
                        // Help button
                        _buildNavRailButton(
                          icon: Icons.help_outline,
                          label: 'Help & Support',
                          onPressed: () {
                            // Show help dialog
                          },
                        ),
                        const SizedBox(height: 12),
                        // Settings button
                        _buildNavRailButton(
                          icon: Icons.settings_outlined,
                          label: 'Settings',
                          onPressed: () {
                            // Navigate to settings
                          },
                        ),
                      ],
                    ),
                  ),
                ),

              // Main content area
              Expanded(
                child: Container(
                  color: BioAccessTheme.backgroundColor,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: Align(
                        alignment: Alignment.topCenter,
                        key: ValueKey<int>(_selectedIndex),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Page header
                            Container(
                              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: BioAccessTheme.primaryBlue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _screenIcons[_selectedIndex],
                                      color: BioAccessTheme.primaryBlue,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _screenTitles[_selectedIndex],
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: BioAccessTheme.primaryBlue,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _getScreenDescription(_selectedIndex),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: BioAccessTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            // Screen content
                            Expanded(
                              child: _screens[_selectedIndex],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Show BottomNavigationBar only on narrower screens
          bottomNavigationBar: !isDesktop
              ? BottomNavigationBar(
                  backgroundColor: BioAccessTheme.primaryBlue,
                  selectedItemColor: Colors.white,
                  unselectedItemColor: Colors.white.withOpacity(0.6),
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _selectedIndex,
                  onTap: _onItemTapped,
                  elevation: 8,
                  selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  unselectedLabelStyle: const TextStyle(fontSize: 12),
                  items: List.generate(
                    _screenTitles.length,
                    (index) => BottomNavigationBarItem(
                      icon: Icon(_outlinedIcons[index]),
                      activeIcon: Icon(_screenIcons[index]),
                      label: _screenTitles[index],
                      backgroundColor: BioAccessTheme.primaryBlue,
                    ),
                  ),
                )
              : null, // No bottom bar on desktop
        );
      },
    );
  }

  // Helper method to build navigation rail buttons
  Widget _buildNavRailButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white.withOpacity(0.8),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get descriptions for each screen
  String _getScreenDescription(int index) {
    switch (index) {
      case 0:
        return 'Manage room access controls and security settings';
      case 1:
        return 'View detailed entry and exit logs for all access points';
      case 2:
        return 'Configure user permissions and access privileges';
      case 3:
        return 'Manage and restore frozen user accounts';
      case 4:
        return 'Create and manage invitation tokens for new users';
      default:
        return '';
    }
  }
}