import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_font.dart';
import '../../../core/theme/app_theme_color.dart';

/// State for [ThemeBloc]: the current [ThemeMode], (2026-10-22) which
/// of the 6 accent-color themes is active, and (2026-11-20) which of
/// the 5 fonts is active.
///
/// All three are persisted across app restarts via SharedPreferences --
/// see ThemeBloc's own doc comment for how. Starts light + indigo +
/// Manrope (the app's original color and font) as the fallback for a
/// genuinely first-ever launch (no saved preference yet).
class ThemeState extends Equatable {
  final ThemeMode mode;
  final AppThemeColor themeColor;
  final AppFont font;

  const ThemeState({
    this.mode = ThemeMode.light,
    this.themeColor = AppThemeColor.indigo,
    this.font = AppFont.manrope,
  });

  bool get isDark => mode == ThemeMode.dark;

  ThemeState copyWith({ThemeMode? mode, AppThemeColor? themeColor, AppFont? font}) => ThemeState(
        mode: mode ?? this.mode,
        themeColor: themeColor ?? this.themeColor,
        font: font ?? this.font,
      );

  @override
  List<Object?> get props => [mode, themeColor, font];
}
