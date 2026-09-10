import 'package:equatable/equatable.dart';

/// Every action the Splash screen can trigger. Right now there's only
/// one — "the screen appeared, go check auth status" — but every screen
/// action will always start as a named Event class, whether that's
/// one event or twelve.
sealed class SplashEvent extends Equatable {
  const SplashEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once, right when SplashScreen builds. See splash_screen.dart —
/// `SplashBloc()..add(const SplashStarted())`.
class SplashStarted extends SplashEvent {
  const SplashStarted();
}
