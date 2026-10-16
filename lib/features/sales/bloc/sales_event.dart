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

/// Fired when a product is tapped in the "Add Product" sheet, or the
/// cart card's own "+" -- adds ONE new, still-unverified (pending)
/// unit slot to this product's line (starting a new line at qty 1 if
/// it isn't in the cart yet), capped at the product's current stock.
/// Works the same for every product now, unique-tracked or not -- see
/// Product.tracksUniqueUnits's own doc comment for why that
/// distinction no longer needs to gate adding at all, only how a
/// slot's barcode later gets verified (SaleItemSlotVerified below).
class SaleItemAdded extends SalesEvent {
  final Product product;
  const SaleItemAdded(this.product);

  @override
  List<Object?> get props => [product];
}

/// Fired by the top "Scan Barcode" button once the View has already
/// looked the scanned code up (see `_resolveBarcode` in
/// sales_screen.dart) and confirmed a real match -- adds the product
/// to the cart (or grows its line) with that ONE slot already
/// verified, since a real scan just happened; no separate pending step
/// needed for it. `unitId` is set only when the match was a specific
/// ProductUnit's own code rather than the product's shared barcode.
class SaleItemScannedAdded extends SalesEvent {
  final Product product;
  final String barcode;
  final String? unitId;
  const SaleItemScannedAdded({required this.product, required this.barcode, this.unitId});

  @override
  List<Object?> get props => [product, barcode, unitId];
}

/// The cart card's "-" -- drops the single most-recently-added slot
/// from this product's line (a still-pending one if there is one,
/// since nothing confirmed is lost by undoing an unconfirmed add;
/// otherwise the last verified one). Removes the whole line once its
/// last slot is gone, same as SaleItemRemoved.
class SaleItemUnitRemoved extends SalesEvent {
  final String productId;
  const SaleItemUnitRemoved(this.productId);

  @override
  List<Object?> get props => [productId];
}

/// A specific pending slot's barcode, already resolved and validated
/// by the View (see `_resolveBarcode`) -- fills that one slot in,
/// whether it came from the camera (the slot's own Scan button) or the
/// cashier typing it by hand (Type). `unitId` is set only for a real
/// per-unit code, same as SaleItemScannedAdded above.
class SaleItemSlotVerified extends SalesEvent {
  final String productId;
  final int slotIndex;
  final String barcode;
  final String? unitId;
  const SaleItemSlotVerified({
    required this.productId,
    required this.slotIndex,
    required this.barcode,
    this.unitId,
  });

  @override
  List<Object?> get props => [productId, slotIndex, barcode, unitId];
}

/// The "ITEM BARCODES" checklist's own "Remove" link on one specific
/// unit row -- drops exactly that slot (verified or still pending),
/// which also drops this line's qty by 1, same as the screen's own
/// "removing a barcode updates the item's quantity automatically" note.
class SaleItemSlotRemoved extends SalesEvent {
  final String productId;
  final int slotIndex;
  const SaleItemSlotRemoved({required this.productId, required this.slotIndex});

  @override
  List<Object?> get props => [productId, slotIndex];
}

/// Quick "-1" / "-2" shortcut on a cart card -- removes that many of
/// the line's most-recently-added slots in one tap (same end result as
/// tapping SaleItemUnitRemoved that many times in a row, preferring
/// still-pending slots first, same as that event).
class SaleItemQuickRemove extends SalesEvent {
  final String productId;
  final int count;
  const SaleItemQuickRemove({required this.productId, required this.count});

  @override
  List<Object?> get props => [productId, count];
}

/// The cart card's trash icon (or the barcode checklist's own "Delete
/// all N" shortcut) -- removes the entire line, every slot at once.
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
