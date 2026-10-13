import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// Shows the generated label sheet before it leaves the app -- scroll
/// through the pages, zoom in to check the barcodes look right, then
/// either tap Print (sends straight to a connected/Wi-Fi printer or the
/// OS print dialog) or Share (save, email, or send to a print shop).
/// Both buttons are `PdfPreview`'s own built-in actions, not something
/// built by hand here.
///
/// `canChangePageFormat`/`canChangeOrientation` are turned off: the
/// label grid is already laid out for a fixed A4 sheet in
/// `buildBarcodeLabelsPdf`, so letting someone flip to a different page
/// size here wouldn't actually re-flow the labels -- it would just be a
/// control that looks like it does something and doesn't.
class BarcodeLabelsPreviewScreen extends StatelessWidget {
  final Uint8List bytes;

  const BarcodeLabelsPreviewScreen({super.key, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Preview Barcode Labels'),
      ),
      body: PdfPreview(
        build: (format) async => bytes,
        pdfFileName: 'barcode-labels.pdf',
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
      ),
    );
  }
}
