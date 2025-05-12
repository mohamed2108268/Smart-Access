// --- START OF FILE theme/theme.dart ---
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BioAccessTheme {
  // Define Core Colors based on provided palette
  // Keeping primaryBlue name to maintain compatibility with existing code
  static const primaryBlue = Color(0xFF2E5266); // Deep teal as primary color
  static const lightBlue = Color(0xFF6E8898); // Medium slate blue as secondary
  static const accentGold = Color(0xFF9FB1BC); // Light blue-gray as tertiary/accent 
  static const darkGold = Color(0xFFD3D0CB); // Light beige/sand as neutral

  // Derived colors for UI elements
  static const textOnPrimary = Colors.white;
  static const textOnSurface = Color(0xFF2C3E50); // Dark blue-gray for text
  static const textSecondary = Color(0xFF546E7A); // Medium gray for secondary text
  static const surfaceColor = Colors.white;
  static const backgroundColor = Color(0xFFF5F7F9); // Very light blue-gray background
  static const errorColor = Color(0xFFE53935); // Slightly muted red for errors
  static const successColor = Color(0xFF43A047); // Slightly muted green for success

  // Light Theme Definition
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryBlue,
    scaffoldBackgroundColor: backgroundColor,

    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      primary: primaryBlue,
      secondary: lightBlue,
      tertiary: accentGold,
      background: backgroundColor,
      surface: surfaceColor,
      onSurface: textOnSurface,
      onPrimary: textOnPrimary,
      onSecondary: textOnPrimary,
      onTertiary: textOnSurface,
      error: errorColor,
      onError: Colors.white,
      brightness: Brightness.light,
    ),

    textTheme: GoogleFonts.interTextTheme(
      ThemeData.light().textTheme.copyWith(
            // Headlines
            displayLarge: const TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
            displayMedium: const TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
            displaySmall: const TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
            headlineLarge: const TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
            headlineMedium: const TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
            headlineSmall: const TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
            // Titles
            titleLarge: const TextStyle(color: textOnSurface, fontWeight: FontWeight.w600),
            titleMedium: const TextStyle(color: textOnSurface),
            titleSmall: const TextStyle(color: textOnSurface),
            // Body Text
            bodyLarge: const TextStyle(color: textOnSurface),
            bodyMedium: const TextStyle(color: textSecondary),
            bodySmall: const TextStyle(color: textSecondary),
            // Labels
            labelLarge: const TextStyle(color: textOnPrimary, fontWeight: FontWeight.w500),
            labelMedium: const TextStyle(color: textOnSurface),
            labelSmall: const TextStyle(color: textSecondary),
          ),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: primaryBlue,
      foregroundColor: textOnPrimary,
      elevation: 0,
      iconTheme: IconThemeData(color: textOnPrimary),
      actionsIconTheme: IconThemeData(color: textOnPrimary),
      titleTextStyle: TextStyle(
         fontFamily: 'Inter',
         fontSize: 20,
         fontWeight: FontWeight.w600,
         color: textOnPrimary
      )
    ),

    navigationRailTheme: NavigationRailThemeData(
        backgroundColor: primaryBlue.withOpacity(0.95),
        indicatorColor: accentGold.withOpacity(0.3),
        selectedIconTheme: const IconThemeData(color: Colors.white),
        unselectedIconTheme: IconThemeData(color: Colors.white.withOpacity(0.7)),
        selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        labelType: NavigationRailLabelType.all,
        elevation: 4,
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: primaryBlue,
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white.withOpacity(0.7),
      selectedIconTheme: const IconThemeData(size: 24),
      unselectedIconTheme: const IconThemeData(size: 22),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    cardTheme: CardTheme(
      elevation: 2,
      color: surfaceColor,
      shadowColor: lightBlue.withOpacity(0.3),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: darkGold.withOpacity(0.5), width: 0.5),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: textOnPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        elevation: 2,
        shadowColor: primaryBlue.withOpacity(0.4),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryBlue,
        side: const BorderSide(color: primaryBlue, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: lightBlue,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkGold.withOpacity(0.15),
      hintStyle: TextStyle(color: textSecondary.withOpacity(0.7)),
      prefixIconColor: lightBlue,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: darkGold, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: darkGold, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: errorColor, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: errorColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: accentGold.withOpacity(0.2),
      labelStyle: TextStyle(color: textOnSurface.withOpacity(0.8)),
      iconTheme: const IconThemeData(color: lightBlue, size: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(color: accentGold.withOpacity(0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accentGold,
      foregroundColor: textOnSurface,
      elevation: 4,
      shape: CircleBorder(),
    ),

    dialogTheme: DialogTheme(
      backgroundColor: surfaceColor,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: const TextStyle(color: primaryBlue, fontSize: 20, fontWeight: FontWeight.bold),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: textOnSurface.withOpacity(0.9),
      contentTextStyle: const TextStyle(color: Colors.white),
      actionTextColor: accentGold,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
      elevation: 4,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryBlue,
      linearTrackColor: accentGold,
      circularTrackColor: accentGold,
    ),

    tabBarTheme: const TabBarTheme(
      indicatorColor: primaryBlue,
      labelColor: primaryBlue,
      unselectedLabelColor: textSecondary,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: TextStyle(fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: lightBlue.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
    ),

    dividerTheme: DividerThemeData(
      color: darkGold.withOpacity(0.6),
      thickness: 1,
      space: 1,
    ),
    
    // Specific customization for admin panel
    iconTheme: const IconThemeData(
      color: primaryBlue,
      size: 24,
    ),
  );
}
// --- END OF FILE theme/theme.dart ---