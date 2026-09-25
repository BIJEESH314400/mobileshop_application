import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/app_logger.dart';
import 'theme_event.dart';
import 'theme_state.dart';

/// App-wide light/dark switch. Provided once at the root in app.dart
/// (above MaterialApp), so `context.read<ThemeBloc>()` /
/// `context.watch<ThemeBloc>()` work from any screen — right now only
/// the Profile screen's Dark Mode row uses it, but any other screen
/// can opt in the same way later.
///
/// Persisted via SharedPreferences (2026-09-24, user-reported: "set
/// dark mode then quit again open. dark mode not show. only light
/// mode") -- the choice is saved under `_prefsKey` every time it's
/// toggled, and the app's initial mode is read from that same key
/// BEFORE runApp() even happens (see main.dart), so there's no flash
/// of light mode on a dark-mode launch while this Bloc spins up.
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  static const _prefsKey = 'isDarkMode';

  ThemeBloc({ThemeMode? initialMode}) : super(ThemeState(mode: initialMode ?? ThemeMode.light)) {
    on<ThemeToggled>(_onToggled);
  }

  /// Reads the saved preference. Called once, from main(), before
  /// runApp() -- kept as a static method (not an event/handler) since
  /// it has to finish before the Bloc/widget tree exists at all, which
  /// is what avoids the flash-of-wrong-theme a Splash-style "start
  /// light, correct after an async load" approach would have.
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
}
