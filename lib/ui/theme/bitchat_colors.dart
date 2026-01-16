import 'package:flutter/material.dart';

/// Bitchat color scheme for terminal/IRC-style UI.
/// Matches Android implementation for cross-platform parity.
class BitchatColors {
  BitchatColors._();

  // ==========================================================================
  // DARK MODE COLORS (Primary theme - terminal-like)
  // ==========================================================================

  /// Primary green - terminal style (#39FF14)
  static const Color darkPrimary = Color(0xFF39FF14);

  /// On primary - black text on green
  static const Color darkOnPrimary = Color(0xFF000000);

  /// Secondary green - slightly darker (#2ECB10)
  static const Color darkSecondary = Color(0xFF2ECB10);

  /// Background - pure black (#000000)
  static const Color darkBackground = Color(0xFF000000);

  /// On background - green text on black
  static const Color darkOnBackground = Color(0xFF39FF14);

  /// Surface - very dark gray (#111111)
  static const Color darkSurface = Color(0xFF111111);

  /// On surface - green text
  static const Color darkOnSurface = Color(0xFF39FF14);

  /// Error - red (#FF5555)
  static const Color darkError = Color(0xFFFF5555);

  /// On error - black
  static const Color darkOnError = Color(0xFF000000);

  // ==========================================================================
  // LIGHT MODE COLORS
  // ==========================================================================

  /// Primary green - dark green (#008000)
  static const Color lightPrimary = Color(0xFF008000);

  /// On primary - white text on green
  static const Color lightOnPrimary = Color(0xFFFFFFFF);

  /// Secondary green - darker (#006600)
  static const Color lightSecondary = Color(0xFF006600);

  /// Background - pure white (#FFFFFF)
  static const Color lightBackground = Color(0xFFFFFFFF);

  /// On background - dark green text on white
  static const Color lightOnBackground = Color(0xFF008000);

  /// Surface - very light gray (#F8F8F8)
  static const Color lightSurface = Color(0xFFF8F8F8);

  /// On surface - dark green text
  static const Color lightOnSurface = Color(0xFF008000);

  /// Error - dark red (#CC0000)
  static const Color lightError = Color(0xFFCC0000);

  /// On error - white
  static const Color lightOnError = Color(0xFFFFFFFF);

  // ==========================================================================
  // SPECIAL UI COLORS (iOS-style, shared between themes)
  // ==========================================================================

  /// Self message color - iOS orange (#FF9500)
  static const Color selfMessageColor = Color(0xFFFF9500);

  /// Link/URL color - iOS blue (#007AFF)
  static const Color linkColor = Color(0xFF007AFF);

  /// Geohash link color - iOS blue with underline
  static const Color geohashLinkColor = Color(0xFF007AFF);

  /// iOS green for dark mode (#32D74B)
  static const Color iosGreenDark = Color(0xFF32D74B);

  /// iOS green for light mode (#248A3D)
  static const Color iosGreenLight = Color(0xFF248A3D);

  /// Scroll button border - green accent (#00C851)
  static const Color scrollButtonBorder = Color(0xFF00C851);

  /// Primary green - main app color (#00C851)
  static const Color primaryGreen = Color(0xFF00C851);

  /// iOS blue for mesh channel (#007AFF)
  static const Color meshBlue = Color(0xFF007AFF);

  /// Green for location/geohash channels (#00C851)
  static const Color locationGreen = Color(0xFF00C851);

  /// Gold color for favorites (#FFD700)
  static const Color favoriteGold = Color(0xFFFFD700);

  // ==========================================================================
  // RSSI SIGNAL STRENGTH COLORS
  // ==========================================================================

  /// Excellent signal (>= -50 dBm) - bright green
  static const Color rssiExcellent = Color(0xFF00FF00);

  /// Good signal (>= -60 dBm) - green-yellow
  static const Color rssiGood = Color(0xFF80FF00);

  /// Fair signal (>= -70 dBm) - yellow
  static const Color rssiFair = Color(0xFFFFFF00);

  /// Weak signal (>= -80 dBm) - orange
  static const Color rssiWeak = Color(0xFFFF8000);

  /// Poor signal (< -80 dBm) - red
  static const Color rssiPoor = Color(0xFFFF4444);

  /// Gets the appropriate color for the given RSSI value.
  static Color colorForRssi(int rssi) {
    if (rssi >= -50) return rssiExcellent;
    if (rssi >= -60) return rssiGood;
    if (rssi >= -70) return rssiFair;
    if (rssi >= -80) return rssiWeak;
    return rssiPoor;
  }

  // ==========================================================================
  // COLOR SCHEMES
  // ==========================================================================

  /// Dark mode color scheme
  static ColorScheme get darkColorScheme => const ColorScheme(
        brightness: Brightness.dark,
        primary: darkPrimary,
        onPrimary: darkOnPrimary,
        secondary: darkSecondary,
        onSecondary: darkOnPrimary,
        error: darkError,
        onError: darkOnError,
        background: darkBackground,
        onBackground: darkOnBackground,
        surface: darkSurface,
        onSurface: darkOnSurface,
        surfaceVariant: Color(0xFF0F0F0F),
        onSurfaceVariant: darkOnSurface,
      );

  /// Light mode color scheme
  static ColorScheme get lightColorScheme => const ColorScheme(
        brightness: Brightness.light,
        primary: lightPrimary,
        onPrimary: lightOnPrimary,
        secondary: lightSecondary,
        onSecondary: lightOnPrimary,
        error: lightError,
        onError: lightOnError,
        background: lightBackground,
        onBackground: lightOnBackground,
        surface: lightSurface,
        onSurface: lightOnSurface,
        surfaceVariant: Color(0xFFF0F0F0),
        onSurfaceVariant: lightOnSurface,
      );

  /// Gets the appropriate color scheme for the given brightness.
  static ColorScheme colorSchemeFor(Brightness brightness) {
    return brightness == Brightness.dark ? darkColorScheme : lightColorScheme;
  }
}
