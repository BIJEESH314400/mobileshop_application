/// Short, fixed-length, letters-only tag derived from a free-text name
/// (a product's category or brand) -- built for embedding in a
/// generated unique unit code (see
/// `ProductUnitRepository.generateUnits`), so a code reads as
/// something like "SP-SAM-00000001" instead of a meaningless number.
///
/// A multi-word name becomes an initialism of its first `length`
/// words -- "Smart Phone" -> "SP". A single word is just truncated to
/// `length` characters -- "Samsung" -> "SAM", "Flowers" -> "FLO".
/// Either way the result is always exactly `length` characters (short
/// input is padded with "X") so every generated code has the same
/// predictable shape regardless of how long the real category/brand
/// name is.
///
/// Returns '' for blank input -- deciding what to show instead (e.g.
/// "XXX" for a product with no brand set) is the caller's call, not
/// this function's; it only does the lettering.
///
/// This is a separate, shorter scheme from `barcode_label_pdf.dart`'s
/// own `_categoryShortCode` (which prints a 2-4 letter category tag
/// directly on the sticker) -- the two don't need to agree, since one
/// feeds a printed hint and this one feeds a machine-checked unique
/// code, but don't be surprised if they abbreviate the same category
/// slightly differently.
String codeShortName(String input, {int length = 3}) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return '';

  final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  String letters;
  if (words.length > 1) {
    letters = words.map((w) => w[0]).take(length).join();
  } else {
    letters = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  }
  letters = letters.toUpperCase();

  if (letters.isEmpty) return '';
  if (letters.length >= length) return letters.substring(0, length);
  return letters.padRight(length, 'X');
}
