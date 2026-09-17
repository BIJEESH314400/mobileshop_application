import 'package:equatable/equatable.dart';

/// Every action the Login screen can trigger. Only one today
/// (the Sign In button), but this is where LoginEmailChanged,
/// LoginPasswordVisibilityToggled, etc. would go as the form grows.
sealed class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

/// Fired when the user taps "Sign In". Just username + password —
/// kept deliberately simple. If the account turns out to have more
/// than one branch, the Bloc doesn't ask for that up front; it finds
/// out from the login response and asks via a popup afterward instead
/// (see BranchSelected below), so a single-branch account never sees
/// an extra field it doesn't need.
class LoginSubmitted extends LoginEvent {
  final String username;
  final String password;

  const LoginSubmitted({required this.username, required this.password});

  @override
  List<Object?> get props => [username, password];
}

/// Fired when the user picks a branch from the popup shown after
/// LoginSubmitted, for accounts whose login response says they have
/// more than one shop.
class BranchSelected extends LoginEvent {
  final String branchId;

  const BranchSelected({required this.branchId});

  @override
  List<Object?> get props => [branchId];
}
