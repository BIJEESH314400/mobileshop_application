import 'package:equatable/equatable.dart';

import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import 'sales_state.dart';

sealed class SalesEvent extends Equatable {
  const SalesEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the Sales screen opens — starts a live subscription
/// to this shop's products (used to fill the "Add Product" picker),
/// the same way ProductsSubscriptionRequested does for Products.
class SalesSubscriptionRequested extends SalesEvent {
  const SalesSubscriptionRequested();
}

/// Fired when a product is picked from the "Add Product" sheet. Adds
/// it to the cart at qty 1, or increments its qty if it's already
/// there — capped either way at that product's current stock.
class SaleItemAdded extends SalesEvent {
  final Product product;
  const SaleItemAdded(this.product);

  @override
  List<Object?> get props => [product];
}

/// +/- from a cart item's qty steppers. `delta` is +1 or -1.
class SaleItemQtyChanged extends SalesEvent {
  final String productId;
  final int delta;
  const SaleItemQtyChanged({required this.productId, required this.delta});

  @override
  List<Object?> get props => [productId, delta];
}

class SaleItemRemoved extends SalesEvent {
  final String productId;
  const SaleItemRemoved(this.productId);

  @override
  List<Object?> get props => [productId];
}

/// Raw text from the discount field, parsed/clamped in SalesState —
/// lets the cashier type a custom discount per sale instead of the
/// flat amount the placeholder used to hardcode.
class SaleDiscountChanged extends SalesEvent {
  final String discount;
  const SaleDiscountChanged(this.discount);

  @override
  List<Object?> get props => [discount];
}

class SalePaymentMethodChanged extends SalesEvent {
  final PaymentMethod method;
  const SalePaymentMethodChanged(this.method);

  @override
  List<Object?> get props => [method];
}

/// Fired once when the Sales screen opens, alongside
/// SalesSubscriptionRequested — starts a SEPARATE, concurrent live
/// subscription to this shop's customer directory (used to fill the
/// customer picker sheet), same two-concurrent-streams-in-one-Bloc
/// pattern ConversationBloc already uses for its typing indicator.
class SalesCustomersSubscriptionRequested extends SalesEvent {
  const SalesCustomersSubscriptionRequested();
}

/// Fired from the customer picker sheet. `customer` null means
/// "cleared back to walk-in" -- see CustomerPickerResult's own doc
/// comment for why a bare nullable field on its own can't express
/// that (vs. "sheet closed with no change", which just doesn't fire
/// this event at all).
class SaleCustomerSelected extends SalesEvent {
  final Customer? customer;
  const SaleCustomerSelected(this.customer);

  @override
  List<Object?> get props => [customer];
}

/// Fired when "Complete Sale" is tapped.
class SaleSubmitted extends SalesEvent {
  const SaleSubmitted();
}
