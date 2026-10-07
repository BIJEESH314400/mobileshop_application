import 'package:equatable/equatable.dart';

class AddProductState extends Equatable {
  final bool isSubmitting;
  final bool isSuccess;
  final bool isDeleting;
  final bool isDeleted;
  final String? errorMessage;

  const AddProductState({
    this.isSubmitting = false,
    this.isSuccess = false,
    this.isDeleting = false,
    this.isDeleted = false,
    this.errorMessage,
  });

  AddProductState copyWith({
    bool? isSubmitting,
    bool? isSuccess,
    bool? isDeleting,
    bool? isDeleted,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AddProductState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      isDeleting: isDeleting ?? this.isDeleting,
      isDeleted: isDeleted ?? this.isDeleted,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isSubmitting, isSuccess, isDeleting, isDeleted, errorMessage];
}
