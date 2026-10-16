import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// One physical, individually-trackable unit of a product -- e.g. one
/// specific phone out of a batch of 12, each with its own unique code
/// instead of all 12 sharing the product's single `Product.barcode`.
///
/// A product's own barcode (see Product.barcode) still identifies the
/// *product* (the SKU) -- fine for things like chargers or cables,
/// where any one unit is interchangeable with another. A ProductUnit
/// identifies one specific physical item, for products (phones, most
/// often) where the owner wants to know exactly which unit was sold.
/// Minted in a batch by Print Barcode Labels' "Unique code per
/// sticker" toggle (see ProductUnitRepository.generateUnits); status
/// flips to 'sold' -- permanently, the code is retired and never
/// reissued -- the moment its specific label is scanned in Sales and
/// that sale is completed (see SaleRepository.completeSale).
class ProductUnit extends Equatable {
  final String id;
  final String shopId;
  final String productId;

  // Snapshot of the product's name at the moment this unit was minted,
  // same reasoning as SaleItem.name -- lets a "sold units" list show a
  // name without a second Firestore read back to (possibly
  // since-renamed-or-deleted) Product.
  final String productName;

  final String code;
  final String status; // 'available' | 'sold'
  final DateTime? createdAt;
  final DateTime? soldAt;

  // Which sale retired this unit -- '' until sold, same
  // empty-string-as-absent convention used everywhere else in this app.
  final String saleId;

  // Always true for every document in this collection -- a
  // ProductUnit only ever exists because something minted one unique
  // code for it, there's no "not unique" variant stored here. Stored
  // explicitly anyway (rather than left implicit in "which collection
  // is this doc in") so that reading one unit's raw data on its own --
  // in the Firebase console, in a future report, in a stray Firestore
  // query -- is self-describing, without needing to already know this
  // collection's own meaning first.
  final bool isUniqueCode;

  const ProductUnit({
    required this.id,
    required this.shopId,
    required this.productId,
    required this.productName,
    required this.code,
    this.status = 'available',
    this.createdAt,
    this.soldAt,
    this.saleId = '',
    this.isUniqueCode = true,
  });

  bool get isAvailable => status == 'available';

  factory ProductUnit.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    final rawSoldAt = map['soldAt'];
    return ProductUnit(
      id: id,
      shopId: map['shopId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      code: map['code'] as String? ?? '',
      status: map['status'] as String? ?? 'available',
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
      soldAt: rawSoldAt is Timestamp ? rawSoldAt.toDate() : null,
      saleId: map['saleId'] as String? ?? '',
      isUniqueCode: map['isUniqueCode'] as bool? ?? true,
    );
  }

  /// What gets written on first creation (see
  /// ProductUnitRepository.generateUnits) -- always starts 'available'
  /// with no soldAt/saleId yet, so this doesn't take those as
  /// parameters the way Product/Sale's toMap() don't need to handle an
  /// "already sold" case on first write either.
  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'productId': productId,
      'productName': productName,
      'code': code,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'soldAt': null,
      'saleId': saleId,
      'isUniqueCode': isUniqueCode,
    };
  }

  @override
  List<Object?> get props =>
      [id, shopId, productId, productName, code, status, createdAt, soldAt, saleId, isUniqueCode];
}
