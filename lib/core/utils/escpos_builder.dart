import 'dart:convert';
import 'dart:typed_data';

/// Minimal ESC/POS byte builder for a Bluetooth thermal receipt
/// printer -- the same command bytes a reference Android app's own
/// PrinterCommands.kt used (ESC/POS is a de-facto standard almost
/// every cheap thermal printer, Visiontek included, understands),
/// just built directly as a byte buffer here instead of that app's
/// `<0x00>`/`<0x0A>` string-tag scheme -- same bytes, simpler from Dart.
///
/// Text is encoded as latin1 -- plain ESC/POS printers have no real
/// Unicode support, so a currency figure uses "Rs." rather than the
/// real "₹" sign here (the PDF receipt elsewhere in this app keeps
/// the real ₹ symbol, since PDF rendering has proper font support).
class EscPosBuilder {
  final List<int> _bytes = [];

  EscPosBuilder() {
    _bytes.addAll([0x1B, 0x40]); // ESC @ -- reset the printer to its default state
  }

  /// Writes [value] as plain text with no trailing line feed -- call
  /// [line]/[feed] separately to move to the next line.
  EscPosBuilder text(String value, {bool bold = false, bool doubleWidth = false, bool center = false}) {
    _bytes.addAll([0x1B, 0x61, center ? 0x01 : 0x00]); // ESC a n -- alignment
    _bytes.addAll([0x1B, 0x45, bold ? 0x01 : 0x00]); // ESC E n -- emphasized (bold)
    _bytes.addAll([0x1D, 0x21, doubleWidth ? 0x11 : 0x00]); // GS ! n -- character size (double w+h when set)
    _bytes.addAll(latin1.encode(value));
    return this;
  }

  /// Writes [value] (if any) then a line feed -- the normal way to
  /// add one line of plain, non-bold, left-aligned text.
  EscPosBuilder line([String value = '']) {
    if (value.isNotEmpty) text(value);
    _bytes.add(0x0A); // LF
    return this;
  }

  /// A full-width dashed divider line.
  EscPosBuilder divider({int width = 32, String char = '-'}) => line(char * width);

  /// [lines] blank lines -- used at the end of a receipt so the last
  /// printed line isn't left sitting right against the tear bar.
  EscPosBuilder feed([int lines = 3]) {
    for (var i = 0; i < lines; i++) {
      _bytes.add(0x0A);
    }
    return this;
  }

  Uint8List build() => Uint8List.fromList(_bytes);
}
