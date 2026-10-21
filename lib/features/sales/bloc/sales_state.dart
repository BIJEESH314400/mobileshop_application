import 'package:equatable/equatable.dart';

import '../../../core/models/app_user.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';

enum PaymentMethod { upi, card, cash }

/// One physical unit's spot in a cart line -- added the moment a
/// product is tapped/scanned, confirmed afterward by scanning or
/// typing its actual barcode. `barcode == null` means still pending
/// (counted toward the line/cart's qty, but not yet toward what
/// Complete Sale will actually accept). `unitId` is set only when the
/// confirmed code turned out to be a specific ProductUnit's own code
/// (see ProductUnit) rather than the product's plain shared barcode --
/// that's what SaleRepository.completeSale uses to retire the right
/// physical unit, same as before this redesign; a plain product's
/// slots are confirmed by its one shared barcode and carry no unitId
/// at all, since there's nothing more specific to retire.
class CartUnitSlot extends Equatable {
  final String? barcode;
  final String? unitId;

  const CartUnitSlot({this.barcode, this.unitId});

  bool get isVerified => barcode != null && barcode!.isNotEmpty;

  @override
  List<Object?> get props => [barcode, unitId];
}

/// One line in the cart — a snapshot of a Product plus one [CartUnitSlot]
/// per unit being sold. `availableStock` is the product's stock at the
/// moment it was added, used only to cap how many slots can be added on
/// screen; the check that actually matters happens server-side, inside
/// SaleRepository's transaction, when the sale is completed.
///
/// Every unit in a sale now needs its own confirmed barcode before
/// Complete Sale will go through (see SalesState.allBarcodesVerified) --
/// this applies uniformly to a unique-tracked product (confirmed by its
/// own per-unit code) and a plain one (confirmed by its shared product
/// barcode, scanned/typed once per physical item) alike. `qty` is
/// therefore no longer a typed/stepped number of its own -- it's always
/// just how many slots this line currently has, verified or still
/// pending.
class CartItem extends Equatable {
  final String productId;
  final String name;
  final double price;
  final int availableStock;
  final String barcode;

  // Snapshot of Product.tracksUniqueUnits at the moment this line was
  // started -- used only to pick the right hint text/placeholder in the
  // barcode checklist (e.g. "scan this unit's own sticker" vs "scan
  // this product's barcode"); the actual validation of a scanned/typed
  // code doesn't need it, since looking the code up against
  // product_units vs the product's own barcode already tells the real
  // story either way.
  final bool tracksUniqueUnits;

  final List<CartUnitSlot> slots;

  const CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.availableStock,
    this.barcode = '',
    this.tracksUniqueUnits = false,
    this.slots = const [],
  });

  int get qty => slots.length;

  int get verifiedCount => slots.where((s) => s.isVerified).length;

  int get pendingCount => qty - verifiedCount;

  bool get allVerified => pendingCount == 0;

  List<String> get unitIds =>
      slots.where((s) => s.unitId != null).map((s) => s.unitId!).toList();

  List<String> get unitBarcodes =>
      slots.where((s) => s.isVerified).map((s) => s.barcode!).toList();

  CartItem copyWith({List<CartUnitSlot>? slots}) {
    return CartItem(
      productId: productId,
      name: name,
      price: price,
      availableStock: availableStock,
      barcode: barcode,
      tracksUniqueUnits: tracksUniqueUnits,
      slots: slots ?? this.slots,
    );
  }

  double get lineTotal => price * qty;

  @override
  List<Object?> get props => [productId, name, price, availableStock, barcode, tracksUniqueUnits, slots];
}

class SalesState extends Equatable {
  final bool isLoadingProducts;
  final List<Product> availableProducts;
  final List<CartItem> cartItems;
  final String discountInput;
  final PaymentMethod paymentMethod;
  final bool isSubmitting;
  final bool isSuccess;
  final double? completedTotal;
  final String? errorMessage;

  /// Who's actually signed in and ringing up this sale -- loaded once
  /// when the screen opens (see SalesBloc._onSubscriptionRequested) and
  /// stamped onto the Sale on submit. Null only very briefly while that
  /// lookup is still in flight, or if it failed outright.
  final AppUser? currentUser;

  /// GST % actually applied below, in [tax] -- loaded once when the
  /// screen opens from TaxInvoiceSettingsRepository (same shot as
  /// [currentUser], see SalesBloc._onSubscriptionRequested) and
  /// defaults to 18 (TaxInvoiceSettings' own default) until that load
  /// finishes or if it fails outright, matching this app's long-
  /// standing 18% GST behaviour from before Tax & Invoice Settings
  /// existed. Fixed per-sale, not live -- see SaleDiscountChanged for
  /// why discount isn't either.
  final double taxRatePercent;

  /// Live customer directory for the picker sheet (see
  /// SalesCustomersSubscriptionRequested) and whichever one is picked
  /// for THIS sale -- null means walk-in/not recorded, the default,
  /// matching Sale.customerId's empty-string-as-absent convention.
  final List<Customer> availableCustomers;
  final Customer? selectedCustomer;

  const SalesState({
    this.isLoadingProducts = true,
    this.availableProducts = const [],
    this.cartItems = const [],
    this.discountInput = '',
    this.paymentMethod = PaymentMethod.upi,
    this.isSubmitting = false,
    this.isSuccess = false,
    this.completedTotal,
    this.errorMessage,
    this.currentUser,
    this.taxRatePercent = 18.0,
    this.availableCustomers = const [],
    this.selectedCustomer,
  });

  double get subtotal => cartItems.fold(0.0, (sum, item) => sum + item.lineTotal);

  /// Whatever the cashier typed into the discount field, clamped so it
  /// can never be negative or bigger than the subtotal — a stray typo
  /// like "5000" on a ₹1,000 cart shouldn't produce a negative total.
  double get discount {
    final entered = double.tryParse(discountInput.replaceAll(',', '').trim()) ?? 0;
    if (entered <= 0) return 0;
    return entered > subtotal ? subtotal : entered;
  }

  double get tax => (subtotal - discount) * (taxRatePercent / 100.0);

  double get total => subtotal - discount + tax;

  int get itemCount => cartItems.fold(0, (sum, item) => sum + item.qty);

  /// How many units across the WHOLE cart still need their barcode
  /// scanned or typed in before Complete Sale will go through.
  int get pendingBarcodeCount => cartItems.fold(0, (sum, item) => sum + item.pendingCount);

  bool get allBarcodesVerified => pendingBarcodeCount == 0;

  SalesState copyWith({
    bool? isLoadingProducts,
    List<Product>? availableProducts,
    List<CartItem>? cartItems,
    String? discountInput,
    PaymentMethod? paymentMethod,
    bool? isSubmitting,
    bool? isSuccess,
    double? completedTotal,
    String? errorMessage,
    bool clearError = false,
    AppUser? currentUser,
    double? taxRatePercent,
    List<Customer>? availableCustomers,
    Customer? selectedCustomer,
    bool clearCustomer = false,
  }) {
    return SalesState(
      isLoadingProducts: isLoadingProducts ?? this.isLoadingProducts,
      availableProducts: availableProducts ?? this.availableProducts,
      cartItems: cartItems ?? this.cartItems,
      discountInput: discountInput ?? this.discountInput,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      completedTotal: completedTotal ?? this.completedTotal,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentUser: currentUser ?? this.currentUser,
      taxRatePercent: taxRatePercent ?? this.taxRatePercent,
      availableCustomers: availableCustomers ?? this.availableCustomers,
      selectedCustomer: clearCustomer ? null : (selectedCustomer ?? this.selectedCustomer),
    );
  }

  @override
  List<Object?> get props => [
        isLoadingProducts,
        availableProducts,
        cartItems,
        discountInput,
        paymentMethod,
        isSubmitting,
        isSuccess,
        completedTotal,
        errorMessage,
        currentUser,
        taxRatePercent,
        availableCustomers,
        selectedCustomer,
      ];
}
