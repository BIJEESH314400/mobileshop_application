import 'package:equatable/equatable.dart';

class AddProductState extends Equatable {
  final bool isSubmitting;
  final bool isSuccess;
  final bool isDeleting;
  final bool isDeleted;
  final String? errorMessage;

  /// The barcode the just-saved product ended up with -- either what the
  /// person scanned/typed, or the one generated automatically because
  /// they left Barcode blank. Only meaningful alongside `isSuccess`; the
  /// View uses it to tell the person what got assigned, since an
  /// auto-generated barcode would otherwise be invisible to them until
  /// they reopened the product.
  final String? savedBarcode;

  const AddProductState({
    this.isSubmitting = false,
    this.isSuccess = false,
    this.isDeleting = false,
    this.isDeleted = false,
    this.errorMessage,
    this.savedBarcode,
  });

  AddProductState copyWith({
    bool? isSubmitting,
    bool? isSuccess,
    bool? isDeleting,
    bool? isDeleted,
    String? errorMessage,
    String? savedBarcode,
    bool clearError = false,
  }) {
    return AddProductState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      isDeleting: isDeleting ?? this.isDeleting,
      isDeleted: isDeleted ?? this.isDeleted,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      savedBarcode: savedBarcode ?? this.savedBarcode,
    );
  }

  @override
  List<Object?> get props => [isSubmitting, isSuccess, isDeleting, isDeleted, errorMessage, savedBarcode];
}
