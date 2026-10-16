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

  // Whether this product's print runs should default to "Unique code
  // per sticker" being ON (see BarcodeLabelsScreen). Read-only from
  // this model's own toMap() -- see the comment there for why -- and
  // only ever written by ProductRepository.setTracksUniqueUnits,
  // called from the Barcode Labels screen itself when the owner
  // actually changes the toggle. Defaults to true (both here and when
  // reading a document that doesn't have this field yet) because
  // every product this screen can print for benefits from per-unit
  // tracking unless the owner opts a specific one out, not the other
  // way around.
  final bool tracksUniqueUnits;

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
    this.tracksUniqueUnits = true,
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
      // Missing (every product saved before this field existed, and
      // every product never touched on Barcode Labels since) reads as
      // true -- see this field's own doc comment above for why "not
      // set yet" means "on" here, unlike barcode/sku's "not set yet"
      // meaning blank.
      tracksUniqueUnits: map['tracksUniqueUnits'] as bool? ?? true,
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
      // tracksUniqueUnits is deliberately NOT written here. Add
      // Product's form knows nothing about this field and always
      // builds a fresh Product with it left at its default (true) --
      // if toMap() included it, every ordinary product edit (fixing a
      // price, restocking) would silently stomp the owner's actual
      // saved preference back to true. Only
      // ProductRepository.setTracksUniqueUnits writes this field, and
      // only the Barcode Labels screen calls it.
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
        tracksUniqueUnits,
      ];
}
