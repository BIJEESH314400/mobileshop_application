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

  /// Creates a new product document. Firestore assigns the document id
  /// automatically — the `id` field on the `Product` passed in isn't
  /// used for anything here.
  Future<void> addProduct(Product product) {
    return _products.add(product.toMap());
  }

  /// Updates an existing product document in place. Deliberately drops
  /// `createdAt` from the map first -- `toMap()` stamps it with
  /// `FieldValue.serverTimestamp()`, which is correct for a brand-new
  /// product but would silently reset the original creation time (and
  /// therefore its position in "newest first" lists) every time someone
  /// just fixes a typo or updates the stock count.
  Future<void> updateProduct(String id, Product product) {
    final data = product.toMap()..remove('createdAt');
    return _products.doc(id).update(data);
  }
}
