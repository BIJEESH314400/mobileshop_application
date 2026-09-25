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
}
