import 'package:equatable/equatable.dart';

/// The shop's own GST/invoice details -- GSTIN, the tax rate applied
/// at checkout, and an optional invoice prefix + footer note -- stored
/// once per shop under `taxInvoiceSettings/{shopId}`.
///
/// Unlike `ShopDetails`/`PaymentSettings` (display info only so far),
/// [taxRatePercent] is live: `TaxInvoiceSettingsScreen` saving it is
/// what actually changes the GST % used in Sales checkout, replacing
/// the `SalesState.taxRate` constant that used to be hardcoded at 18%.
/// GSTIN/invoice prefix/footer note are still display-only (not yet
/// printed on the receipt/report PDFs).
///
/// Every field defaults so a shop that hasn't filled this in yet just
/// reads back the same 18% GST behaviour the app always had.
class TaxInvoiceSettings extends Equatable {
  final String gstin;
  final double taxRatePercent;
  final String invoicePrefix;
  final String invoiceNote;

  const TaxInvoiceSettings({
    this.gstin = '',
    this.taxRatePercent = 18.0,
    this.invoicePrefix = '',
    this.invoiceNote = '',
  });

  /// `SalesState.taxRate` wants a 0-1 fraction, not a percentage.
  double get taxRateFraction => taxRatePercent / 100.0;

  factory TaxInvoiceSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const TaxInvoiceSettings();
    return TaxInvoiceSettings(
      gstin: map['gstin'] as String? ?? '',
      taxRatePercent: (map['taxRatePercent'] as num?)?.toDouble() ?? 18.0,
      invoicePrefix: map['invoicePrefix'] as String? ?? '',
      invoiceNote: map['invoiceNote'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gstin': gstin,
      'taxRatePercent': taxRatePercent,
      'invoicePrefix': invoicePrefix,
      'invoiceNote': invoiceNote,
    };
  }

  @override
  List<Object?> get props => [gstin, taxRatePercent, invoicePrefix, invoiceNote];
}
