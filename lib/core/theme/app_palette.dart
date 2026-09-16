import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Centralized light/dark color lookup, shared by every screen so the
/// whole app — not just one screen — responds to `ThemeBloc`'s mode.
///
/// Get one with `AppPalette.of(context)` at the top of `build()`, then
/// use `p.background`/`p.card`/`p.textPrimary`/etc. instead of
/// reaching for the `AppColors.x` light constants directly. This was
/// pulled out of what started as a private `_Palette` class inside
/// profile_screen.dart (the first screen made theme-aware) once a
/// second screen needed the same thing — see the project status doc.
///
/// Deliberately NOT applied to SplashScreen: that screen is a solid
/// brand-accent background with white content regardless of theme
/// (matches the design canvas's Splash artboard, which has no dark
/// variant), so it stays as-is on purpose.
class AppPalette {
  final bool isDark;
  const AppPalette(this.isDark);

  factory AppPalette.of(BuildContext context) =>
      AppPalette(Theme.of(context).brightness == Brightness.dark);

  Color get background => isDark ? AppColors.darkBackground : AppColors.background;
  Color get card => isDark ? AppColors.darkCard : AppColors.card;
  Color get border => isDark ? AppColors.darkBorder : AppColors.border;
  Color get divider => isDark ? AppColors.darkBorder : const Color(0xFFF2F2F1);
  Color get textPrimary => isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
  Color get textSecondary => isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

  // Input fields (Login) sit on a filled box one shade off the page
  // background in both themes — darkCard reads as "raised" on
  // darkBackground the same way the light background does on white.
  Color get inputFill => isDark ? AppColors.darkCard : AppColors.background;

  // The light theme's Log Out card uses a pale red border (#FEE2E2)
  // which would barely show on a dark card, so dark mode uses a
  // translucent version of the solid danger red instead.
  Color get dangerBorder => isDark ? AppColors.danger.withOpacity(0.35) : AppColors.dangerBg;
}
