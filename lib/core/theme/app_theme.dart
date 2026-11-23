import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_font.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    // Was hardcoded 'Manrope' -- now reads the current pick from
    // Profile > Font Style (2026-11-20), same "read fresh on every
    // rebuild" pattern AppColors.accent already uses for App Theme.
    fontFamily: AppFonts.current.fontFamily,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
      primary: AppColors.accent,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
    ),
  );
}

/// Dark counterpart of [buildAppTheme]. Wired into `MaterialApp.darkTheme`
/// + `themeMode:` in app.dart, driven by `ThemeBloc` — this is what
/// makes the Profile screen's Dark Mode switch a real, app-wide toggle
/// instead of just a visual one.
ThemeData buildAppDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: AppFonts.current.fontFamily,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
      primary: AppColors.accent,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
    ),
  );
}
