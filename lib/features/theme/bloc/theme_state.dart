import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// State for [ThemeBloc]: just the current [ThemeMode].
///
/// Persisted across app restarts via SharedPreferences (2026-09-24) --
/// see ThemeBloc's own doc comment for how. Starts light only as the
/// fallback for a genuinely first-ever launch (no saved preference
/// yet), not on every launch like before.
class ThemeState extends Equatable {
  final ThemeMode mode;

  const ThemeState({this.mode = ThemeMode.light});

  bool get isDark => mode == ThemeMode.dark;

  ThemeState copyWith({ThemeMode? mode}) => ThemeState(mode: mode ?? this.mode);

  @override
  List<Object?> get props => [mode];
}
