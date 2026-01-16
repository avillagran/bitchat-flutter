import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bitchat_colors.dart';
import 'bitchat_typography.dart';

/// Theme preference options for the app.
enum ThemePreference {
  system,
  light,
  dark,
}

/// Bitchat theme configuration combining colors and typography.
/// Provides complete ThemeData for both light and dark modes.
class BitchatTheme {
  BitchatTheme._();

  /// Creates a dark theme for Bitchat.
  static ThemeData get darkTheme {
    final colorScheme = BitchatColors.darkColorScheme;
    final textTheme = BitchatTypography.textThemeFor(colorScheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: BitchatColors.darkBackground,

      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: BitchatColors.darkBackground,
        foregroundColor: BitchatColors.darkOnBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: BitchatColors.darkPrimary,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: BitchatColors.darkBackground,
        ),
      ),

      // Input decoration for text fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BitchatColors.darkSurface,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: BitchatColors.darkOnSurface.withOpacity(0.5),
        ),
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: BitchatColors.darkPrimary,
        size: 24,
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        color: BitchatColors.darkPrimary.withOpacity(0.2),
        thickness: 1,
      ),

      // Bottom sheet theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: BitchatColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),

      // Card theme
      cardTheme: CardTheme(
        color: BitchatColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // List tile theme
      listTileTheme: ListTileThemeData(
        textColor: BitchatColors.darkOnSurface,
        iconColor: BitchatColors.darkPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),

      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BitchatColors.darkPrimary,
        ),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BitchatColors.darkPrimary,
          foregroundColor: BitchatColors.darkOnPrimary,
        ),
      ),

      // Icon button theme
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: BitchatColors.darkPrimary,
        ),
      ),
    );
  }

  /// Creates a light theme for Bitchat.
  static ThemeData get lightTheme {
    final colorScheme = BitchatColors.lightColorScheme;
    final textTheme = BitchatTypography.textThemeFor(colorScheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: BitchatColors.lightBackground,

      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: BitchatColors.lightBackground,
        foregroundColor: BitchatColors.lightOnBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: BitchatColors.lightPrimary,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: BitchatColors.lightBackground,
        ),
      ),

      // Input decoration for text fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BitchatColors.lightSurface,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: BitchatColors.lightOnSurface.withOpacity(0.5),
        ),
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: BitchatColors.lightPrimary,
        size: 24,
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        color: BitchatColors.lightPrimary.withOpacity(0.2),
        thickness: 1,
      ),

      // Bottom sheet theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: BitchatColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),

      // Card theme
      cardTheme: CardTheme(
        color: BitchatColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // List tile theme
      listTileTheme: ListTileThemeData(
        textColor: BitchatColors.lightOnSurface,
        iconColor: BitchatColors.lightPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),

      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BitchatColors.lightPrimary,
        ),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BitchatColors.lightPrimary,
          foregroundColor: BitchatColors.lightOnPrimary,
        ),
      ),

      // Icon button theme
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: BitchatColors.lightPrimary,
        ),
      ),
    );
  }

  /// Gets the theme for the given preference and platform brightness.
  static ThemeData themeFor(
      ThemePreference preference, Brightness platformBrightness) {
    switch (preference) {
      case ThemePreference.light:
        return lightTheme;
      case ThemePreference.dark:
        return darkTheme;
      case ThemePreference.system:
        return platformBrightness == Brightness.dark ? darkTheme : lightTheme;
    }
  }

  /// Detects if the current theme is dark based on background luminance.
  static bool isDarkTheme(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    return backgroundColor.red + backgroundColor.green + backgroundColor.blue <
        1.5 * 255;
  }
}
