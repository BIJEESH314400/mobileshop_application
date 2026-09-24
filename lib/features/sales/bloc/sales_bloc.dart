import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/product.dart';
import '../../../core/models/sale.dart';
import '../../../core/repositories/current_user_repository.dart';
import '../../../core/repositories/product_repository.dart';
import '../../../core/repositories/sale_repository.dart';
import 'sales_event.dart';
import 'sales_state.dart';

class SalesBloc extends Bloc<SalesEvent, SalesState> {
  final ProductRepository _productRepository;
  final SaleRepository _saleRepository;
  final CurrentUserRepository _currentUserRepository;

  SalesBloc({
    ProductRepository? productRepository,
    SaleRepository? saleRepository,
    CurrentUserRepository? currentUserRepository,
  })  : _productRepository = productRepository ?? ProductRepository(),
        _saleRepository = saleRepository ?? SaleRepository(),
        _currentUserRepository = currentUserRepository ?? CurrentUserRepository(),
        super(const SalesState()) {
    on<SalesSubscriptionRequested>(_onSubscriptionRequested);
    on<SaleItemAdded>(_onItemAdded);
    on<SaleItemQtyChanged>(_onQtyChanged);
    on<SaleItemRemoved>(_onItemRemoved);
    on<SaleDiscountChanged>(_onDiscountChanged);
    on<SalePaymentMethodChanged>(_onPaymentMethodChanged);
    on<SaleSubmitted>(_onSubmitted);
  }

  Future<void> _onSubscriptionRequested(
    SalesSubscriptionRequested event,
    Emitter<SalesState> emit,
  ) async {
    emit(state.copyWith(isLoadingProducts: true, clearError: true));

    // One-shot -- who's signed in doesn't change mid-sale, same
    // reasoning as CurrentUserBloc's single fetch on Profile. Done
    // before the (long-lived, never-completing) product stream below,
    // since anything after `await emit.forEach(...)` wouldn't run until
    // that stream closes. A failed lookup is swallowed -- state.currentUser
    // just stays null and the sale still goes through, only without
    // seller attribution (see _onSubmitted).
    try {
      final currentUser = await _currentUserRepository.loadCurrentUser();
      emit(state.copyWith(currentUser: currentUser));
    } catch (_) {
      // Leave currentUser null -- see the comment above.
    }

    // Same live-stream pattern as ProductsBloc — the "Add Product"
    // picker stays current with stock/price changes made anywhere else
    // in the app while the cashier is mid-sale.
    await emit.forEach<List<Product>>(
      _productRepository.watchProducts(shopId: currentShopId),
      onData: (products) => state.copyWith(
        isLoadingProducts: false,
        availableProducts: products,
        clearError: true,
      ),
      onError: (error, stackTrace) => state.copyWith(
        isLoadingProducts: false,
        errorMessage: 'Could not load products. Please check your connection and try again.',
      ),
    );
  }

  void _onItemAdded(SaleItemAdded event, Emitter<SalesState> emit) {
    final product = event.product;
    final index = state.cartItems.indexWhere((item) => item.productId == product.id);

    if (index >= 0) {
      final existing = state.cartItems[index];
      if (existing.qty >= product.stockQty) {
        emit(state.copyWith(errorMessage: 'Only ${product.stockQty} of ${product.name} in stock'));
        return;
      }
      final updated = [...state.cartItems];
      updated[index] = existing.copyWith(qty: existing.qty + 1);
      emit(state.copyWith(cartItems: updated, isSuccess: false, clearError: true));
      return;
    }

    if (product.stockQty <= 0) {
      emit(state.copyWith(errorMessage: '${product.name} is out of stock'));
      return;
    }

    emit(state.copyWith(
      cartItems: [
        ...state.cartItems,
        CartItem(
          productId: product.id,
          name: product.name,
          price: product.price,
          qty: 1,
          availableStock: product.stockQty,
        ),
      ],
      isSuccess: false,
      clearError: true,
    ));
  }

  void _onQtyChanged(SaleItemQtyChanged event, Emitter<SalesState> emit) {
    final index = state.cartItems.indexWhere((item) => item.productId == event.productId);
    if (index < 0) return;

    final item = state.cartItems[index];
    // int.clamp() returns num, not int, so the bounds are applied by
    // hand here rather than risking a num/int assignment mismatch.
    final cap = item.availableStock < 1 ? 1 : item.availableStock;
    var newQty = item.qty + event.delta;
    if (newQty < 1) newQty = 1;
    if (newQty > cap) newQty = cap;
    if (newQty == item.qty) return;

    final updated = [...state.cartItems];
    updated[index] = item.copyWith(qty: newQty);
    emit(state.copyWith(cartItems: updated, isSuccess: false, clearError: true));
  }

  void _onItemRemoved(SaleItemRemoved event, Emitter<SalesState> emit) {
    emit(state.copyWith(
      cartItems: state.cartItems.where((item) => item.productId != event.productId).toList(),
      isSuccess: false,
      clearError: true,
    ));
  }

  void _onDiscountChanged(SaleDiscountChanged event, Emitter<SalesState> emit) {
    emit(state.copyWith(discountInput: event.discount, isSuccess: false));
  }

  void _onPaymentMethodChanged(SalePaymentMethodChanged event, Emitter<SalesState> emit) {
    emit(state.copyWith(paymentMethod: event.method, isSuccess: false));
  }

  Future<void> _onSubmitted(SaleSubmitted event, Emitter<SalesState> emit) async {
    if (state.cartItems.isEmpty) {
      emit(state.copyWith(errorMessage: 'Add at least one item before completing the sale'));
      return;
    }

    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      final sale = Sale(
        id: '', // Firestore assigns the real id when completeSale() runs — never read from here.
        shopId: currentShopId,
        items: state.cartItems
            .map((item) => SaleItem(
                  productId: item.productId,
                  name: item.name,
                  price: item.price,
                  qty: item.qty,
                ))
            .toList(),
        subtotal: state.subtotal,
        discount: state.discount,
        tax: state.tax,
        total: state.total,
        paymentMethod: _paymentKey(state.paymentMethod),
        createdAt: null, // set server-side — see Sale.toMap()
        soldByUid: state.currentUser?.uid ?? '',
        soldByName: state.currentUser?.displayName ?? '',
        soldByRole: state.currentUser == null
            ? 'owner'
            : (state.currentUser!.isOwner ? 'owner' : 'employee'),
      );

      await _saleRepository.completeSale(sale);

      // Cart clears on success so the screen is ready for the next
      // sale — the confirmation + navigation is handled by the View.
      emit(state.copyWith(
        isSubmitting: false,
        isSuccess: true,
        completedTotal: state.total,
        cartItems: [],
        discountInput: '',
        clearError: true,
      ));
    } on InsufficientStockException catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
    } catch (_) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: 'Could not complete sale. Please check your connection and try again.',
      ));
    }
  }

  String _paymentKey(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.upi:
        return 'upi';
      case PaymentMethod.card:
        return 'card';
      case PaymentMethod.cash:
        return 'cash';
    }
  }
}
