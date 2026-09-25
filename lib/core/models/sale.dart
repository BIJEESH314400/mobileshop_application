import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// One item sold within a Sale — a snapshot of a Product's name/price
/// at the moment it was sold, plus how many. Kept separate from
/// Product on purpose: if a product's price changes later, past sales
/// should still show what was actually charged at the time.
class SaleItem extends Equatable {
  final String productId;
  final String name;
  final double price;
  final int qty;

  const SaleItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.qty,
  });

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      productId: map['productId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      qty: (map['qty'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'qty': qty,
    };
  }

  double get lineTotal => price * qty;

  @override
  List<Object?> get props => [productId, name, price, qty];
}

/// One row in the `sales` Firestore collection. Writing this document
/// and decrementing each item's product stock happen together in a
/// single Firestore transaction — see SaleRepository.completeSale —
/// so a sale is never recorded with only some of the stock adjusted.
class Sale extends Equatable {
  final String id;
  final String shopId;
  final List<SaleItem> items;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String paymentMethod; // 'upi' | 'card' | 'cash'
  final DateTime? createdAt;

  // Who actually rang up this sale -- the owner, or a specific employee.
  // Snapshotted at sale time (name/role, not just a uid) for the same
  // reason SaleItem snapshots product name/price: if that employee's
  // name or account ever changes later, this sale should still show who
  // it really was at the time, without a second Firestore read to look
  // them up. soldByUid is kept alongside for anything that ever needs
  // to link back to the real account (e.g. per-employee sales figures).
  final String soldByUid;
  final String soldByName;
  final String soldByRole; // 'owner' | 'employee'

  // Which customer this sale was rung up for -- optional, added
  // 2026-09-24 alongside the Customers screen. Empty/'' means "walk-in
  // / not recorded", same empty-string-as-absent convention as
  // soldByName above -- every sale completed before this field existed
  // reads back the same way rather than needing a separate null check
  // everywhere. customerName/customerPhone are snapshotted at sale
  // time (same reasoning as soldByName/SaleItem's price snapshot): if
  // the customer's saved name/phone changes later, this sale still
  // shows what it really was at the time.
  final String customerId;
  final String customerName;
  final String customerPhone;

  const Sale({
    required this.id,
    required this.shopId,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    this.createdAt,
    this.soldByUid = '',
    this.soldByName = '',
    this.soldByRole = 'owner',
    this.customerId = '',
    this.customerName = '',
    this.customerPhone = '',
  });

  factory Sale.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    final rawItems = map['items'] as List<dynamic>? ?? const [];
    return Sale(
      id: id,
      shopId: map['shopId'] as String? ?? '',
      items: rawItems
          .map((item) => SaleItem.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0,
      tax: (map['tax'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      paymentMethod: map['paymentMethod'] as String? ?? 'cash',
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
      // Empty/'' for any sale recorded before this field existed --
      // the UI treats an empty soldByName as "not recorded" rather than
      // guessing who it might have been.
      soldByUid: map['soldByUid'] as String? ?? '',
      soldByName: map['soldByName'] as String? ?? '',
      soldByRole: map['soldByRole'] as String? ?? 'owner',
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      customerPhone: map['customerPhone'] as String? ?? '',
    );
  }

  /// What gets written to Firestore on Complete Sale. `createdAt` uses
  /// `FieldValue.serverTimestamp()` for the same reason Product does —
  /// so reports sort by Firebase's clock, not the phone's.
  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'paymentMethod': paymentMethod,
      'createdAt': FieldValue.serverTimestamp(),
      'soldByUid': soldByUid,
      'soldByName': soldByName,
      'soldByRole': soldByRole,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
    };
  }

  @override
  List<Object?> get props => [
        id,
        shopId,
        items,
        subtotal,
        discount,
        tax,
        total,
        paymentMethod,
        createdAt,
        soldByUid,
        soldByName,
        soldByRole,
        customerId,
        customerName,
        customerPhone,
      ];
}
