import 'package:flutter/material.dart';

/// Per original spec §22: dark navy/charcoal, white text, red reserved for
/// emergency states only, green for safe/connected, amber for warnings.
/// Minimal animation, high contrast, no gradients, not "gamified".
class VigilanceColors {
  VigilanceColors._();
  static const navy = Color(0xFF0D1B2A);
  static const navySurface = Color(0xFF16263A);
  static const charcoal = Color(0xFF1B1F24);
  static const white = Color(0xFFF5F7FA);
  static const mutedWhite = Color(0xFFB8C1CC);
  static const safeGreen = Color(0xFF2E7D5B);
  static const warnAmber = Color(0xFFC98A2C);
  static const emergencyRed = Color(0xFFB3261E);
}

class VigilanceTheme {
  VigilanceTheme._();

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: VigilanceColors.navy,
      primaryColor: VigilanceColors.navySurface,
      colorScheme: const ColorScheme.dark(
        primary: VigilanceColors.navySurface,
        secondary: VigilanceColors.safeGreen,
        error: VigilanceColors.emergencyRed,
        surface: VigilanceColors.navySurface,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: VigilanceColors.white, fontWeight: FontWeight.w700, fontSize: 28),
        headlineMedium: TextStyle(color: VigilanceColors.white, fontWeight: FontWeight.w600, fontSize: 22),
        bodyLarge: TextStyle(color: VigilanceColors.white, fontSize: 16),
        bodyMedium: TextStyle(color: VigilanceColors.mutedWhite, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        color: VigilanceColors.navySurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: VigilanceColors.safeGreen,
          foregroundColor: VigilanceColors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: VigilanceColors.white,
          side: const BorderSide(color: VigilanceColors.mutedWhite),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VigilanceColors.navySurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: VigilanceColors.mutedWhite),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: VigilanceColors.navy,
        foregroundColor: VigilanceColors.white,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: VigilanceColors.navySurface,
        selectedItemColor: VigilanceColors.safeGreen,
        unselectedItemColor: VigilanceColors.mutedWhite,
      ),
      useMaterial3: true,
    );
  }

  /// Cloak Mode uses a visually distinct, neutral "notes app" palette — NOT
  /// the navy security theme — so it doesn't look like Vigilance at all.
  /// See screens/emergency/cloak_mode_screen.dart.
  static ThemeData get cloak {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFFFFDF7),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 20),
        bodyLarge: TextStyle(color: Colors.black87, fontSize: 16),
        bodyMedium: TextStyle(color: Colors.black54, fontSize: 13),
      ),
      useMaterial3: true,
    );
  }
}
