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
    on<AddProductDeleted>(_onDeleted);
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
        // Stock Qty is optional on this form -- left blank, it just
        // means "0 in stock" rather than blocking the save.
        stockQty: int.tryParse(event.stockQty.trim()) ?? 0,
        sku: event.sku.trim(),
        condition: event.condition,
        description: event.description.trim(),
        shopId: currentShopId,
        barcode: event.barcode.trim(),
        createdAt: null, // set server-side — see Product.toMap()
      );

      String? savedBarcode;
      if (event.productId == null) {
        final saved = await _repository.addProduct(product);
        savedBarcode = saved.barcode;
      } else {
        final saved = await _repository.updateProduct(event.productId!, product);
        savedBarcode = saved.barcode;
      }
      emit(state.copyWith(isSubmitting: false, isSuccess: true, savedBarcode: savedBarcode));
    } catch (_) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: 'Could not save product. Please check your connection and try again.',
        isSuccess: false,
      ));
    }
  }

  Future<void> _onDeleted(AddProductDeleted event, Emitter<AddProductState> emit) async {
    emit(state.copyWith(isDeleting: true, clearError: true));
    try {
      await _repository.deleteProduct(event.productId);
      emit(state.copyWith(isDeleting: false, isDeleted: true));
    } catch (_) {
      emit(state.copyWith(
        isDeleting: false,
        errorMessage: 'Could not delete product. Please check your connection and try again.',
      ));
    }
  }

  // Only Product Name and Price are mandatory now -- Category, Brand,
  // and Stock Qty are all optional and simply default to their empty
  // value (''/0, see Product.fromMap) when left blank, same as SKU,
  // Barcode, and Description already did before this change.
  String? _validate(AddProductSubmitted event) {
    if (event.name.trim().isEmpty) return 'Product name is required';

    final price = double.tryParse(event.price.replaceAll(',', '').trim());
    if (price == null || price <= 0) return 'Enter a valid price';

    // Stock Qty: not required, but if something WAS typed, it still
    // has to be a real non-negative number -- "abc" or "-1" is still
    // rejected, only *blank* is now allowed through.
    final stockText = event.stockQty.trim();
    if (stockText.isNotEmpty) {
      final stock = int.tryParse(stockText);
      if (stock == null || stock < 0) return 'Enter a valid stock quantity';
    }

    return null;
  }
}
