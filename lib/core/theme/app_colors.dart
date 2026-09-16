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

  // Two-tone status badges (dark text on a light tint) — used for
  // "Low Stock" / "In Progress" style pills, matching the CellPoint
  // design canvas. `warning` above stays as the single mid-tone for
  // anywhere a flat color (not a badge pair) is needed.
  static const warningText = Color(0xFF92400E);
  static const warningBg = Color(0xFFFEF3C7);
  static const successBg = Color(0xFFDCFCE7);
  static const dangerBg = Color(0xFFFEE2E2);

  // Light-lavender tint square behind a product/cart-item icon (Products,
  // Sales). Matches the design canvas exactly; kept fixed in both themes,
  // same as the other brand/status tint pairs above.
  static const iconTint = Color(0xFFF4F4FE);

  // Dark theme (used today only by AppBottomNav's brightness check;
  // TODO: promote to a real ColorScheme.dark() once dual-theme lands)
  static const darkBackground = Color(0xFF0E0F13);
  static const darkCard = Color(0xFF15171D);
  static const darkBorder = Color(0xFF23262E);
  static const darkTextPrimary = Color(0xFFF2F2F5);
  static const darkTextSecondary = Color(0xFF7C818B);
  static const accentGlow = Color(0xFF5B8DEF); // Home button glow, dark theme
  static const activeDark = Color(0xFF22D3EE); // active tab color, dark theme
}
