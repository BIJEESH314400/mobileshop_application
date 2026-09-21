import 'package:equatable/equatable.dart';

import '../../../core/models/product.dart';

class ProductsState extends Equatable {
  final bool isLoading;
  final List<Product> products;
  final String? errorMessage;

  const ProductsState({
    this.isLoading = true,
    this.products = const [],
    this.errorMessage,
  });

  ProductsState copyWith({
    bool? isLoading,
    List<Product>? products,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProductsState(
      isLoading: isLoading ?? this.isLoading,
      products: products ?? this.products,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isLoading, products, errorMessage];
}
