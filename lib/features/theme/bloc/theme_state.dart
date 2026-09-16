import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// State for [ThemeBloc]: just the current [ThemeMode]. Starts light.
///
/// Not persisted across app restarts yet — every launch starts back on
/// light regardless of what was last chosen. Making it survive a
/// restart is a `HydratedBloc` job (R&D backlog topic 10), left for
/// later on purpose.
class ThemeState extends Equatable {
  final ThemeMode mode;

  const ThemeState({this.mode = ThemeMode.light});

  bool get isDark => mode == ThemeMode.dark;

  ThemeState copyWith({ThemeMode? mode}) => ThemeState(mode: mode ?? this.mode);

  @override
  List<Object?> get props => [mode];
}
