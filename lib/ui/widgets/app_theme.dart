// App-wide dark theme for deepThink.
//
// Exposes [AppTheme.darkTheme] for MaterialApp and [AppColors] for any widget
// that needs the palette without a BuildContext.
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// AppColors
// ---------------------------------------------------------------------------

/// Named colour constants for the deepThink dark sci-fi palette.
class AppColors {
  AppColors._();

  /// Near-black window background with a faint blue tint.
  static const Color background = Color(0xFF0A0A0F);

  /// Slightly lighter surface (drawers, overlays).
  static const Color surface = Color(0xFF12121A);

  /// Card / panel background.
  static const Color card = Color(0xFF1A1A27);

  /// Subtle border / divider colour.
  static const Color border = Color(0xFF2A2A3D);

  /// Primary body text.
  static const Color textPrimary = Color(0xFFE8E8F0);

  /// Secondary / muted text.
  static const Color textSecondary = Color(0xFF8888AA);

  /// Accent blue — interactive elements, highlights.
  static const Color accent = Color(0xFF4A9EFF);

  /// Status-band / footer background.
  static const Color statusBackground = Color(0xFF0D0D15);

  // Character colours (match OrbConfig primaries).
  static const Color watsonBlue = Color(0xFF1E90FF);
  static const Color deepPurple = Color(0xFF7B2FBE);
  static const Color novaOrange = Color(0xFFFF6B00);
  static const Color sageRed = Color(0xFFDC143C);
}

// ---------------------------------------------------------------------------
// AppTheme
// ---------------------------------------------------------------------------

/// Provides the [MaterialApp] dark [ThemeData] for deepThink.
class AppTheme {
  AppTheme._();

  /// Full dark [ThemeData] — pass to [MaterialApp.theme].
  static ThemeData get darkTheme {
    const textColor = AppColors.textPrimary;
    const mutedColor = AppColors.textSecondary;

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.accent,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.deepPurple,
        surface: AppColors.surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textColor,
      ),
      cardColor: AppColors.card,
      dividerColor: AppColors.border,
      // Text theme
      textTheme: const TextTheme(
        // Header — character names
        headlineLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0.4,
        ),
        headlineSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0.3,
        ),
        // Body
        bodyLarge: TextStyle(fontSize: 14, color: textColor, height: 1.55),
        bodyMedium: TextStyle(fontSize: 13, color: textColor, height: 1.5),
        bodySmall: TextStyle(fontSize: 11, color: mutedColor, height: 1.4),
        // Labels / badges
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: mutedColor,
          letterSpacing: 0.6,
        ),
      ),
      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
        ),
        hintStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    );
  }
}
