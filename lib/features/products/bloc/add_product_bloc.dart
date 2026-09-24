import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/product.dart';
import '../../../core/repositories/product_repository.dart';
import 'add_product_event.dart';
import 'add_product_state.dart';

class AddProductBloc extends Bloc<AddProductEvent, AddProductState> {
  final ProductRepository _repository;

  AddProductBloc({ProductRepository? repository})
      : _repository = repository ?? ProductRepository(),
        super(const AddProductState()) {
    on<AddProductSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(AddProductSubmitted event, Emitter<AddProductState> emit) async {
    final validationError = _validate(event);
    if (validationError != null) {
      emit(state.copyWith(errorMessage: validationError, isSuccess: false));
      return;
    }

    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      final product = Product(
        // Ignored on create (Firestore assigns the real id when
        // addProduct() runs) and ignored on update too (updateProduct()
        // takes the id as its own parameter, not from this map) — only
        // kept here because Product's constructor requires it.
        id: event.productId ?? '',
        name: event.name.trim(),
        category: event.category,
        brand: event.brand,
        // Commas are just for readability while typing (e.g. "68,999") —
        // strip them before parsing, since a comma isn't a valid digit.
        price: double.parse(event.price.replaceAll(',', '').trim()),
        stockQty: int.parse(event.stockQty.trim()),
        sku: event.sku.trim(),
        condition: event.condition,
        description: event.description.trim(),
        shopId: currentShopId,
        createdAt: null, // set server-side — see Product.toMap()
      );

      if (event.productId == null) {
        await _repository.addProduct(product);
      } else {
        await _repository.updateProduct(event.productId!, product);
      }
      emit(state.copyWith(isSubmitting: false, isSuccess: true));
    } catch (_) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: 'Could not save product. Please check your connection and try again.',
        isSuccess: false,
      ));
    }
  }

  String? _validate(AddProductSubmitted event) {
    if (event.name.trim().isEmpty) return 'Product name is required';
    if (event.category.trim().isEmpty) return 'Please choose a category';
    if (event.brand.trim().isEmpty) return 'Please choose a brand';

    final price = double.tryParse(event.price.replaceAll(',', '').trim());
    if (price == null || price <= 0) return 'Enter a valid price';

    final stock = int.tryParse(event.stockQty.trim());
    if (stock == null || stock < 0) return 'Enter a valid stock quantity';

    return null;
  }
}
