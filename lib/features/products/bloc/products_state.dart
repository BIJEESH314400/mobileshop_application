import 'package:equatable/equatable.dart';

import '../../../core/models/product.dart';

class ProductsState extends Equatable {
  final bool isLoading;
  final List<Product> products;
  final String searchQuery;
  final String? errorMessage;

  const ProductsState({
    this.isLoading = true,
    this.products = const [],
    this.searchQuery = '',
    this.errorMessage,
  });

  /// `products`, filtered by `searchQuery` against name/SKU/brand --
  /// same "math/filtering lives in State, not pushed into the Bloc"
  /// approach CustomersState.filteredCustomers already uses. The
  /// Products screen's own category pills filter on top of this list,
  /// same as before.
  List<Product> get filteredProducts {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return products;
    return products
        .where((p) =>
            p.name.toLowerCase().contains(query) ||
            p.sku.toLowerCase().contains(query) ||
            p.brand.toLowerCase().contains(query))
        .toList();
  }

  ProductsState copyWith({
    bool? isLoading,
    List<Product>? products,
    String? searchQuery,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProductsState(
      isLoading: isLoading ?? this.isLoading,
      products: products ?? this.products,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isLoading, products, searchQuery, errorMessage];
}
