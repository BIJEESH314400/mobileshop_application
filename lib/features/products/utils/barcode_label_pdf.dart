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

  const LabelRequest({required this.product, required this.quantity});
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
Future<Uint8List> buildBarcodeLabelsPdf(List<LabelRequest> requests) async {
  final doc = pw.Document();
  final code128 = Barcode.code128();

  // Flatten "this product, N copies" into one cell per physical
  // sticker -- the grid below doesn't know or care which product a
  // cell came from, it just lays out whatever list it's given.
  final labels = <Product>[];
  for (final request in requests) {
    for (var i = 0; i < request.quantity; i++) {
      labels.add(request.product);
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
          children: labels.map((product) {
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
                    data: product.barcode,
                    drawText: true,
                    width: 168,
                    height: 70,
                    textStyle: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    product.name,
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
