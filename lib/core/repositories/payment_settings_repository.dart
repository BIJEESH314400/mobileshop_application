import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/payment_settings.dart';

/// Reads/writes the one `paymentSettings/{shopId}` document for this
/// shop -- owner-only, enforced by `firestore.rules`, not just by
/// this screen's own `OwnerOnlyGate` wrapper. Same one-shot-read shape
/// as `ShopDetailsRepository` -- this isn't live/changing data.
class PaymentSettingsRepository {
  final FirebaseFirestore _db;

  PaymentSettingsRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _paymentSettings => _db.collection('paymentSettings');

  Future<PaymentSettings> getPaymentSettings(String shopId) async {
    final doc = await _paymentSettings.doc(shopId).get();
    return PaymentSettings.fromMap(doc.data());
  }

  Future<void> savePaymentSettings(String shopId, PaymentSettings settings) {
    return _paymentSettings.doc(shopId).set(settings.toMap(), SetOptions(merge: true));
  }
}
