import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tax_invoice_settings.dart';

/// Reads/writes the one `taxInvoiceSettings/{shopId}` document for
/// this shop -- owner-only, enforced by `firestore.rules`, not just by
/// this screen's own `OwnerOnlyGate` wrapper. Same one-shot-read shape
/// as `ShopDetailsRepository`/`PaymentSettingsRepository` -- this
/// isn't live/changing data, it's read once per screen/session (see
/// `SalesBloc._onSubscriptionRequested`, which is what actually makes
/// [TaxInvoiceSettings.taxRatePercent] affect checkout).
class TaxInvoiceSettingsRepository {
  final FirebaseFirestore _db;

  TaxInvoiceSettingsRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _taxInvoiceSettings => _db.collection('taxInvoiceSettings');

  Future<TaxInvoiceSettings> getTaxInvoiceSettings(String shopId) async {
    final doc = await _taxInvoiceSettings.doc(shopId).get();
    return TaxInvoiceSettings.fromMap(doc.data());
  }

  Future<void> saveTaxInvoiceSettings(String shopId, TaxInvoiceSettings settings) {
    return _taxInvoiceSettings.doc(shopId).set(settings.toMap(), SetOptions(merge: true));
  }
}
