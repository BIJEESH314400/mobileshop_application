import 'package:flutter/material.dart';

/// One of the 5 selectable app-wide fonts (Profile > Font Style), added
/// 2026-11-20. Independent of App Theme (accent color) and Dark Mode --
/// this only changes the font family read by `ThemeData.fontFamily`
/// (see buildAppTheme()/buildAppDarkTheme()); every other style
/// (colors, spacing, icons) stays exactly what it already was.
///
/// `manrope` is the app's original font (bundled as
/// assets/fonts/Manrope-Variable.ttf since before this feature) --
/// kept as the actual runtime default (see [AppFonts.current] and
/// [fromId]'s `orElse`) so nothing changes for anyone who never opens
/// the picker, even though `systemDefault` is listed first in the UI.
///
/// Inter, DM Sans, and Outfit are bundled the same way Manrope already
/// was: one official, free, OFL-licensed variable `.ttf` file per
/// family (each covers every weight via its own weight axis, declared
/// in pubspec.yaml exactly like Manrope's single file already is) --
/// not Google's online font-loading package, so none of these ever
/// need an internet connection to display, on any screen, at any time.
///
/// `systemDefault` deliberately has a null [fontFamily] -- passing
/// null to `ThemeData.fontFamily` makes Flutter fall back to the
/// platform's own default (Roboto on Android, San Francisco on iOS)
/// instead of naming a bundled font at all.
enum AppFont {
  systemDefault('system', 'Default (System)', null),
  manrope('manrope', 'Manrope', 'Manrope'),
  inter('inter', 'Inter', 'Inter'),
  dmSans('dm_sans', 'DM Sans', 'DM Sans'),
  outfit('outfit', 'Outfit', 'Outfit');

  /// Stored in SharedPreferences -- stable even if display order/labels
  /// change later, unlike persisting the enum index.
  final String id;
  final String label;

  /// Passed straight to `ThemeData(fontFamily: ...)`. Null means "name
  /// no font", i.e. the platform default.
  final String? fontFamily;

  const AppFont(this.id, this.label, this.fontFamily);

  static AppFont fromId(String? id) {
    return AppFont.values.firstWhere(
      (f) => f.id == id,
      orElse: () => AppFont.manrope,
    );
  }
}

/// Mirrors how `AppColors.accent` works (2026-10-22, "6 app themes"):
/// the one runtime-mutable font setting, read fresh by
/// buildAppTheme()/buildAppDarkTheme() every time app.dart's
/// `BlocBuilder<ThemeBloc, ThemeState>` rebuilds `MaterialApp` -- so a
/// font change takes effect the same proven way an accent-color change
/// already does, with zero per-screen wiring. Set from the saved
/// preference before runApp() (see main.dart) and again whenever
/// ThemeBloc handles a ThemeFontChanged event.
class AppFonts {
  AppFonts._();
  static AppFont current = AppFont.manrope;
}
