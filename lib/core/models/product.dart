import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// One row in the `products` Firestore collection — matches the Add
/// Product form field-for-field, plus two fields the form doesn't show:
/// `shopId` (which branch this belongs to) and `createdAt` (so lists can
/// be sorted newest-first).
class Product extends Equatable {
  final String id;
  final String name;
  final String category;
  final String brand;
  final double price;
  final int stockQty;
  final String sku;
  final String condition; // 'New' | 'Refurbished' | 'Used'
  final String description;
  final String shopId;
  final DateTime? createdAt;

  /// This product's barcode — either scanned from a real product
  /// package, or an internally-generated one for products that don't
  /// come with their own (see `ProductRepository.addProduct`). Defaults
  /// to '' so every place that already constructs a `Product` without
  /// knowing about this field keeps compiling unchanged; '' means "no
  /// barcode yet", same convention as an empty `sku`.
  final String barcode;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.brand,
    required this.price,
    required this.stockQty,
    required this.sku,
    required this.condition,
    required this.description,
    required this.shopId,
    this.createdAt,
    this.barcode = '',
  });

  /// Builds a Product from a Firestore document. `id` comes from
  /// `doc.id` separately, since a document's own id isn't one of its
  /// stored fields.
  factory Product.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    return Product(
      id: id,
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? '',
      brand: map['brand'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      stockQty: (map['stockQty'] as num?)?.toInt() ?? 0,
      sku: map['sku'] as String? ?? '',
      condition: map['condition'] as String? ?? 'New',
      description: map['description'] as String? ?? '',
      shopId: map['shopId'] as String? ?? '',
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
      // Older product documents, saved before this field existed, simply
      // don't have it -- '' is the correct read for those, same
      // "missing means not set yet" convention as every other field here.
      barcode: map['barcode'] as String? ?? '',
    );
  }

  /// What gets written to Firestore on Save. `createdAt` uses
  /// `FieldValue.serverTimestamp()` rather than `DateTime.now()` so the
  /// time is set by Firebase's own clock, not the phone's (which could
  /// be wrong) — standard practice for anything used to sort/report on
  /// later.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'brand': brand,
      'price': price,
      'stockQty': stockQty,
      'sku': sku,
      'condition': condition,
      'description': description,
      'shopId': shopId,
      'createdAt': FieldValue.serverTimestamp(),
      'barcode': barcode,
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        category,
        brand,
        price,
        stockQty,
        sku,
        condition,
        description,
        shopId,
        createdAt,
        barcode,
      ];
}
