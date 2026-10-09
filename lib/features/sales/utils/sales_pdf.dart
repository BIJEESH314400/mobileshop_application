import 'dart:typed_data';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/models/sale.dart';

/// PDF builders for Sales History -- a single sale's receipt, and a
/// report of a whole (already filtered) list of sales. Kept separate
/// from the on-screen widgets in sales_history_screen.dart, but
/// deliberately mirrors the same fields/order shown there so the PDF
/// never surprises someone who already saw it on screen.
final _pdfPrice = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);
final _pdfDateTime = DateFormat('d MMM yyyy, h:mm a');
final _pdfDate = DateFormat('d MMM yyyy');

/// One-page receipt for a single [sale] -- same fields as the in-app
/// Receipt bottom sheet (sales_history_screen.dart's `_showReceipt`):
/// date, sold-by, customer link, itemized lines, subtotal/discount/
/// tax/total, payment method.
Future<Uint8List> buildReceiptPdfBytes(Sale sale) async {
  final doc = pw.Document();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('4B Mobiles', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text('Sales Receipt', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.SizedBox(height: 14),
            pw.Text(
              sale.createdAt == null ? 'Just now' : _pdfDateTime.format(sale.createdAt!),
              style: const pw.TextStyle(fontSize: 10),
            ),
            if (sale.soldByName.isNotEmpty)
              pw.Text(
                'Sold by ${sale.soldByName}${sale.soldByRole == 'owner' ? ' (Owner)' : ' (Staff)'}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            pw.Text(
              sale.customerName.isNotEmpty ? 'Customer: ${sale.customerName}' : 'Customer: Walk-in',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 16),
            pw.Table(
              border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300)),
              columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1.4)},
              children: [
                pw.TableRow(
                  children: [
                    _pdfCell('Item', bold: true),
                    _pdfCell('Qty', bold: true),
                    _pdfCell('Amount', bold: true, alignRight: true),
                  ],
                ),
                for (final item in sale.items)
                  pw.TableRow(
                    children: [
                      _pdfCell(item.name),
                      _pdfCell('${item.qty}'),
                      _pdfCell(_pdfPrice.format(item.lineTotal), alignRight: true),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.grey400),
            _pdfTotalRow('Subtotal', sale.subtotal),
            if (sale.discount > 0) _pdfTotalRow('Discount', -sale.discount),
            _pdfTotalRow('Tax', sale.tax),
            pw.SizedBox(height: 4),
            _pdfTotalRow('Total', sale.total, emphasize: true),
            pw.SizedBox(height: 12),
            pw.Text('Paid via ${sale.paymentMethod.toUpperCase()}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ],
        );
      },
    ),
  );

  return doc.save();
}

/// A multi-sale report -- whatever list of sales is currently visible
/// on the Sales History screen (already narrowed by its own search
/// box / date-range filter, if any were set). [dateRange]/[searchQuery]
/// are shown as a subtitle only, purely descriptive -- the caller has
/// already done the actual filtering before calling this.
Future<Uint8List> buildSalesListPdfBytes(
  List<Sale> sales, {
  DateTimeRange? dateRange,
  String? searchQuery,
}) async {
  final doc = pw.Document();
  final revenue = sales.fold(0.0, (sum, s) => sum + s.total);

  final filterLines = <String>[];
  if (dateRange != null) {
    filterLines.add('${_pdfDate.format(dateRange.start)} - ${_pdfDate.format(dateRange.end)}');
  }
  if (searchQuery != null && searchQuery.trim().isNotEmpty) {
    filterLines.add('Search: "${searchQuery.trim()}"');
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (context) {
        if (context.pageNumber > 1) {
          return pw.Text('4B Mobiles - Sales Report (continued)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600));
        }
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('4B Mobiles', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text('Sales Report', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            if (filterLines.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(filterLines.join('  ·  '), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ],
            pw.SizedBox(height: 10),
            pw.Text(
              '${sales.length} sale${sales.length == 1 ? '' : 's'}   ·   Total: ${_pdfPrice.format(revenue)}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
          ],
        );
      },
      build: (context) => [
        pw.Table(
          border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300)),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.6),
            1: pw.FlexColumnWidth(3),
            2: pw.FlexColumnWidth(1.6),
            3: pw.FlexColumnWidth(1.2),
            4: pw.FlexColumnWidth(1.4),
          },
          children: [
            pw.TableRow(
              children: [
                _pdfCell('Date', bold: true),
                _pdfCell('Items', bold: true),
                _pdfCell('Sold By', bold: true),
                _pdfCell('Paid', bold: true),
                _pdfCell('Total', bold: true, alignRight: true),
              ],
            ),
            for (final sale in sales)
              pw.TableRow(
                children: [
                  _pdfCell(sale.createdAt == null ? 'Just now' : _pdfDateTime.format(sale.createdAt!)),
                  _pdfCell(sale.items.map((i) => '${i.name} x${i.qty}').join(', ')),
                  _pdfCell(sale.soldByName.isNotEmpty ? sale.soldByName : '-'),
                  _pdfCell(sale.paymentMethod.toUpperCase()),
                  _pdfCell(_pdfPrice.format(sale.total), alignRight: true),
                ],
              ),
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _pdfCell(String text, {bool bold = false, bool alignRight = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 9.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
    ),
  );
}

pw.Widget _pdfTotalRow(String label, double value, {bool emphasize = false}) {
  final style = pw.TextStyle(fontSize: emphasize ? 13 : 10, fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal);
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(_pdfPrice.format(value), style: style),
      ],
    ),
  );
}
