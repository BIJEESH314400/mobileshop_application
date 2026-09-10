import 'package:flutter/material.dart';

/// Brand colors, matching the CellPoint design.
///
/// The `dark*` / `*Dark` constants below are prep for the "2 themes"
/// requirement — not wired into MaterialApp yet (that still needs a
/// `darkTheme:` + `themeMode:` on MobileShopApp, and ideally a saved
/// user preference). AppBottomNav already reads `Theme.of(context)
/// .brightness` and picks between the two sets, so once the app-wide
/// dark ThemeData lands, the bottom bar switches automatically with
/// zero changes here.
class AppColors {
  AppColors._();

  // Light theme (current default)
  static const accent = Color(0xFF4F5AED);
  static const background = Color(0xFFFAFAF9);
  static const card = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1C1C24);
  static const textSecondary = Color(0xFF6B6B76);
  static const border = Color(0xFFEDEDEC);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);

  // Dark theme (used today only by AppBottomNav's brightness check;
  // TODO: promote to a real ColorScheme.dark() once dual-theme lands)
  static const darkBackground = Color(0xFF0E0F13);
  static const darkCard = Color(0xFF15171D);
  static const darkBorder = Color(0xFF23262E);
  static const darkTextSecondary = Color(0xFF7C818B);
  static const accentGlow = Color(0xFF5B8DEF); // Home button glow, dark theme
  static const activeDark = Color(0xFF22D3EE); // active tab color, dark theme
}
