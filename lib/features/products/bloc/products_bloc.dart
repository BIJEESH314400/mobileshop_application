import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/product.dart';
import '../../../core/repositories/product_repository.dart';
import 'products_event.dart';
import 'products_state.dart';

class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  final ProductRepository _repository;

  ProductsBloc({ProductRepository? repository})
      : _repository = repository ?? ProductRepository(),
        super(const ProductsState()) {
    on<ProductsSubscriptionRequested>(_onSubscriptionRequested);
  }

  Future<void> _onSubscriptionRequested(
    ProductsSubscriptionRequested event,
    Emitter<ProductsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    // emit.forEach keeps this handler "open" for as long as Firestore
    // keeps pushing updates — every add/edit/delete to a product in
    // this shop re-runs `onData` and refreshes the list on screen
    // automatically, with no manual refresh button needed.
    await emit.forEach<List<Product>>(
      _repository.watchProducts(shopId: currentShopId),
      onData: (products) => state.copyWith(isLoading: false, products: products, clearError: true),
      onError: (error, stackTrace) => state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load products. Please check your connection and try again.',
      ),
    );
  }
}
