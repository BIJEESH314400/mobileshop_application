import 'package:equatable/equatable.dart';

sealed class CurrentUserEvent extends Equatable {
  const CurrentUserEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the Profile screen opens — looks up who is actually
/// signed in (owner or a specific employee) so the screen can show
/// their real name instead of fixed placeholder text.
class CurrentUserRequested extends CurrentUserEvent {
  const CurrentUserRequested();
}
