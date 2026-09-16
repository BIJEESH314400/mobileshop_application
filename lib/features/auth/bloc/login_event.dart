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
///
/// Login identifies an account by mobile number + shop ID (not email —
/// most staff at a small shop have a phone but not necessarily an
/// email they check), plus a password.
class LoginSubmitted extends LoginEvent {
  final String mobile;
  final String shopId;
  final String password;

  const LoginSubmitted({required this.mobile, required this.shopId, required this.password});

  @override
  List<Object?> get props => [mobile, shopId, password];
}
