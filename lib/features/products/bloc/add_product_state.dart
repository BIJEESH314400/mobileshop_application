import 'package:equatable/equatable.dart';

class AddProductState extends Equatable {
  final bool isSubmitting;
  final bool isSuccess;
  final String? errorMessage;

  const AddProductState({
    this.isSubmitting = false,
    this.isSuccess = false,
    this.errorMessage,
  });

  AddProductState copyWith({
    bool? isSubmitting,
    bool? isSuccess,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AddProductState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isSubmitting, isSuccess, errorMessage];
}
