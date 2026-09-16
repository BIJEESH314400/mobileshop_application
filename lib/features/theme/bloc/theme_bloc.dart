import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'theme_event.dart';
import 'theme_state.dart';

/// App-wide light/dark switch. Provided once at the root in app.dart
/// (above MaterialApp), so `context.read<ThemeBloc>()` /
/// `context.watch<ThemeBloc>()` work from any screen — right now only
/// the Profile screen's Dark Mode row uses it, but any other screen
/// can opt in the same way later.
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc() : super(const ThemeState()) {
    on<ThemeToggled>(_onToggled);
  }

  void _onToggled(ThemeToggled event, Emitter<ThemeState> emit) {
    emit(state.copyWith(mode: state.isDark ? ThemeMode.light : ThemeMode.dark));
  }
}
