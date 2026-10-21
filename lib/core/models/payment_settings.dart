import 'package:equatable/equatable.dart';

/// The shop's own payment/bank details -- UPI id + bank account info
/// -- stored once per shop under `paymentSettings/{shopId}`. Display
/// info only today: saving these doesn't change what happens at
/// checkout (Sales still offers UPI/Card/Cash exactly as before) --
/// this is for showing on receipts/invoices later, same spirit as
/// `ShopDetails`.
///
/// Every field defaults to `''` so a shop that hasn't filled this in
/// yet just reads back blank.
class PaymentSettings extends Equatable {
  final String upiId;
  final String bankAccountName;
  final String bankAccountNumber;
  final String bankIfsc;
  final String bankName;

  const PaymentSettings({
    this.upiId = '',
    this.bankAccountName = '',
    this.bankAccountNumber = '',
    this.bankIfsc = '',
    this.bankName = '',
  });

  factory PaymentSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PaymentSettings();
    return PaymentSettings(
      upiId: map['upiId'] as String? ?? '',
      bankAccountName: map['bankAccountName'] as String? ?? '',
      bankAccountNumber: map['bankAccountNumber'] as String? ?? '',
      bankIfsc: map['bankIfsc'] as String? ?? '',
      bankName: map['bankName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'upiId': upiId,
      'bankAccountName': bankAccountName,
      'bankAccountNumber': bankAccountNumber,
      'bankIfsc': bankIfsc,
      'bankName': bankName,
    };
  }

  @override
  List<Object?> get props => [upiId, bankAccountName, bankAccountNumber, bankIfsc, bankName];
}
