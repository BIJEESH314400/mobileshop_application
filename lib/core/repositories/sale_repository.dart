import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sale.dart';

/// Thrown when a sale can't go through because a product's stock
/// changed between it being added to the cart and "Complete Sale"
/// being tapped (e.g. someone else on another device sold the last
/// unit first). The message is written in plain language because it's
/// shown to the cashier as-is.
class InsufficientStockException implements Exception {
  final String message;
  const InsufficientStockException(this.message);

  @override
  String toString() => message;
}

/// The only place in the app that talks to the `sales` Firestore
/// collection. Writing the sale document and decrementing every sold
/// product's stock happen inside one Firestore transaction, so a sale
/// can never be recorded with only some of the stock adjusted — either
/// both succeed, or neither does and the cashier sees an error.
class SaleRepository {
  final FirebaseFirestore _db;

  SaleRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sales => _db.collection('sales');
  CollectionReference<Map<String, dynamic>> get _products => _db.collection('products');

  Future<void> completeSale(Sale sale) {
    return _db.runTransaction((txn) async {
      // Firestore transactions require every read to finish before any
      // write starts, so current stock for every cart item is checked
      // first — the sale doc and stock decrements are only written
      // once every single item is confirmed to have enough left.
      final productRefs = sale.items.map((item) => _products.doc(item.productId)).toList();
      final snapshots = await Future.wait(productRefs.map((ref) => txn.get(ref)));

      for (var i = 0; i < sale.items.length; i++) {
        final item = sale.items[i];
        final snapshot = snapshots[i];

        if (!snapshot.exists) {
          throw InsufficientStockException('${item.name} is no longer available');
        }

        final currentStock = (snapshot.data()?['stockQty'] as num?)?.toInt() ?? 0;
        if (currentStock < item.qty) {
          throw InsufficientStockException('Only $currentStock of ${item.name} left in stock');
        }
      }

      final saleRef = _sales.doc();
      txn.set(saleRef, sale.toMap());

      for (var i = 0; i < sale.items.length; i++) {
        txn.update(productRefs[i], {'stockQty': FieldValue.increment(-sale.items[i].qty)});
      }
    });
  }
}
