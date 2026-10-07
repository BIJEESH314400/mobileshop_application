import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_request.dart';

/// The only place in the app that talks to the `productRequests`
/// Firestore collection directly -- same single-point-of-contact
/// convention as ProductRepository/CustomerRepository.
class ProductRequestRepository {
  final FirebaseFirestore _db;

  ProductRequestRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _requests => _db.collection('productRequests');

  /// A live list of this shop's still-waiting requests (not yet
  /// fulfilled), newest first. Same "filter server-side on shopId,
  /// sort client-side" shape ProductRepository.watchProducts already
  /// uses -- avoids needing a composite index for a list this small.
  Stream<List<ProductRequest>> watchWaitingRequests({required String shopId}) {
    return _requests
        .where('shopId', isEqualTo: shopId)
        .where('fulfilled', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs.map((doc) => ProductRequest.fromMap(doc.id, doc.data())).toList();
      requests.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime); // newest first
      });
      return requests;
    });
  }

  /// Saves a new "customer waiting for this item" request.
  ///
  /// `productId` is optional (2026-10-07) -- most requests are logged
  /// straight from the "Waiting Customers" screen's own "+ Add
  /// Request" button, for an item that was never added to the
  /// Products catalog at all (the owner already knows it's not
  /// something the shop carries, no need to create a dummy Product
  /// just to say so). It's only ever set when this comes from the
  /// Sales screen's product picker instead, for a catalog item that's
  /// genuinely at zero stock.
  Future<void> addRequest({
    required String shopId,
    String? productId,
    required String productName,
    int quantity = 1,
    String customerId = '',
    required String customerName,
    String customerPhone = '',
    String note = '',
  }) {
    return _requests.add({
      'shopId': shopId,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'note': note,
      'fulfilled': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Marks a request fulfilled once staff has restocked the product
  /// and handed it over (or called the customer, however it actually
  /// played out) -- a deliberately separate, narrow write rather than
  /// a general `updateRequest`, same reasoning ServiceJobRepository's
  /// `completeJob` is its own method instead of reusing `updateJob`.
  Future<void> markFulfilled(String id) {
    return _requests.doc(id).update({
      'fulfilled': true,
      'fulfilledAt': FieldValue.serverTimestamp(),
    });
  }
}
