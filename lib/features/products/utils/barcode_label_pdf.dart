import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/models/product.dart';

/// One row of "print this many labels for this product" -- what the
/// Barcode Labels screen collects before generating a PDF.
class LabelRequest {
  final Product product;
  final int quantity;

  // One code per sticker, in order, when "Unique code per sticker" was
  // on for this product -- each cell then shows uniqueCodes[i] instead
  // of the product's own single barcode. Null (the default) means
  // every copy shows the same product.barcode, same as before this
  // existed. Expected to have exactly `quantity` entries when set.
  final List<String>? uniqueCodes;

  const LabelRequest({required this.product, required this.quantity, this.uniqueCodes});
}

/// Builds a printable A4 sheet of barcode stickers -- one cell per
/// copy requested (not per product), arranged in a simple 3-column
/// grid with a thin border around each cell marking where to cut.
/// Each cell shows a scannable Code128 barcode (with the code printed
/// underneath it, same as a real retail sticker) and the product's
/// name below that.
///
/// Code128 handles both a scanned-in manufacturer barcode and this
/// app's own longer `4B...`-prefixed generated codes without needing
/// two different symbologies, so one PDF builder covers both cases.
/// Short, print-friendly stand-in for a product's category -- there's
/// no room on a small sticker for a full category name next to the
/// barcode and product name. A multi-word category ("Smart Phone")
/// becomes an initialism of its first words ("SP"); a single word is
/// just truncated ("Flowers" -> "FLO"). Empty category -> empty
/// string, so products without one print exactly as before this
/// existed.
String _categoryShortCode(String category) {
  final trimmed = category.trim();
  if (trimmed.isEmpty) return '';
  final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length > 1) {
    return words.take(3).map((w) => w[0].toUpperCase()).join();
  }
  return trimmed.length <= 4 ? trimmed.toUpperCase() : trimmed.substring(0, 4).toUpperCase();
}

Future<Uint8List> buildBarcodeLabelsPdf(List<LabelRequest> requests) async {
  final doc = pw.Document();
  final code128 = Barcode.code128();

  // Flatten "this product, N copies" into one cell per physical
  // sticker -- the grid below doesn't know or care which product a
  // cell came from, it just lays out whatever (product, code) pairs
  // it's given. `code` is either every copy's shared product barcode,
  // or -- when uniqueCodes was supplied -- that one sticker's own
  // individually-generated code (see LabelRequest.uniqueCodes).
  final labels = <({Product product, String code})>[];
  for (final request in requests) {
    for (var i = 0; i < request.quantity; i++) {
      final code = (request.uniqueCodes != null && i < request.uniqueCodes!.length)
          ? request.uniqueCodes![i]
          : request.product.barcode;
      labels.add((product: request.product, code: code));
    }
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.copyWith(
        marginLeft: 16,
        marginRight: 16,
        marginTop: 20,
        marginBottom: 20,
      ),
      build: (context) => [
        pw.GridView(
          crossAxisCount: 3,
          childAspectRatio: 0.65,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: labels.map((label) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.BarcodeWidget(
                    barcode: code128,
                    data: label.code,
                    drawText: true,
                    width: 168,
                    height: 70,
                    textStyle: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.SizedBox(height: 4),
                  if (_categoryShortCode(label.product.category).isNotEmpty) ...[
                    pw.Text(
                      _categoryShortCode(label.product.category),
                      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
                    ),
                    pw.SizedBox(height: 2),
                  ],
                  pw.Text(
                    label.product.name,
                    maxLines: 2,
                    overflow: pw.TextOverflow.clip,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );

  return doc.save();
}
