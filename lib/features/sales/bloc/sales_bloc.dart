import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/models/sale.dart';
import '../../../core/repositories/current_user_repository.dart';
import '../../../core/repositories/customer_repository.dart';
import '../../../core/repositories/product_repository.dart';
import '../../../core/repositories/sale_repository.dart';
import '../../../core/repositories/tax_invoice_settings_repository.dart';
import 'sales_event.dart';
import 'sales_state.dart';

class SalesBloc extends Bloc<SalesEvent, SalesState> {
  final ProductRepository _productRepository;
  final SaleRepository _saleRepository;
  final CurrentUserRepository _currentUserRepository;
  final CustomerRepository _customerRepository;
  final TaxInvoiceSettingsRepository _taxInvoiceSettingsRepository;

  SalesBloc({
    ProductRepository? productRepository,
    SaleRepository? saleRepository,
    CurrentUserRepository? currentUserRepository,
    CustomerRepository? customerRepository,
    TaxInvoiceSettingsRepository? taxInvoiceSettingsRepository,
  })  : _productRepository = productRepository ?? ProductRepository(),
        _saleRepository = saleRepository ?? SaleRepository(),
        _currentUserRepository = currentUserRepository ?? CurrentUserRepository(),
        _customerRepository = customerRepository ?? CustomerRepository(),
        _taxInvoiceSettingsRepository = taxInvoiceSettingsRepository ?? TaxInvoiceSettingsRepository(),
        super(const SalesState()) {
    on<SalesSubscriptionRequested>(_onSubscriptionRequested);
    on<SalesCustomersSubscriptionRequested>(_onCustomersSubscriptionRequested);
    on<SaleItemAdded>(_onItemAdded);
    on<SaleItemScannedAdded>(_onScannedAdded);
    on<SaleItemUnitRemoved>(_onUnitRemoved);
    on<SaleItemSlotVerified>(_onSlotVerified);
    on<SaleItemSlotRemoved>(_onSlotRemoved);
    on<SaleItemQuickRemove>(_onQuickRemove);
    on<SaleItemRemoved>(_onItemRemoved);
    on<SaleDiscountChanged>(_onDiscountChanged);
    on<SalePaymentMethodChanged>(_onPaymentMethodChanged);
    on<SaleCustomerSelected>(_onCustomerSelected);
    on<SaleSubmitted>(_onSubmitted);
  }

  // Runs concurrently alongside _onSubscriptionRequested's product
  // stream above -- same "separate on<EventType> handlers, each with
  // their own long-lived subscription" pattern ConversationBloc uses
  // for its typing indicator. A failed customer-list load is swallowed
  // silently: checkout must stay usable (walk-in sales) even if the
  // customer directory can't be reached right now.
  Future<void> _onCustomersSubscriptionRequested(
    SalesCustomersSubscriptionRequested event,
    Emitter<SalesState> emit,
  ) async {
    await emit.forEach<List<Customer>>(
      _customerRepository.watchCustomers(shopId: currentShopId),
      onData: (customers) => state.copyWith(availableCustomers: customers),
      onError: (error, stackTrace) => state,
    );
  }

  void _onCustomerSelected(SaleCustomerSelected event, Emitter<SalesState> emit) {
    emit(state.copyWith(
      selectedCustomer: event.customer,
      clearCustomer: event.customer == null,
      isSuccess: false,
    ));
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

    // One-shot, same reasoning as currentUser just above -- the GST
    // rate doesn't change mid-sale either. A failed/missing read
    // leaves state.taxRatePercent at its 18% default (see SalesState's
    // own field doc comment), so checkout keeps working exactly as it
    // always did if this shop never opened Tax & Invoice Settings, or
    // if this one read hiccups.
    try {
      final taxSettings = await _taxInvoiceSettingsRepository.getTaxInvoiceSettings(currentShopId);
      emit(state.copyWith(taxRatePercent: taxSettings.taxRatePercent));
    } catch (_) {
      // Leave taxRatePercent at its default -- see the comment above.
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
      updated[index] = existing.copyWith(slots: [...existing.slots, _nextSlotFor(existing)]);
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
          availableStock: product.stockQty,
          barcode: product.barcode,
          tracksUniqueUnits: product.tracksUniqueUnits,
          slots: const [CartUnitSlot()],
        ),
      ],
      isSuccess: false,
      clearError: true,
    ));
  }

  /// Same shape as _onItemAdded above, except the new slot starts out
  /// already verified (barcode + optional unitId already resolved by
  /// the View -- see `_resolveBarcode` in sales_screen.dart) rather
  /// than pending, since a real scan just happened for it.
  void _onScannedAdded(SaleItemScannedAdded event, Emitter<SalesState> emit) {
    final product = event.product;
    final index = state.cartItems.indexWhere((item) => item.productId == product.id);
    final newSlot = CartUnitSlot(barcode: event.barcode, unitId: event.unitId);

    if (index >= 0) {
      final existing = state.cartItems[index];
      if (existing.qty >= product.stockQty) {
        emit(state.copyWith(errorMessage: 'Only ${product.stockQty} of ${product.name} in stock'));
        return;
      }
      final grownSlots = _verifyWholeLineIfBulk(
        tracksUniqueUnits: existing.tracksUniqueUnits,
        slots: [...existing.slots, newSlot],
        barcode: event.barcode,
      );
      final updated = [...state.cartItems];
      updated[index] = existing.copyWith(slots: grownSlots);
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
          availableStock: product.stockQty,
          barcode: product.barcode,
          tracksUniqueUnits: product.tracksUniqueUnits,
          slots: [newSlot],
        ),
      ],
      isSuccess: false,
      clearError: true,
    ));
  }

  /// Drops the single most-recently-added slot from a line -- a
  /// still-pending one if there is one (nothing confirmed is lost by
  /// undoing an unconfirmed add), otherwise the last verified one.
  /// Removes the whole line once its last slot is gone.
  void _onUnitRemoved(SaleItemUnitRemoved event, Emitter<SalesState> emit) {
    final index = state.cartItems.indexWhere((item) => item.productId == event.productId);
    if (index < 0) return;
    final item = state.cartItems[index];
    if (item.slots.isEmpty) return;

    final slots = [...item.slots];
    var removeAt = slots.lastIndexWhere((slot) => !slot.isVerified);
    if (removeAt < 0) removeAt = slots.length - 1;
    slots.removeAt(removeAt);

    _applySlots(emit, index, event.productId, slots);
  }

  /// Fills one specific pending slot in with a barcode the View has
  /// already looked up and validated. Silently ignored if the index is
  /// out of range (the cart changed underneath an in-flight scan) --
  /// same fail-quiet reasoning other index-based handlers below use.
  void _onSlotVerified(SaleItemSlotVerified event, Emitter<SalesState> emit) {
    final index = state.cartItems.indexWhere((item) => item.productId == event.productId);
    if (index < 0) return;
    final item = state.cartItems[index];
    if (event.slotIndex < 0 || event.slotIndex >= item.slots.length) return;

    final oneVerified = [...item.slots];
    oneVerified[event.slotIndex] = CartUnitSlot(barcode: event.barcode, unitId: event.unitId);
    final slots = _verifyWholeLineIfBulk(
      tracksUniqueUnits: item.tracksUniqueUnits,
      slots: oneVerified,
      barcode: event.barcode,
    );
    final updated = [...state.cartItems];
    updated[index] = item.copyWith(slots: slots);
    emit(state.copyWith(cartItems: updated, isSuccess: false, clearError: true));
  }

  /// The barcode checklist's own "Remove" link on one specific unit
  /// row -- drops exactly that slot, verified or still pending, which
  /// also drops this line's qty by 1 (slots.length IS qty).
  void _onSlotRemoved(SaleItemSlotRemoved event, Emitter<SalesState> emit) {
    final index = state.cartItems.indexWhere((item) => item.productId == event.productId);
    if (index < 0) return;
    final item = state.cartItems[index];
    if (event.slotIndex < 0 || event.slotIndex >= item.slots.length) return;

    final slots = [...item.slots]..removeAt(event.slotIndex);
    _applySlots(emit, index, event.productId, slots);
  }

  /// "-1" / "-2" quick-remove -- same slot-preference rule as
  /// _onUnitRemoved, applied `count` times in a row.
  void _onQuickRemove(SaleItemQuickRemove event, Emitter<SalesState> emit) {
    final index = state.cartItems.indexWhere((item) => item.productId == event.productId);
    if (index < 0) return;
    final item = state.cartItems[index];

    final slots = [...item.slots];
    var remaining = event.count;
    while (remaining > 0 && slots.isNotEmpty) {
      var removeAt = slots.lastIndexWhere((slot) => !slot.isVerified);
      if (removeAt < 0) removeAt = slots.length - 1;
      slots.removeAt(removeAt);
      remaining--;
    }

    _applySlots(emit, index, event.productId, slots);
  }

  /// What a freshly-added unit on an EXISTING line should start as.
  /// A bulk product (tracksUniqueUnits == false) prints the exact
  /// same barcode on every physical copy -- think a stack of identical
  /// comic books -- so once this line already has ONE confirmed
  /// barcode, a brand new unit of it is provably that same code and
  /// doesn't need asking again. A unique-tracked product's units each
  /// carry their own distinct code, so a new one always starts
  /// pending regardless of what else is already confirmed on the
  /// line.
  CartUnitSlot _nextSlotFor(CartItem existing) {
    if (existing.tracksUniqueUnits) return const CartUnitSlot();
    for (final slot in existing.slots) {
      if (slot.isVerified) return CartUnitSlot(barcode: slot.barcode);
    }
    return const CartUnitSlot();
  }

  /// For a bulk product, every slot on the line shares the one
  /// printed barcode, so confirming it ANYWHERE on the line -- a
  /// checklist Scan/Type, or the top Scan Barcode button adding one
  /// more unit while others on the same line are still pending --
  /// marks every slot on that line verified at once, not just the one
  /// slot that triggered it. A unique-tracked product's slots are
  /// returned unchanged, since each of its units genuinely needs its
  /// own separate scan.
  List<CartUnitSlot> _verifyWholeLineIfBulk({
    required bool tracksUniqueUnits,
    required List<CartUnitSlot> slots,
    required String barcode,
  }) {
    if (tracksUniqueUnits) return slots;
    return List.generate(slots.length, (_) => CartUnitSlot(barcode: barcode));
  }

  /// Shared tail end for every "remove some slots" handler above --
  /// drops the whole line once its slot list is empty, otherwise just
  /// updates it in place.
  void _applySlots(Emitter<SalesState> emit, int index, String productId, List<CartUnitSlot> slots) {
    if (slots.isEmpty) {
      emit(state.copyWith(
        cartItems: state.cartItems.where((item) => item.productId != productId).toList(),
        isSuccess: false,
        clearError: true,
      ));
      return;
    }
    final updated = [...state.cartItems];
    updated[index] = state.cartItems[index].copyWith(slots: slots);
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

    // Every unit in the cart needs a confirmed barcode now (see
    // CartUnitSlot) -- this is the bloc-level backstop for that rule;
    // the UI also disables Complete Sale while any are pending, but
    // this guard is what actually stops the sale from going through if
    // that ever gets bypassed some other way.
    if (!state.allBarcodesVerified) {
      emit(state.copyWith(
        errorMessage: 'Scan or type the barcode for every item before completing the sale',
      ));
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
                  barcode: item.barcode,
                  unitIds: item.unitIds,
                  unitBarcodes: item.unitBarcodes,
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
        customerId: state.selectedCustomer?.id ?? '',
        customerName: state.selectedCustomer?.name ?? '',
        customerPhone: state.selectedCustomer?.phone ?? '',
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
        clearCustomer: true, // reset for the next sale, same as cart/discount above
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
