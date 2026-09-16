import 'package:equatable/equatable.dart';

/// Events for [ThemeBloc]. Just one for now — flip between light/dark.
/// Kept as a proper Event->Bloc->State class (not a Cubit) to match the
/// rest of this project's deliberate all-Bloc convention (see
/// SplashBloc/LoginBloc), even though a plain on/off flag would
/// normally be a textbook Cubit case — see R&D backlog topic 9 for
/// that comparison.
abstract class ThemeEvent extends Equatable {
  const ThemeEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched from the Profile screen's Dark Mode switch.
class ThemeToggled extends ThemeEvent {
  const ThemeToggled();
}
