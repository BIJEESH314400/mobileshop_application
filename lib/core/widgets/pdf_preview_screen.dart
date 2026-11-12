import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../theme/app_palette.dart';

/// Shows a PDF on screen before it's shared or printed -- wraps the
/// `printing` package's own `PdfPreview` widget (same package already
/// used for every `Printing.sharePdf` call in this app), which gives a
/// live, pinch-zoomable preview plus its own built-in Share/Print
/// buttons in the toolbar. Added 2026-11-12 so the owner/employee can
/// actually see what a report or receipt looks like before sending it
/// anywhere, instead of it going straight to the OS share sheet
/// sight-unseen. [bytes] is already-built PDF data (none of this
/// app's PDF builders vary their output by page format), so [build]
/// below just hands it back as-is regardless of what format the
/// preview widget asks for.
class PdfPreviewScreen extends StatelessWidget {
  final String title;
  final String fileName;
  final Uint8List bytes;

  const PdfPreviewScreen({super.key, required this.title, required this.fileName, required this.bytes});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              decoration: BoxDecoration(color: p.background, border: Border(bottom: BorderSide(color: p.border))),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back_rounded, size: 20, color: p.textPrimary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PdfPreview(
                build: (format) async => bytes,
                pdfFileName: fileName,
                allowPrinting: true,
                allowSharing: true,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
