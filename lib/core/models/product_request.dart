import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// One row in the `productRequests` Firestore collection -- a record
/// that a specific customer wants a specific item the shop couldn't
/// hand over right away, so staff can order it from the supplier and
/// come back to this customer once it's in. Added 2026-10-07 to close
/// the gap flagged by the shop owner: previously, trying to add an
/// out-of-stock product in Sales just said "Out of Stock" and nothing
/// else -- the customer's request itself was never saved anywhere, so
/// staff had to remember it on paper.
///
/// **`productId` is deliberately optional (2026-10-07 revision).** The
/// first version required picking a real catalog `Product`, which
/// meant the owner had to add a throwaway Product entry just to mark
/// something out of stock, for an item the shop doesn't normally
/// carry at all (the owner already knows "we don't have Titan
/// watches" without the app telling them) -- real-world example the
/// owner gave. So a request can now stand entirely on its own: just a
/// typed `productName`, no catalog entry required. `productId` stays
/// set only for the other, still-supported path -- logging a request
/// straight from the Sales picker for an item that IS in the catalog
/// and genuinely at zero stock.
class ProductRequest extends Equatable {
  final String id;
  final String shopId;
  final String? productId;
  final String productName;
  final int quantity;
  /// Links back to a real `customers/{id}` document -- added
  /// 2026-10-07 alongside the Add Request screen's switch from a
  /// free-typed name to the same pick-existing-or-add-new customer
  /// picker Sales/Service Jobs already use, so "who's waiting" is a
  /// real linked customer, not just a name that might not match
  /// anything in the directory. Empty for requests saved before this
  /// change.
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String note;
  final bool fulfilled;
  final DateTime? createdAt;
  final DateTime? fulfilledAt;

  const ProductRequest({
    required this.id,
    required this.shopId,
    this.productId,
    required this.productName,
    this.quantity = 1,
    this.customerId = '',
    required this.customerName,
    this.customerPhone = '',
    this.note = '',
    this.fulfilled = false,
    this.createdAt,
    this.fulfilledAt,
  });

  factory ProductRequest.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    final rawFulfilledAt = map['fulfilledAt'];
    return ProductRequest(
      id: id,
      shopId: map['shopId'] as String? ?? '',
      productId: map['productId'] as String?,
      productName: map['productName'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      customerPhone: map['customerPhone'] as String? ?? '',
      note: map['note'] as String? ?? '',
      fulfilled: map['fulfilled'] as bool? ?? false,
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
      fulfilledAt: rawFulfilledAt is Timestamp ? rawFulfilledAt.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'note': note,
      'fulfilled': fulfilled,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        shopId,
        productId,
        productName,
        quantity,
        customerId,
        customerName,
        customerPhone,
        note,
        fulfilled,
        createdAt,
        fulfilledAt,
      ];
}
