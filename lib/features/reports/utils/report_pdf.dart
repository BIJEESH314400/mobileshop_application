import 'dart:typed_data';

import 'package:flutter/material.dart' show Color, Colors;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/models/sale.dart';
import '../../../core/models/shop_details.dart';
import '../../../core/models/tax_invoice_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/receipt_branding.dart';

/// PDF builder for the Reports screen -- same stat-row / top-products /
/// payment-breakdown math as reports_screen.dart's `_StatRow`,
/// `_TopProducts` and `_PaymentBreakdown`, reimplemented here as plain
/// Dart since PDF generation can't reuse Flutter widget classes. Kept
/// in step with that screen deliberately: whatever the owner sees on
/// screen for a period is exactly what this PDF reports for the same
/// period.
///
/// Redesigned 2026-11-12, twice in the same day -- first after a
/// branded "trip expense report" reference image, then again after the
/// user shared a second, more specific mockup (a "Sales & Revenue
/// Summary" layout with a big settled-revenue banner, chip stats, and
/// side-by-side payment cards) and asked for that exact design. This
/// version matches that second mockup's structure. `_pdfAccent`/
/// `_pdfAccentTint`/`_pdfAccentPale`/`_pdfAccentDark` read
/// `AppColors.accent` -- the same mutable accent color Profile -> App
/// Theme already drives everywhere else in the app -- at the moment
/// this PDF is generated, so whichever of the 6 themes is selected is
/// what shows up here, not a fixed brand color copied from the mockup.
///
/// Two things in the mockup were deliberately NOT copied as real data:
/// - A short descriptive subtitle under each product name (e.g.
///   "Smartphone Unit", "Accessory Line") -- SaleItem has no category
///   field, so this would have to be invented text with no real
///   meaning. Left out rather than fabricated.
/// - A true gradient fill on the revenue banner -- the `pdf` package's
///   widget-level BoxDecoration gradient support isn't something that
///   could be verified without a Dart compiler in this environment (no
///   Flutter/Dart toolchain is reachable from here -- every change in
///   this project is verified by a brace/paren balance checker only,
///   never actually compiled), so a flat accent fill was used instead
///   to avoid shipping an unverified API call that could fail the
///   user's next build. Flagged in the project doc for anyone who
///   wants to swap it for a real gradient later.
/// "Fully Settled" / "Reconciled" are static labels, not a tracked
/// status -- but an honest one: every Sale record in this app is
/// create-only and immutable (firestore.rules allows no update except
/// re-linking a customer, and never allows delete), so every sale a
/// report includes really is a final, settled transaction, never a
/// pending one.
final _reportPrice = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);
final _reportDateTime = DateFormat('d MMM yyyy · h:mm a');

/// The app's own product name -- distinct from the shop's own display
/// name (`shopDisplayName`, fully dynamic per Shop Details), used only
/// for "generated via ..." style footer copy. Matches the brand name
/// already hardcoded as the receipt printer's own Test Print text.
const _appBrandName = '4B Mobiles';

PdfColor _pdfColor(Color color) => PdfColor.fromInt(color.value);

/// The live accent color (whichever of the 6 app themes is active),
/// plus a few derived tints/shades for backgrounds -- same
/// `Color.lerp(accent, white/black, t)` approach the Dashboard's own
/// decorative stat card already uses to stay theme-aware instead of a
/// hardcoded hue.
PdfColor get _pdfAccent => _pdfColor(AppColors.accent);
PdfColor get _pdfAccentTint => _pdfColor(Color.lerp(AppColors.accent, Colors.white, 0.88)!); // Grand Total row background
PdfColor get _pdfAccentPale => _pdfColor(Color.lerp(AppColors.accent, Colors.white, 0.94)!); // info box / table zebra striping
PdfColor get _pdfAccentDark => _pdfColor(Color.lerp(AppColors.accent, Colors.black, 0.18)!); // chip background on top of the revenue banner

class _ReportProductAgg {
  final String name;
  int qty;
  double revenue;
  _ReportProductAgg({required this.name, required this.qty, required this.revenue});
}

/// A report PDF for [sales] (already filtered to the owner's chosen
/// period on the Reports screen -- this function just renders what it's
/// handed). [periodLabel] is the human label for that period (e.g.
/// "This Week"), shown in the info box.
Future<Uint8List> buildReportPdfBytes({
  required String periodLabel,
  required List<Sale> sales,
  ShopDetails? shop,
  TaxInvoiceSettings? tax,
}) async {
  final doc = pw.Document();
  final generatedAt = DateTime.now();
  final reportId = 'RPT-${generatedAt.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';

  // -- Revenue / orders / avg order / items sold -- mirrors _StatRow's math.
  final revenue = sales.fold(0.0, (sum, s) => sum + s.total);
  final orders = sales.length;
  final avgOrder = orders == 0 ? 0.0 : revenue / orders;
  final itemsSold = sales.fold(0, (sum, s) => sum + s.items.fold(0, (isum, item) => isum + item.qty));

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

  // -- Payment method breakdown -- mirrors _PaymentBreakdown's math,
  // plus an order count per method (for "X of Y transactions").
  var upi = 0.0, card = 0.0, cash = 0.0;
  var upiCount = 0, cardCount = 0, cashCount = 0;
  for (final sale in sales) {
    switch (sale.paymentMethod) {
      case 'upi':
        upi += sale.total;
        upiCount++;
        break;
      case 'card':
        card += sale.total;
        cardCount++;
        break;
      default:
        cash += sale.total;
        cashCount++;
        break;
    }
  }
  final paymentRows = <(String, String, int, double)>[
    ('UPI Settlement', 'upi', upiCount, upi),
    ('Card Payment', 'card', cardCount, card),
    ('Cash Tender', 'cash', cashCount, cash),
  ];
  // Whichever method actually brought in the most revenue gets the
  // highlighted/filled card below -- only if it actually has any
  // revenue, so an all-zero period highlights nothing.
  final leadMethodKey = paymentRows.fold<(String, double)?>(null, (lead, row) {
    final (_, key, _, amount) = row;
    if (amount <= 0) return lead;
    if (lead == null || amount > lead.$2) return (key, amount);
    return lead;
  })?.$1;
  String pct(double value) => revenue <= 0 ? '0%' : '${((value / revenue) * 100).round()}%';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(26),
      header: (context) {
        if (context.pageNumber > 1) {
          return pw.Text(
            '${shopDisplayName(shop)} - Reports (continued)',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          );
        }
        return _reportHeaderBand(shop: shop, reportId: reportId, generatedAt: generatedAt);
      },
      footer: (context) => _reportFooter(
        shop: shop,
        reportId: reportId,
        pageNumber: context.pageNumber,
        pagesCount: context.pagesCount,
      ),
      build: (context) => [
        pw.SizedBox(height: 12),
        _reportInfoBox(shop: shop, periodLabel: periodLabel),
        pw.SizedBox(height: 14),

        _reportRevenueBanner(revenue: revenue, orders: orders, avgOrder: avgOrder, itemsSold: itemsSold),
        pw.SizedBox(height: 20),

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            _reportSectionLabel('TOP SOLD PRODUCTS'),
            pw.Text(
              '${topProducts.length} unique line item${topProducts.length == 1 ? '' : 's'}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        if (topFive.isEmpty) _reportEmptyNote() else _reportProductsTable(topFive, revenue),
        pw.SizedBox(height: 20),

        _reportSectionLabel('PAYMENT BREAKDOWN'),
        pw.SizedBox(height: 8),
        if (revenue <= 0)
          _reportEmptyNote()
        else
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < paymentRows.length; i++) ...[
                if (i > 0) pw.SizedBox(width: 8),
                _reportPaymentCard(
                  label: paymentRows[i].$1,
                  count: paymentRows[i].$3,
                  totalOrders: orders,
                  amount: paymentRows[i].$4,
                  pctText: pct(paymentRows[i].$4),
                  pctValue: revenue <= 0 ? 0 : paymentRows[i].$4 / revenue,
                  highlighted: paymentRows[i].$2 == leadMethodKey,
                ),
              ],
            ],
          ),
      ],
    ),
  );

  return doc.save();
}

/// Badge + shop name + compact subtitle on the left; an ID pill and a
/// "Fully Settled" status pill stacked above the generated date/time
/// on the right -- one compact masthead block, no separate large title
/// section below it.
pw.Widget _reportHeaderBand({required ShopDetails? shop, required String reportId, required DateTime generatedAt}) {
  final initial = shopDisplayName(shop).trim().isEmpty ? '?' : shopDisplayName(shop).trim()[0].toUpperCase();
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(height: 3, color: _pdfAccent),
      pw.SizedBox(height: 12),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 30,
            height: 30,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(color: _pdfAccent, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
            child: pw.Text(initial, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(shopDisplayName(shop), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 1),
                pw.Text(
                  'SALES & REVENUE SUMMARY',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _pdfAccent, letterSpacing: 0.6),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Row(
                children: [
                  _reportPill(reportId, PdfColors.blueGrey50, PdfColors.blueGrey700),
                  pw.SizedBox(width: 6),
                  _reportPill('Fully Settled', PdfColors.green50, PdfColors.green700),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Text(_reportDateTime.format(generatedAt), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 4),
    ],
  );
}

pw.Widget _reportPill(String text, PdfColor background, PdfColor textColor) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: pw.BoxDecoration(color: background, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20))),
    child: pw.Text(text, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: textColor)),
  );
}

/// OUTLET / PERIOD / STORE LOCATION & CONTACT, laid out as 3 labeled
/// columns in a light bordered box.
pw.Widget _reportInfoBox({required ShopDetails? shop, required String periodLabel}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey50,
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _reportInfoField('OUTLET', shopDisplayName(shop)),
        _reportInfoField('PERIOD', periodLabel),
        _reportInfoField('STORE LOCATION & CONTACT', shopAddressLine(shop).isEmpty ? '-' : shopAddressLine(shop)),
      ],
    ),
  );
}

pw.Widget _reportInfoField(String label, String value) {
  return pw.Expanded(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600, letterSpacing: 0.4)),
        pw.SizedBox(height: 3),
        pw.Text(value, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold), maxLines: 2),
      ],
    ),
  );
}

/// The big accent-filled revenue banner -- total on the left, three
/// small chip stats (Orders / Avg per Order / Items Sold) on the
/// right. A flat fill, not a true gradient -- see the file-level doc
/// comment for why.
pw.Widget _reportRevenueBanner({
  required double revenue,
  required int orders,
  required double avgOrder,
  required int itemsSold,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(16),
    decoration: pw.BoxDecoration(color: _pdfAccent, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10))),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'TOTAL SETTLED REVENUE',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 0.6),
              ),
              pw.SizedBox(height: 6),
              pw.Text(_reportPrice.format(revenue), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              pw.SizedBox(height: 4),
              pw.Text(
                'Aggregated across all sales cycles for this period',
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.white),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 10),
        _reportBannerChip('ORDERS', '$orders'),
        pw.SizedBox(width: 6),
        _reportBannerChip('AVG / ORDER', _reportPrice.format(avgOrder)),
        pw.SizedBox(width: 6),
        _reportBannerChip('ITEMS SOLD', '$itemsSold'),
      ],
    ),
  );
}

pw.Widget _reportBannerChip(String label, String value) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    decoration: pw.BoxDecoration(color: _pdfAccentDark, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.white, letterSpacing: 0.4)),
        pw.SizedBox(height: 3),
        pw.Text(value, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
      ],
    ),
  );
}

pw.Widget _reportSectionLabel(String text) {
  return pw.Row(
    children: [
      pw.Container(width: 3, height: 12, color: _pdfAccent),
      pw.SizedBox(width: 6),
      pw.Text(text, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5)),
    ],
  );
}

pw.Widget _reportEmptyNote() {
  return pw.Text('No sales for this period.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600));
}

/// #, Product Description, Qty, Revenue, Cumulative Total -- an
/// accent-filled header row, light zebra rows, and a tinted Grand
/// Total row with a "Reconciled" tag.
pw.Widget _reportProductsTable(List<_ReportProductAgg> items, double totalRevenue) {
  var running = 0.0;
  var qtySum = 0;
  final rows = <pw.TableRow>[
    pw.TableRow(
      decoration: pw.BoxDecoration(color: _pdfAccent),
      children: [
        _reportHeadCell('#'),
        _reportHeadCell('Product Description'),
        _reportHeadCell('Qty'),
        _reportHeadCell('Revenue', alignRight: true),
        _reportHeadCell('Cumulative Total', alignRight: true),
      ],
    ),
  ];
  for (var i = 0; i < items.length; i++) {
    running += items[i].revenue;
    qtySum += items[i].qty;
    rows.add(
      pw.TableRow(
        decoration: i.isOdd ? pw.BoxDecoration(color: _pdfAccentPale) : null,
        children: [
          _reportCell('${i + 1}'),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: pw.Text(items[i].name, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _pdfAccent)),
          ),
          _reportCell('${items[i].qty}'),
          _reportCell(_reportPrice.format(items[i].revenue), alignRight: true, bold: true),
          _reportCell(_reportPrice.format(running), alignRight: true),
        ],
      ),
    );
  }
  rows.add(
    pw.TableRow(
      decoration: pw.BoxDecoration(color: _pdfAccentTint),
      children: [
        _reportCell(''),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          child: pw.Row(
            children: [
              pw.Text('GRAND TOTAL', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(width: 8),
              _reportPill('Reconciled', PdfColors.green50, PdfColors.green700),
            ],
          ),
        ),
        _reportCell('$qtySum', bold: true),
        _reportCell(_reportPrice.format(totalRevenue), bold: true, alignRight: true),
        _reportCell('', alignRight: true),
      ],
    ),
  );
  return pw.Table(
    border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300)),
    columnWidths: const {
      0: pw.FlexColumnWidth(0.4),
      1: pw.FlexColumnWidth(3),
      2: pw.FlexColumnWidth(0.8),
      3: pw.FlexColumnWidth(1.4),
      4: pw.FlexColumnWidth(1.6),
    },
    children: rows,
  );
}

/// One of the 3 side-by-side payment-method cards -- filled/accent
/// when [highlighted] (the period's dominant method), plain bordered
/// otherwise, each with a share badge, a transaction count, the
/// amount and a small progress bar.
pw.Widget _reportPaymentCard({
  required String label,
  required int count,
  required int totalOrders,
  required double amount,
  required String pctText,
  required double pctValue,
  required bool highlighted,
}) {
  final fg = highlighted ? PdfColors.white : PdfColors.black;
  final sub = highlighted ? PdfColors.white : PdfColors.grey600;
  final barTrack = highlighted ? _pdfAccentDark : PdfColors.grey200;
  final barFill = highlighted ? PdfColors.white : _pdfAccent;
  final filledFlex = (pctValue.clamp(0.0, 1.0) * 100).round();
  final emptyFlex = 100 - filledFlex;

  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: highlighted ? _pdfAccent : PdfColors.white,
        border: highlighted ? null : pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(child: pw.Text(label, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: fg))),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: highlighted ? _pdfAccentDark : PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Text(pctText, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: fg)),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text('$count of $totalOrders transactions', style: pw.TextStyle(fontSize: 7, color: sub)),
          pw.SizedBox(height: 4),
          pw.Text(_reportPrice.format(amount), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: fg)),
          pw.SizedBox(height: 6),
          // Plain flex-split bar (no ClipRRect) -- this project has no
          // reachable Dart/Flutter compiler to verify an uncertain
          // widget API against, so the progress bar is built only from
          // Row/Expanded/Container, which are already used safely
          // elsewhere in this same file.
          pw.Row(
            children: [
              if (filledFlex > 0) pw.Expanded(flex: filledFlex, child: pw.Container(height: 4, color: barFill)),
              if (emptyFlex > 0) pw.Expanded(flex: emptyFlex, child: pw.Container(height: 4, color: barTrack)),
            ],
          ),
        ],
      ),
    ),
  );
}

pw.Widget _reportHeadCell(String text, {bool alignRight = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 4),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
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

/// Thin rule + shop/app byline on the left, report id + page count on
/// the right.
pw.Widget _reportFooter({
  required ShopDetails? shop,
  required String reportId,
  required int pageNumber,
  required int pagesCount,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Divider(color: PdfColors.grey300, height: 12),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '${shopDisplayName(shop)}  ·  Reports & Analytics  ·  Generated via $_appBrandName POS',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
          pw.Text(
            'Report ID: $reportId  ·  Page $pageNumber of $pagesCount',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
        ],
      ),
    ],
  );
}
