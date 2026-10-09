import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/models/sale.dart';

/// PDF builder for the Reports screen -- same stat-row / top-products /
/// payment-breakdown math as reports_screen.dart's `_StatRow`,
/// `_TopProducts` and `_PaymentBreakdown`, reimplemented here as plain
/// Dart since PDF generation can't reuse Flutter widget classes. Kept
/// in step with that screen deliberately: whatever the owner sees on
/// screen for a period is exactly what this PDF reports for the same
/// period.
final _reportPrice = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);

class _ReportProductAgg {
  final String name;
  int qty;
  double revenue;
  _ReportProductAgg({required this.name, required this.qty, required this.revenue});
}

/// A report PDF for [sales] (already filtered to the owner's chosen
/// period on the Reports screen -- this function just renders what it's
/// handed). [periodLabel] is the human label for that period (e.g.
/// "This Week"), shown as a subtitle only.
Future<Uint8List> buildReportPdfBytes({
  required String periodLabel,
  required List<Sale> sales,
}) async {
  final doc = pw.Document();

  // -- Revenue / orders / avg order -- mirrors _StatRow's math.
  final revenue = sales.fold(0.0, (sum, s) => sum + s.total);
  final orders = sales.length;
  final avgOrder = orders == 0 ? 0.0 : revenue / orders;

  // -- Top products by revenue -- mirrors _TopProducts' aggregation.
  final byProduct = <String, _ReportProductAgg>{};
  for (final sale in sales) {
    for (final item in sale.items) {
      final existing = byProduct[item.productId];
      if (existing == null) {
        byProduct[item.productId] = _ReportProductAgg(name: item.name, qty: item.qty, revenue: item.lineTotal);
      } else {
        existing.qty += item.qty;
        existing.revenue += item.lineTotal;
      }
    }
  }
  final topProducts = byProduct.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue));
  final topFive = topProducts.take(5).toList();

  // -- Payment method breakdown -- mirrors _PaymentBreakdown's math.
  var upi = 0.0, card = 0.0, cash = 0.0;
  for (final sale in sales) {
    switch (sale.paymentMethod) {
      case 'upi':
        upi += sale.total;
        break;
      case 'card':
        card += sale.total;
        break;
      default:
        cash += sale.total;
        break;
    }
  }
  final paymentTotal = upi + card + cash;
  String pct(double value) => paymentTotal <= 0 ? '0%' : '${((value / paymentTotal) * 100).round()}%';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (context) {
        if (context.pageNumber > 1) {
          return pw.Text('4B Mobiles - Reports (continued)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600));
        }
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('4B Mobiles', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text('Reports & Analytics', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text(periodLabel, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.SizedBox(height: 12),
          ],
        );
      },
      build: (context) => [
        // Stat row
        pw.Row(
          children: [
            _reportStatTile('Revenue', _reportPrice.format(revenue)),
            pw.SizedBox(width: 10),
            _reportStatTile('Orders', '$orders'),
            pw.SizedBox(width: 10),
            _reportStatTile('Avg Order', _reportPrice.format(avgOrder)),
          ],
        ),
        pw.SizedBox(height: 20),

        // Top products
        pw.Text('Top Products', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (topFive.isEmpty)
          pw.Text('No sales for this period.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
        else
          pw.Table(
            border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300)),
            columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1.4)},
            children: [
              pw.TableRow(
                children: [
                  _reportCell('Product', bold: true),
                  _reportCell('Qty', bold: true),
                  _reportCell('Revenue', bold: true, alignRight: true),
                ],
              ),
              for (var i = 0; i < topFive.length; i++)
                pw.TableRow(
                  children: [
                    _reportCell('${i + 1}. ${topFive[i].name}'),
                    _reportCell('${topFive[i].qty}'),
                    _reportCell(_reportPrice.format(topFive[i].revenue), alignRight: true),
                  ],
                ),
            ],
          ),
        pw.SizedBox(height: 20),

        // Payment breakdown
        pw.Text('Payment Methods', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (paymentTotal <= 0)
          pw.Text('No sales for this period.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
        else
          pw.Table(
            border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300)),
            columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1.4)},
            children: [
              pw.TableRow(
                children: [
                  _reportCell('Method', bold: true),
                  _reportCell('Share', bold: true),
                  _reportCell('Amount', bold: true, alignRight: true),
                ],
              ),
              pw.TableRow(children: [_reportCell('UPI'), _reportCell(pct(upi)), _reportCell(_reportPrice.format(upi), alignRight: true)]),
              pw.TableRow(children: [_reportCell('Card'), _reportCell(pct(card)), _reportCell(_reportPrice.format(card), alignRight: true)]),
              pw.TableRow(children: [_reportCell('Cash'), _reportCell(pct(cash)), _reportCell(_reportPrice.format(cash), alignRight: true)]),
            ],
          ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _reportStatTile(String label, String value) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    ),
  );
}

pw.Widget _reportCell(String text, {bool bold = false, bool alignRight = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 9.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
    ),
  );
}
