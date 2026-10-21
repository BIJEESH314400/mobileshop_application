import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/shop_details.dart';
import '../models/tax_invoice_settings.dart';

/// Shared "masthead" building blocks for every PDF/receipt this app
/// generates (the sale receipt, the Sales History report, the Reports
/// & Analytics report, and the Bluetooth thermal receipt) -- added
/// 2026-10-21 so all four finally show the shop's own real name/
/// address/GSTIN (from Shop Details / Tax & Invoice Settings) instead
/// of a hardcoded "4B Mobiles" with no tax info. Every function here
/// falls back to the old hardcoded behaviour when [shop]/[tax] are
/// null or were never filled in, so a shop that hasn't visited those
/// two settings screens yet sees no regression.
const _fallbackShopName = '4B Mobiles';

/// The shop's real name if Shop Details has one saved, else the old
/// hardcoded fallback.
String shopDisplayName(ShopDetails? shop) {
  final name = shop?.name.trim() ?? '';
  return name.isEmpty ? _fallbackShopName : name;
}

/// The shop's address + phone, joined on one line, or '' if neither
/// was ever saved.
String shopAddressLine(ShopDetails? shop) {
  final parts = [shop?.address.trim(), shop?.phone.trim()].where((s) => s != null && s.isNotEmpty).cast<String>();
  return parts.join('  ·  ');
}

/// A simple, deterministic invoice number built from the saved
/// Invoice Prefix (Tax & Invoice Settings) plus the sale's own id --
/// e.g. prefix "INV-" + sale id "...a1b2c3" -> "INV-A1B2C3". This is
/// NOT a sequential running counter (there's no counter document to
/// race-safely increment anywhere in this app yet) -- it's a stable,
/// always-the-same-for-this-sale number, good enough to print on a
/// receipt. Returns null (no invoice-number line at all) if no
/// Invoice Prefix has been saved -- an empty prefix means the owner
/// hasn't opted into invoice numbering yet.
String? buildInvoiceNumber(String saleId, TaxInvoiceSettings? tax) {
  final prefix = tax?.invoicePrefix.trim() ?? '';
  if (prefix.isEmpty) return null;
  final shortId = saleId.length > 6 ? saleId.substring(saleId.length - 6) : saleId;
  return '$prefix${shortId.toUpperCase()}';
}

/// The PDF masthead column shown at the top of the first page of
/// every PDF this app generates -- shop name, [subtitle] (e.g. "Sales
/// Receipt"/"Sales Report"/"Reports & Analytics"), the address/phone
/// line (if any), and a "GSTIN: ..." line (if one is saved).
pw.Widget buildPdfShopHeader({
  required ShopDetails? shop,
  required TaxInvoiceSettings? tax,
  required String subtitle,
}) {
  final addressLine = shopAddressLine(shop);
  final gstin = tax?.gstin.trim() ?? '';
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(shopDisplayName(shop), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 2),
      pw.Text(subtitle, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
      if (addressLine.isNotEmpty) ...[
        pw.SizedBox(height: 2),
        pw.Text(addressLine, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      ],
      if (gstin.isNotEmpty) ...[
        pw.SizedBox(height: 2),
        pw.Text('GSTIN: $gstin', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      ],
    ],
  );
}

/// The small italic footer note (Tax & Invoice Settings' "Invoice
/// Footer Note") shown at the bottom of a receipt -- null (render
/// nothing) if no note was ever saved.
pw.Widget? buildPdfFooterNote(TaxInvoiceSettings? tax) {
  final note = tax?.invoiceNote.trim() ?? '';
  if (note.isEmpty) return null;
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 12),
    child: pw.Text(note, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
  );
}
