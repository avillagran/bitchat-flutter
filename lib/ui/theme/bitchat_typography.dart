import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bitchat typography configuration using monospace fonts.
/// Matches Android implementation for cross-platform parity.
class BitchatTypography {
  BitchatTypography._();

  /// Base font size in logical pixels (matches Android 13sp for message content)
  static const double baseFontSize = 13.0;

  /// Maximum nickname length for display
  static const int maxNicknameLength = 15;

  /// Gets the base text style with Roboto Mono font.
  static TextStyle get _baseMonoStyle {
    try {
      return GoogleFonts.robotoMono();
    } catch (_) {
      // Fallback to system monospace if Google Fonts fails
      return const TextStyle(fontFamily: 'monospace');
    }
  }

  /// Creates a TextTheme with monospace styling for the given color scheme.
  static TextTheme textThemeFor(ColorScheme colorScheme) {
    final baseColor = colorScheme.onSurface;
    final base = _baseMonoStyle.copyWith(color: baseColor);

    return TextTheme(
      // Display styles (rarely used in chat)
      displayLarge: base.copyWith(
        fontSize: baseFontSize + 12,
        fontWeight: FontWeight.w400,
      ),
      displayMedium: base.copyWith(
        fontSize: baseFontSize + 8,
        fontWeight: FontWeight.w400,
      ),
      displaySmall: base.copyWith(
        fontSize: baseFontSize + 5,
        fontWeight: FontWeight.w400,
      ),

      // Headline styles
      headlineLarge: base.copyWith(
        fontSize: baseFontSize + 5,
        height: (baseFontSize + 11) / (baseFontSize + 5),
        fontWeight: FontWeight.w500,
      ),
      headlineMedium: base.copyWith(
        fontSize: baseFontSize + 4,
        height: (baseFontSize + 10) / (baseFontSize + 4),
        fontWeight: FontWeight.w500,
      ),
      headlineSmall: base.copyWith(
        fontSize: baseFontSize + 3, // 18sp
        height: (baseFontSize + 9) / (baseFontSize + 3), // 24sp line height
        fontWeight: FontWeight.w500,
      ),

      // Title styles
      titleLarge: base.copyWith(
        fontSize: baseFontSize + 3,
        height: (baseFontSize + 9) / (baseFontSize + 3),
        fontWeight: FontWeight.w500,
      ),
      titleMedium: base.copyWith(
        fontSize: baseFontSize + 1, // 16sp
        height: (baseFontSize + 7) / (baseFontSize + 1), // 22sp line height
        fontWeight: FontWeight.w500,
      ),
      titleSmall: base.copyWith(
        fontSize: baseFontSize,
        fontWeight: FontWeight.w500,
      ),

      // Body styles (main message content)
      bodyLarge: base.copyWith(
        fontSize: baseFontSize + 1, // 16sp
        height: (baseFontSize + 7) / (baseFontSize + 1), // 22sp line height
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: base.copyWith(
        fontSize: baseFontSize, // 15sp - main message text
        height: (baseFontSize + 3) / baseFontSize, // 18sp line height
        fontWeight: FontWeight.w400,
      ),
      bodySmall: base.copyWith(
        fontSize: baseFontSize - 3, // 12sp
        height: (baseFontSize + 1) / (baseFontSize - 3), // 16sp line height
        fontWeight: FontWeight.w400,
      ),

      // Label styles (timestamps, system messages)
      labelLarge: base.copyWith(
        fontSize: baseFontSize - 1,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: base.copyWith(
        fontSize: baseFontSize - 2, // 13sp - system messages
        height: (baseFontSize + 3) / (baseFontSize - 2),
        fontWeight: FontWeight.w500,
      ),
      labelSmall: base.copyWith(
        fontSize: baseFontSize - 4, // 11sp - timestamps
        height: (baseFontSize + 1) / (baseFontSize - 4),
        fontWeight: FontWeight.w400,
      ),
    );
  }

  // ==========================================================================
  // MESSAGE-SPECIFIC TEXT STYLES
  // ==========================================================================

  /// Text style for message content.
  static TextStyle messageContentStyle(ColorScheme colorScheme) {
    return _baseMonoStyle.copyWith(
      fontSize: baseFontSize,
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w400,
    );
  }

  /// Text style for message sender (nickname) - bold.
  static TextStyle senderNicknameStyle(Color color) {
    return _baseMonoStyle.copyWith(
      fontSize: baseFontSize,
      color: color,
      fontWeight: FontWeight.w500,
    );
  }

  /// Text style for self messages - bold.
  static TextStyle selfMessageStyle(Color color) {
    return _baseMonoStyle.copyWith(
      fontSize: baseFontSize,
      color: color,
      fontWeight: FontWeight.bold,
    );
  }

  /// Text style for message hash suffix (lighter).
  static TextStyle hashSuffixStyle(Color color) {
    return _baseMonoStyle.copyWith(
      fontSize: baseFontSize,
      color: color.withOpacity(0.6),
      fontWeight: FontWeight.w500,
    );
  }

  /// Text style for timestamps.
  static TextStyle timestampStyle(ColorScheme colorScheme) {
    return _baseMonoStyle.copyWith(
      fontSize: baseFontSize - 4, // 11sp
      color: colorScheme.onSurface.withOpacity(0.7),
      fontWeight: FontWeight.w400,
    );
  }

  /// Text style for system messages.
  static TextStyle systemMessageStyle(ColorScheme colorScheme) {
    return _baseMonoStyle.copyWith(
      fontSize: baseFontSize - 2, // 13sp
      color: colorScheme.onSurface.withOpacity(0.5),
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.italic,
    );
  }
}
