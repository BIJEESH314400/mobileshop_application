import 'package:equatable/equatable.dart';

import '../../../core/models/product.dart';

enum PaymentMethod { upi, card, cash }

/// One line in the cart — a snapshot of a Product plus how many of it
/// are being sold. `availableStock` is the product's stock at the
/// moment it was added, used only to cap the qty stepper on screen;
/// the check that actually matters happens server-side, inside
/// SaleRepository's transaction, when the sale is completed.
class CartItem extends Equatable {
  final String productId;
  final String name;
  final double price;
  final int qty;
  final int availableStock;

  const CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.qty,
    required this.availableStock,
  });

  CartItem copyWith({int? qty}) {
    return CartItem(
      productId: productId,
      name: name,
      price: price,
      qty: qty ?? this.qty,
      availableStock: availableStock,
    );
  }

  double get lineTotal => price * qty;

  @override
  List<Object?> get props => [productId, name, price, qty, availableStock];
}

class SalesState extends Equatable {
  /// Fixed for now — see SaleDiscountChanged for why discount isn't.
  static const double taxRate = 0.18;

  final bool isLoadingProducts;
  final List<Product> availableProducts;
  final List<CartItem> cartItems;
  final String discountInput;
  final PaymentMethod paymentMethod;
  final bool isSubmitting;
  final bool isSuccess;
  final double? completedTotal;
  final String? errorMessage;

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

  double get tax => (subtotal - discount) * taxRate;

  double get total => subtotal - discount + tax;

  int get itemCount => cartItems.fold(0, (sum, item) => sum + item.qty);

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
      ];
}
