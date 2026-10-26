import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_color.dart';

/// State for [ThemeBloc]: the current [ThemeMode], and (2026-10-22)
/// which of the 6 accent-color themes is active.
///
/// Both are persisted across app restarts via SharedPreferences --
/// see ThemeBloc's own doc comment for how. Starts light + indigo
/// (the app's original color) as the fallback for a genuinely
/// first-ever launch (no saved preference yet).
class ThemeState extends Equatable {
  final ThemeMode mode;
  final AppThemeColor themeColor;

  const ThemeState({this.mode = ThemeMode.light, this.themeColor = AppThemeColor.indigo});

  bool get isDark => mode == ThemeMode.dark;

  ThemeState copyWith({ThemeMode? mode, AppThemeColor? themeColor}) =>
      ThemeState(mode: mode ?? this.mode, themeColor: themeColor ?? this.themeColor);

  @override
  List<Object?> get props => [mode, themeColor];
}
