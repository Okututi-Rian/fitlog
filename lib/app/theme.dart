import 'package:flutter/material.dart';

/// The one seed color the whole app is built from. Material 3 derives the full
/// light and dark palettes from it (docs/ARCHITECTURE.md section 12).
const Color kSeedColor = Color(0xFF2E7D32);

/// Light theme.
final ThemeData lightTheme = _themeFor(Brightness.light);

/// Dark theme.
final ThemeData darkTheme = _themeFor(Brightness.dark);

ThemeData _themeFor(Brightness brightness) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kSeedColor,
      brightness: brightness,
    ),
  );
}
