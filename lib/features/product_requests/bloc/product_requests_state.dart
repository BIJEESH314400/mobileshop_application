import 'package:equatable/equatable.dart';

import '../../../core/models/product_request.dart';

class ProductRequestsState extends Equatable {
  final bool isLoading;
  final List<ProductRequest> requests;
  final String? errorMessage;

  const ProductRequestsState({
    this.isLoading = true,
    this.requests = const [],
    this.errorMessage,
  });

  ProductRequestsState copyWith({
    bool? isLoading,
    List<ProductRequest>? requests,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProductRequestsState(
      isLoading: isLoading ?? this.isLoading,
      requests: requests ?? this.requests,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isLoading, requests, errorMessage];
}
