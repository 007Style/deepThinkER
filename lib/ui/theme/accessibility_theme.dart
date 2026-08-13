/// AccessibilityTheme — high-contrast ThemeData and font size scale map.
library accessibility_theme;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Font size scale
// ---------------------------------------------------------------------------

/// Maps font size scale labels to point sizes.
const Map<String, double> fontSizeScale = {
  'small': 12.0,
  'medium': 14.0,
  'large': 16.0,
  'xl': 20.0,
};

/// Returns the font size for [scale], defaulting to `14.0` (medium).
double fontSizeFor(String scale) => fontSizeScale[scale] ?? 14.0;

// ---------------------------------------------------------------------------
// High-contrast theme
// ---------------------------------------------------------------------------

/// High-contrast [ThemeData] suitable for users with visual impairments.
///
/// Uses pure black/white palette with increased text sizes and border weights.
ThemeData highContrastTheme({String fontSizeScaleKey = 'medium'}) {
  final baseFontSize = fontSizeFor(fontSizeScaleKey);

  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Colors.black,
    onPrimary: Colors.white,
    secondary: Colors.black,
    onSecondary: Colors.white,
    error: Color(0xFFCC0000),
    onError: Colors.white,
    surface: Colors.white,
    onSurface: Colors.black,
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    cardColor: Colors.white,
    dividerColor: Colors.black,
    textTheme: TextTheme(
      bodyMedium: TextStyle(fontSize: baseFontSize, color: Colors.black),
      bodySmall: TextStyle(
        fontSize: baseFontSize - 2,
        color: Colors.black,
      ),
      titleMedium: TextStyle(
        fontSize: baseFontSize + 2,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
      labelSmall: TextStyle(
        fontSize: baseFontSize - 2,
        color: Colors.black,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black, width: 3),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.black, width: 2),
      ),
    ),
    useMaterial3: true,
  );
}

/// Standard [ThemeData] with font scale applied.
ThemeData standardTheme({String fontSizeScaleKey = 'medium'}) {
  final baseFontSize = fontSizeFor(fontSizeScaleKey);

  return ThemeData(
    useMaterial3: true,
    textTheme: TextTheme(
      bodyMedium: TextStyle(fontSize: baseFontSize),
      bodySmall: TextStyle(fontSize: baseFontSize - 2),
      titleMedium: TextStyle(
        fontSize: baseFontSize + 2,
        fontWeight: FontWeight.bold,
      ),
      labelSmall: TextStyle(fontSize: baseFontSize - 2),
    ),
  );
}
