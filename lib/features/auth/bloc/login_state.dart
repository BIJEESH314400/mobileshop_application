import 'package:equatable/equatable.dart';

/// Unchanged from the Cubit version — State shape doesn't depend on
/// whether a Cubit or a Bloc produces it. This is still just "what the
/// UI needs to render right now."
class LoginState extends Equatable {
  final bool isSubmitting;
  final bool isSuccess;
  final String? errorMessage;

  const LoginState({
    this.isSubmitting = false,
    this.isSuccess = false,
    this.errorMessage,
  });

  LoginState copyWith({
    bool? isSubmitting,
    bool? isSuccess,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LoginState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isSubmitting, isSuccess, errorMessage];
}
