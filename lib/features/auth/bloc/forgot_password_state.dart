import 'package:equatable/equatable.dart';

class ForgotPasswordState extends Equatable {
  final bool isSubmitting;
  final bool isSuccess;
  final String? errorMessage;

  const ForgotPasswordState({
    this.isSubmitting = false,
    this.isSuccess = false,
    this.errorMessage,
  });

  ForgotPasswordState copyWith({
    bool? isSubmitting,
    bool? isSuccess,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ForgotPasswordState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isSubmitting, isSuccess, errorMessage];
}
