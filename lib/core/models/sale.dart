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

  // The product's barcode at sale time -- same snapshot reasoning as
  // name/price above, plus it means a receipt/Sales History row can
  // show or search by barcode without a second Firestore read back to
  // the (possibly since-edited-or-deleted) product. Empty for any sale
  // completed before this field existed, or for a product that never
  // had a barcode -- same empty-string-as-absent convention used
  // everywhere else in this app.
  final String barcode;

  // Which ProductUnit.id's this line retired, if any -- e.g. 2 of
  // this line's 5 qty were specific individually-tracked units (see
  // ProductUnit's own doc comment), scanned by their own unique codes
  // rather than picked generically. Empty for a normal sale -- the
  // vast majority -- where nothing here needed per-unit tracking.
  // SaleRepository.completeSale marks every id here 'sold' in the same
  // transaction that writes this Sale, so a unit's code is retired for
  // good the moment the sale that used it actually goes through.
  final List<String> unitIds;

  // The confirmed barcode for every single unit in this line, in the
  // order they were verified -- one entry per unit sold (length ==
  // qty once a sale actually goes through, since Complete Sale is
  // blocked until every slot in the cart is verified). For a unit
  // backed by a real ProductUnit (see unitIds above), the matching
  // entry here is that unit's own code; for a plain product with no
  // per-unit tracking, it's the product's shared barcode, confirmed
  // once per physical item scanned/typed at sale time. Empty for any
  // sale completed before this per-unit confirmation flow existed --
  // `barcode` above (the product-level snapshot) is all those older
  // sales have.
  final List<String> unitBarcodes;

  const SaleItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.qty,
    this.barcode = '',
    this.unitIds = const [],
    this.unitBarcodes = const [],
  });

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    final rawUnitIds = map['unitIds'] as List<dynamic>? ?? const [];
    final rawUnitBarcodes = map['unitBarcodes'] as List<dynamic>? ?? const [];
    return SaleItem(
      productId: map['productId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      qty: (map['qty'] as num?)?.toInt() ?? 0,
      barcode: map['barcode'] as String? ?? '',
      unitIds: rawUnitIds.map((id) => id as String).toList(),
      unitBarcodes: rawUnitBarcodes.map((code) => code as String).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'qty': qty,
      'barcode': barcode,
      'unitIds': unitIds,
      'unitBarcodes': unitBarcodes,
    };
  }

  double get lineTotal => price * qty;

  @override
  List<Object?> get props => [productId, name, price, qty, barcode, unitIds, unitBarcodes];
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
