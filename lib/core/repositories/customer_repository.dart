import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/customer.dart';

/// The only place in the app that talks to the `customers` Firestore
/// collection directly — same one-repository-per-collection convention
/// as ProductRepository/SaleRepository/etc.
class CustomerRepository {
  final FirebaseFirestore _db;

  CustomerRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _customers => _db.collection('customers');

  /// A live, alphabetically-sorted customer directory for this shop.
  /// Sorting happens client-side rather than via Firestore `orderBy`
  /// for the same reason ProductRepository does — avoids needing a
  /// composite index for a list small enough this costs nothing.
  Stream<List<Customer>> watchCustomers({required String shopId}) {
    return _customers.where('shopId', isEqualTo: shopId).snapshots().map((snapshot) {
      final customers = snapshot.docs.map((doc) => Customer.fromMap(doc.id, doc.data())).toList();
      customers.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return customers;
    });
  }

  /// Creates a new customer document and returns its Firestore-assigned
  /// id — needed right away by the Sales screen's "add new customer"
  /// flow, which attaches the customer to the sale being rung up in the
  /// same breath rather than waiting for the live list to catch up.
  Future<String> addCustomer(Customer customer) async {
    final doc = await _customers.add(customer.toMap());
    return doc.id;
  }

  /// Updates an existing customer document in place. Deliberately strips
  /// `createdAt` from the map before writing (`toMap()` always stamps a
  /// fresh `FieldValue.serverTimestamp()`, correct for a brand-new
  /// customer but wrong here -- it would silently reset the customer's
  /// original creation time, and therefore their position in the
  /// alphabetically-sorted list stays the same either way, but any
  /// future "newest customers" view would quietly break). Same pattern
  /// as `ProductRepository.updateProduct`.
  Future<void> updateCustomer(String id, Customer customer) {
    final map = customer.toMap()..remove('createdAt');
    return _customers.doc(id).update(map);
  }

  /// Permanently removes a customer. There's no undo -- the caller is
  /// responsible for confirming with the person first. Any Sale or
  /// ServiceJob that was linked to this customer keeps its own
  /// snapshotted customerName/customerPhone (see Sale/ServiceJob's own
  /// doc comments) so old records still show who it was even after the
  /// customer record itself is gone.
  Future<void> deleteCustomer(String id) {
    return _customers.doc(id).delete();
  }
}
