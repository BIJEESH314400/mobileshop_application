import 'package:flutter/material.dart';

/// Brand colors, matching the CellPoint design.
///
/// Dark mode IS wired into MaterialApp (ThemeBloc + app.dart) — the
/// `dark*` / `*Dark` constants below are its dark-mode set, consumed
/// via AppPalette rather than directly in most places.
class AppColors {
  AppColors._();

  // `accent` is deliberately NOT `const` (2026-10-22, "6 app themes"
  // feature) -- it's the one color that changes when the user picks a
  // theme in Profile > App Theme. Every other color below stays a
  // fixed `const`; this is the sole runtime-mutable one. Set from the
  // saved preference before runApp() (see main.dart) and again
  // whenever ThemeBloc handles a ThemeColorChanged event, so every
  // `AppColors.accent` read anywhere in the app reflects the current
  // choice the next time that widget rebuilds -- which (via
  // AppPalette.of(context)/Theme.of(context) already being called in
  // the same build() almost everywhere this app styles a screen) is
  // immediate, the same way the light/dark toggle already propagates
  // app-wide with zero per-screen wiring.
  static Color accent = const Color(0xFF4F5AED);

  // Light theme (current default)
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

  // Added for the Malayalam-voice-to-English note feature (2026-10-19)
  // -- when a voice note is spoken in Malayalam, the original words
  // and their English translation both go into the same field, each
  // colored so they stay easy to tell apart at a glance.
  static const voiceMalayalam = Color(0xFF8B1E1E); // dark red
  static const voiceEnglish = Color(0xFF1B3A6B); // dark blue

  // Added for Add Customer's section badges/icons (2026-09-25) --
  // "READY" (blue) and "B2B VERIFIED" (purple) needed colors outside
  // the success/warning/danger set above, kept fixed in both themes
  // same as the rest of this bg/solid-color pair family.
  static const info = Color(0xFF2563EB);
  static const infoBg = Color(0xFFDBEAFE);
  static const purple = Color(0xFF7C3AED);
  static const purpleBg = Color(0xFFEDE9FE);

  // Added for the Customers list's order-count pill (2026-10-06) --
  // a neutral grey for customers with 0 orders, matching the same
  // bg/solid-color pair pattern as the other status badges above.
  static const neutralText = Color(0xFF6B7280);
  static const neutralBg = Color(0xFFF3F4F6);

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
