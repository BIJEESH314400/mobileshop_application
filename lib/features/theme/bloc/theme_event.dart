import 'package:equatable/equatable.dart';

import '../../../core/theme/app_theme_color.dart';

/// Events for [ThemeBloc] -- light/dark, and (2026-10-22) which of the
/// 6 accent-color themes is active. Kept as a proper Event->Bloc->State
/// class (not a Cubit) to match the rest of this project's deliberate
/// all-Bloc convention (see SplashBloc/LoginBloc), even though a plain
/// on/off flag would normally be a textbook Cubit case — see R&D
/// backlog topic 9 for that comparison.
abstract class ThemeEvent extends Equatable {
  const ThemeEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched from the Profile screen's Dark Mode switch.
class ThemeToggled extends ThemeEvent {
  const ThemeToggled();
}

/// Dispatched from the Profile screen's App Theme picker sheet.
class ThemeColorChanged extends ThemeEvent {
  final AppThemeColor color;
  const ThemeColorChanged(this.color);

  @override
  List<Object?> get props => [color];
}
