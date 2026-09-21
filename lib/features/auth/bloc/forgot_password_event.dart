import 'package:equatable/equatable.dart';

sealed class ForgotPasswordEvent extends Equatable {
  const ForgotPasswordEvent();

  @override
  List<Object?> get props => [];
}

/// Fired when the user taps "Send Reset Link".
class ForgotPasswordSubmitted extends ForgotPasswordEvent {
  final String username;

  const ForgotPasswordSubmitted({required this.username});

  @override
  List<Object?> get props => [username];
}
