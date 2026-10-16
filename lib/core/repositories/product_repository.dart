import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';

/// The only place in the app that talks to the `products` Firestore
/// collection directly. Screens/Blocs go through this instead of
/// calling `FirebaseFirestore.instance` themselves, so if the storage
/// details ever change, this is the one file to touch.
class ProductRepository {
  final FirebaseFirestore _db;

  ProductRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _products => _db.collection('products');

  // Read directly here rather than going through ProductUnitRepository
  // -- that repository already depends on this one (for findByBarcode,
  // see ProductUnitRepository.generateUnits), so taking a dependency
  // the other way round too would make the two repositories construct
  // each other. A plain two-field-equality read of one collection
  // doesn't need a whole repository class to do it safely.
  CollectionReference<Map<String, dynamic>> get _units => _db.collection('product_units');

  /// A live list of this shop's products, newest first, that updates
  /// automatically whenever a product is added/changed elsewhere —
  /// that's what makes this a Stream instead of a one-time fetch.
  ///
  /// Filtering (`shopId`) happens server-side, but sorting happens here
  /// in Dart on purpose: combining a `where` with an `orderBy` on a
  /// different field needs a Firestore "composite index" to be created
  /// first (a manual step in the console, with a broken query in the
  /// meantime) — not worth it for a product list small enough that
  /// sorting a few dozen items client-side costs nothing noticeable.
  Stream<List<Product>> watchProducts({required String shopId}) {
    return _products.where('shopId', isEqualTo: shopId).snapshots().map((snapshot) {
      final products = snapshot.docs.map((doc) => Product.fromMap(doc.id, doc.data())).toList();
      products.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime); // newest first
      });
      return products;
    });
  }

  /// Creates a new product document and returns it back with its real
  /// Firestore id and (if one wasn't typed/scanned in) its freshly
  /// generated barcode filled in, so the caller can show it to the
  /// person right after Save.
  ///
  /// Uses `_products.doc()` (pre-allocates an id client-side, the same
  /// Firestore-generated random id `.add()` would have used) instead of
  /// `.add()` so the new document has a real id to write in one shot,
  /// same as before. The barcode itself no longer comes from that id
  /// (see `_generateInternalBarcode`'s own doc comment for why).
  Future<Product> addProduct(Product product) async {
    final docRef = _products.doc();
    final barcode = product.barcode.trim().isEmpty
        ? await _generateInternalBarcode(shopId: product.shopId)
        : product.barcode.trim();

    final toSave = Product(
      id: docRef.id,
      name: product.name,
      category: product.category,
      brand: product.brand,
      price: product.price,
      stockQty: product.stockQty,
      sku: product.sku,
      condition: product.condition,
      description: product.description,
      shopId: product.shopId,
      barcode: barcode,
    );
    await docRef.set(toSave.toMap());
    return toSave;
  }

  /// Updates an existing product document in place, and returns the
  /// saved product back (mirroring `addProduct`) so a caller can see
  /// its final barcode. Deliberately drops `createdAt` from the map
  /// first -- `toMap()` stamps it with `FieldValue.serverTimestamp()`,
  /// which is correct for a brand-new product but would silently reset
  /// the original creation time (and therefore its position in
  /// "newest first" lists) every time someone just fixes a typo or
  /// updates the stock count.
  ///
  /// Also mints a barcode here if `product.barcode` is still blank --
  /// covers products saved before the Barcode field existed: simply
  /// opening one and tapping Save (without touching Barcode at all)
  /// gives it a real, reusable barcode, same as a brand-new product
  /// gets one on its first Save.
  Future<Product> updateProduct(String id, Product product) async {
    final barcode = product.barcode.trim().isEmpty
        ? await _generateInternalBarcode(shopId: product.shopId)
        : product.barcode.trim();
    final toSave = Product(
      id: id,
      name: product.name,
      category: product.category,
      brand: product.brand,
      price: product.price,
      stockQty: product.stockQty,
      sku: product.sku,
      condition: product.condition,
      description: product.description,
      shopId: product.shopId,
      barcode: barcode,
    );
    final data = toSave.toMap()..remove('createdAt');
    await _products.doc(id).update(data);
    return toSave;
  }

  /// Permanently removes a product. There's no undo -- the caller is
  /// responsible for confirming with the person first.
  Future<void> deleteProduct(String id) {
    return _products.doc(id).delete();
  }

  /// The one and only place that writes `Product.tracksUniqueUnits` --
  /// called from the Barcode Labels screen whenever the owner actually
  /// flips the "Unique code per sticker" toggle for a product, so it's
  /// remembered the next time that screen opens. A plain single-field
  /// `.update()`, not a full `updateProduct()` round-trip, so this
  /// can't accidentally touch (or regenerate a barcode for) anything
  /// else on the product -- see Product.toMap()'s own comment for why
  /// this field is deliberately excluded from that normal save path.
  Future<void> setTracksUniqueUnits(String id, bool value) {
    return _products.doc(id).update({'tracksUniqueUnits': value});
  }

  /// Looks up a single product by its barcode, scoped to one shop --
  /// this is what lets Add Product (and, later, Sales/POS) tell "this
  /// barcode is already one of our products" apart from "never seen
  /// this one before, treat it as new". Both filters here are plain
  /// equality (`isEqualTo`), so this doesn't need a composite index
  /// created in the Firebase console -- Firestore covers combinations of
  /// equality-only filters with its automatic single-field indexes.
  Future<Product?> findByBarcode(String barcode, {required String shopId}) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return null;
    final snapshot =
        await _products.where('shopId', isEqualTo: shopId).where('barcode', isEqualTo: trimmed).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return Product.fromMap(doc.id, doc.data());
  }

  /// Generates a short, random, all-digit barcode and confirms (via
  /// `findByBarcode`) that this shop doesn't already have a product
  /// using it, retrying a few times on the astronomically unlikely
  /// chance of a clash.
  ///
  /// The first version of this reused the product's own ~20-character
  /// Firestore document id (prefixed "4B") -- simple and free of any
  /// collision risk, but it turned out to scan unreliably in practice:
  /// a camera (especially scanning a shared/recompressed photo of a
  /// label rather than the original print) struggles with how thin the
  /// bars have to get to fit 20+ alphanumeric characters into a small
  /// sticker. A 10-digit numeric code needs roughly half as many bars
  /// for the same physical width -- the same reason real retail
  /// barcodes (EAN/UPC) are all-digit rather than alphanumeric -- which
  /// is the single biggest lever for real-world scan reliability at
  /// sticker size. The tiny bit of added latency (one extra Firestore
  /// read, only when Barcode was left blank) is worth it for that.
  Future<String> _generateInternalBarcode({required String shopId}) async {
    final random = Random();
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = List.generate(10, (_) => random.nextInt(10)).join();
      final existingProduct = await findByBarcode(code, shopId: shopId);
      if (existingProduct != null) continue;
      // Also checked against ProductUnit codes (see ProductUnit) --
      // this plain all-digit barcode scheme and the OLD plain
      // all-digit unit-code scheme shared one numeric namespace, so a
      // brand-new product could never be assigned a number an
      // already-printed phone sticker was using. Unit codes generated
      // today (see ProductUnitRepository.generateUnits) look like
      // "SP-SAM-00000001" -- letters and dashes, not plain digits --
      // so a fresh code from here structurally can't collide with one
      // of those; this check is kept only for products added while
      // any unit codes from before that change are still around.
      final existingUnit = await _units
          .where('shopId', isEqualTo: shopId)
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      if (existingUnit.docs.isEmpty) return code;
    }
    // Essentially unreachable (a 1-in-10-billion clash, five times in a
    // row) -- falls back to the old scheme, which stays guaranteed
    // unique even here since it's derived from a fresh Firestore id.
    return '4B${_products.doc().id}';
  }
}
