import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shop_details.dart';

/// Reads/writes the one `shopDetails/{shopId}` document for this shop
/// — owner-only, enforced by `firestore.rules`, not just by this
/// screen's own `OwnerOnlyGate` wrapper. A one-shot read (like
/// `UsernameLookupRepository`, not a live stream) is enough here —
/// this isn't data that changes while someone's looking at it the way
/// a live sales/chat feed would.
class ShopDetailsRepository {
  final FirebaseFirestore _db;

  ShopDetailsRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _shopDetails => _db.collection('shopDetails');

  Future<ShopDetails> getShopDetails(String shopId) async {
    final doc = await _shopDetails.doc(shopId).get();
    return ShopDetails.fromMap(doc.data());
  }

  Future<void> saveShopDetails(String shopId, ShopDetails details) {
    return _shopDetails.doc(shopId).set(details.toMap(), SetOptions(merge: true));
  }
}
