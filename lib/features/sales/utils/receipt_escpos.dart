import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../../../core/models/sale.dart';
import '../../../core/models/shop_details.dart';
import '../../../core/models/tax_invoice_settings.dart';
import '../../../core/utils/escpos_builder.dart';
import '../../../core/utils/receipt_branding.dart';

/// Builds the ESC/POS bytes for printing one [sale]'s receipt on a
/// Bluetooth thermal printer -- same fields, same order as the PDF
/// receipt (sales_pdf.dart's buildReceiptPdfBytes) and the in-app
/// Receipt bottom sheet, just laid out for a narrow paper roll
/// instead of an A4 page.
///
/// [charsPerLine] defaults to 32 -- the usual width for a compact
/// 2-inch/58mm thermal roll (most small Bluetooth receipt printers,
/// Visiontek included). A 3-inch/80mm printer fits more (around 42-48)
/// -- change this if a wider printer is confirmed on real hardware.
Uint8List buildReceiptEscPosBytes(Sale sale, {int charsPerLine = 32, ShopDetails? shop, TaxInvoiceSettings? tax}) {
  final dateFormat = DateFormat('d MMM yyyy, h:mm a');
  final money = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);

  final addressLine = shopAddressLine(shop);
  final gstin = tax?.gstin.trim() ?? '';
  final invoiceNumber = buildInvoiceNumber(sale.id, tax);
  final footerNote = tax?.invoiceNote.trim() ?? '';

  final b = EscPosBuilder()
    ..text(shopDisplayName(shop), bold: true, doubleWidth: true, center: true)
    ..line()
    ..text('Sales Receipt', center: true)
    ..line();

  for (final addrLine in _wrap(addressLine, charsPerLine)) {
    if (addrLine.isEmpty) continue;
    b
      ..text(addrLine, center: true)
      ..line();
  }
  if (gstin.isNotEmpty) {
    b
      ..text('GSTIN: $gstin', center: true)
      ..line();
  }
  b
    ..line()
    ..line(sale.createdAt == null ? 'Just now' : dateFormat.format(sale.createdAt!));
  if (invoiceNumber != null) {
    b.line('Invoice No: $invoiceNumber');
  }

  if (sale.soldByName.isNotEmpty) {
    b.line('Sold by ${sale.soldByName}${sale.soldByRole == 'owner' ? ' (Owner)' : ' (Staff)'}');
  }
  b.line(sale.customerName.isNotEmpty ? 'Customer: ${sale.customerName}' : 'Customer: Walk-in');
  b.divider(width: charsPerLine);

  for (final item in sale.items) {
    for (final nameLine in _wrap(item.name, charsPerLine)) {
      b.line(nameLine);
    }
    b.line(_twoColumn('${item.qty} x ${money.format(item.price)}', money.format(item.lineTotal), charsPerLine));
  }
  b.divider(width: charsPerLine);

  b.line(_twoColumn('Subtotal', money.format(sale.subtotal), charsPerLine));
  if (sale.discount > 0) {
    b.line(_twoColumn('Discount', '-${money.format(sale.discount)}', charsPerLine));
  }
  b.line(_twoColumn('Tax', money.format(sale.tax), charsPerLine));
  b.text(_twoColumn('TOTAL', money.format(sale.total), charsPerLine), bold: true);
  b.line();
  b.text('Paid via ${sale.paymentMethod.toUpperCase()}', bold: true);
  b.line();
  if (footerNote.isNotEmpty) {
    b.line();
    for (final noteLine in _wrap(footerNote, charsPerLine)) {
      b.line(noteLine);
    }
  }
  b.feed(3);

  return b.build();
}

/// Right-pads/truncates [left] and right-aligns [right] so both share
/// one [width]-character line -- e.g. "Subtotal" .... "Rs. 1,200.00".
String _twoColumn(String left, String right, int width) {
  final gap = width - left.length - right.length;
  if (gap < 1) {
    // Not enough room to share a line -- put the amount on its own
    // line rather than letting it run together with the label.
    return '$left\n$right';
  }
  return '$left${' ' * gap}$right';
}

/// Breaks [text] into [width]-character chunks on word boundaries
/// where possible, so a long item name wraps instead of silently
/// overflowing a cheap printer's own fixed character grid.
List<String> _wrap(String text, int width) {
  if (text.length <= width) return [text];
  final words = text.split(' ');
  final lines = <String>[];
  var current = '';
  for (final word in words) {
    final candidate = current.isEmpty ? word : '$current $word';
    if (candidate.length > width) {
      if (current.isNotEmpty) lines.add(current);
      current = word;
    } else {
      current = candidate;
    }
  }
  if (current.isNotEmpty) lines.add(current);
  return lines;
}
