import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_unit.dart';
import '../utils/code_short_name.dart';

/// The only place in the app that talks to the `product_units`
/// Firestore collection -- one document per physically-labeled,
/// individually-trackable unit (see ProductUnit's own doc comment for
/// what that means and why it exists alongside Product.barcode rather
/// than replacing it).
class ProductUnitRepository {
  final FirebaseFirestore _db;

  ProductUnitRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _units => _db.collection('product_units');

  // One running-count document per (shop, category-code, brand-code)
  // combination -- e.g. every "Smart Phone / Samsung" unit this shop
  // has ever minted, across every print run, shares one counter. See
  // generateUnits' own doc comment for what it's used for.
  CollectionReference<Map<String, dynamic>> get _counters => _db.collection('product_unit_counters');

  /// Looks up one unit by its code, scoped to a shop -- same plain
  /// two-field-equality shape as ProductRepository.findByBarcode, so
  /// this doesn't need a composite index created in the Firebase
  /// console either.
  Future<ProductUnit?> findByCode(String code, {required String shopId}) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;
    final snapshot =
        await _units.where('shopId', isEqualTo: shopId).where('code', isEqualTo: trimmed).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return ProductUnit.fromMap(doc.id, doc.data());
  }

  /// Generates `count` fresh, individually-unique codes for one
  /// product and saves them all as new 'available' units -- what
  /// Print Barcode Labels' "Unique code per sticker" toggle calls
  /// before building the PDF. Every call mints brand-new codes; it
  /// never reuses or reprints an existing unit's code, same as a fresh
  /// print run always meaning newly-arrived physical stock.
  ///
  /// Each code reads as `<category>-<brand>-<8-digit sequence>`, e.g.
  /// "SP-SAM-00000001" -- the category/brand letters come from
  /// `codeShortName` ('XXX' standing in for a blank brand), and the
  /// digits are a running count kept per (shop, category, brand) in
  /// `product_unit_counters`, incremented one at a time inside a
  /// Firestore transaction together with the new unit document itself
  /// -- so the counter and the unit it names either both get written
  /// or neither does, and two devices minting units for the same
  /// category+brand at the same moment can never be handed the same
  /// number. That transactional increment is what guarantees
  /// uniqueness now, so unlike the old plain-random scheme this never
  /// needs a collision-retry loop or an "essentially unreachable"
  /// fallback -- and since every code now starts with letters and
  /// dashes, it can't collide with a plain all-digit product barcode
  /// either (no need to separately check findByBarcode for that).
  Future<List<ProductUnit>> generateUnits({
    required String shopId,
    required String productId,
    required String productName,
    required String category,
    required String brand,
    required int count,
  }) async {
    final categoryCode = codeShortName(category).isEmpty ? 'GEN' : codeShortName(category);
    final brandCode = brand.trim().isEmpty ? 'XXX' : codeShortName(brand);
    final counterRef = _counters.doc('$shopId-$categoryCode-$brandCode');

    final units = <ProductUnit>[];
    for (var i = 0; i < count; i++) {
      final unit = await _db.runTransaction<ProductUnit>((txn) async {
        final counterSnapshot = await txn.get(counterRef);
        final next = ((counterSnapshot.data()?['lastValue'] as num?)?.toInt() ?? 0) + 1;
        final code = '$categoryCode-$brandCode-${next.toString().padLeft(8, '0')}';

        final ref = _units.doc();
        final newUnit = ProductUnit(
          id: ref.id,
          shopId: shopId,
          productId: productId,
          productName: productName,
          code: code,
        );

        txn.set(
          counterRef,
          {
            'shopId': shopId,
            'categoryCode': categoryCode,
            'brandCode': brandCode,
            'lastValue': next,
          },
          SetOptions(merge: true),
        );
        txn.set(ref, newUnit.toMap());
        return newUnit;
      });
      units.add(unit);
    }

    return units;
  }
}
