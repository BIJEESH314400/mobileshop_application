import 'package:equatable/equatable.dart';

/// Every action the Login screen can trigger. Only one today
/// (the Sign In button), but this is where LoginEmailChanged,
/// LoginPasswordVisibilityToggled, etc. would go as the form grows.
sealed class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

/// Fired when the user taps "Sign In". Carries the raw field values in
/// with it — the Bloc never reaches into a TextEditingController itself,
/// the View hands it everything it needs.
class LoginSubmitted extends LoginEvent {
  final String email;
  final String password;

  const LoginSubmitted({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}
