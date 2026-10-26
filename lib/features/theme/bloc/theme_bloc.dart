import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_color.dart';
import '../../../core/utils/app_logger.dart';
import 'theme_event.dart';
import 'theme_state.dart';

/// App-wide light/dark switch, and (2026-10-22) app-wide accent-color
/// theme switch. Provided once at the root in app.dart (above
/// MaterialApp), so `context.read<ThemeBloc>()` / `context.watch<ThemeBloc>()`
/// work from any screen — right now only the Profile screen's Dark
/// Mode row and App Theme picker use it, but any other screen can opt
/// in the same way later.
///
/// Both preferences persist via SharedPreferences -- dark/light since
/// 2026-09-24 (user-reported: "set dark mode then quit again open.
/// dark mode not show. only light mode"), theme color since
/// 2026-10-22. Each is saved under its own prefs key every time it
/// changes, and the app's initial values are read from those same keys
/// BEFORE runApp() even happens (see main.dart), so there's no flash
/// of the wrong theme on launch while this Bloc spins up.
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  static const _prefsKey = 'isDarkMode';
  static const _colorPrefsKey = 'themeColorId';

  ThemeBloc({ThemeMode? initialMode, AppThemeColor? initialThemeColor})
    : super(ThemeState(mode: initialMode ?? ThemeMode.light, themeColor: initialThemeColor ?? AppThemeColor.indigo)) {
    on<ThemeToggled>(_onToggled);
    on<ThemeColorChanged>(_onColorChanged);
  }

  /// Reads the saved light/dark preference. Called once, from main(),
  /// before runApp() -- kept as a static method (not an event/handler)
  /// since it has to finish before the Bloc/widget tree exists at all,
  /// which is what avoids the flash-of-wrong-theme a Splash-style
  /// "start light, correct after an async load" approach would have.
  static Future<ThemeMode> loadSavedMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool(_prefsKey) ?? false;
      return isDark ? ThemeMode.dark : ThemeMode.light;
    } catch (e, st) {
      AppLogger.error('ThemeBloc.loadSavedMode', e, st);
      return ThemeMode.light;
    }
  }

  /// Reads the saved accent-theme preference, same "before runApp()"
  /// reasoning as [loadSavedMode]. Caller (main.dart) is also
  /// responsible for setting `AppColors.accent` from the result before
  /// the first frame -- this method only reads the saved choice, it
  /// doesn't apply it, since it runs before AppColors is otherwise
  /// touched and before the Bloc/widget tree exists.
  static Future<AppThemeColor> loadSavedThemeColor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AppThemeColor.fromId(prefs.getString(_colorPrefsKey));
    } catch (e, st) {
      AppLogger.error('ThemeBloc.loadSavedThemeColor', e, st);
      return AppThemeColor.indigo;
    }
  }

  Future<void> _onToggled(ThemeToggled event, Emitter<ThemeState> emit) async {
    final newMode = state.isDark ? ThemeMode.light : ThemeMode.dark;
    emit(state.copyWith(mode: newMode));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, newMode == ThemeMode.dark);
    } catch (e, st) {
      // The switch itself already flipped visually (emit() above) --
      // a failed save just means it won't survive the NEXT restart,
      // which is worth logging but not worth reverting the toggle or
      // showing an error for over something this low-stakes.
      AppLogger.error('ThemeBloc._onToggled (save)', e, st);
    }
  }

  Future<void> _onColorChanged(ThemeColorChanged event, Emitter<ThemeState> emit) async {
    // Updating AppColors.accent here (not just in main.dart) is what
    // makes picking a new theme while the app is already running take
    // effect immediately -- buildAppTheme()/buildAppDarkTheme() read
    // this value fresh every time app.dart's BlocBuilder rebuilds
    // MaterialApp (which emit() below triggers), so every screen that
    // reads Theme.of(context)/AppPalette.of(context) anywhere in its
    // build() -- which is effectively every styled screen in this app
    // -- picks up the new accent color on its next rebuild, the same
    // proven mechanism the Dark Mode toggle already relies on.
    AppColors.accent = event.color.color;
    emit(state.copyWith(themeColor: event.color));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_colorPrefsKey, event.color.id);
    } catch (e, st) {
      // Same low-stakes reasoning as _onToggled's save failure above --
      // the switch already took visual effect, a failed save just
      // means it won't survive the next restart.
      AppLogger.error('ThemeBloc._onColorChanged (save)', e, st);
    }
  }
}
