/// Capitalizes the first letter of each word and lowercases the rest
/// -- "smart phone" -> "Smart Phone", "SAMSUNG" -> "Samsung", "sAmSung"
/// -> "Samsung". Used when the owner types a brand-new category or
/// brand name (Manage Categories & Brands' "+ Category"/"+ Brand"
/// sheets), so a name ends up the same consistent "Title Case" look no
/// matter which way it was typed, instead of showing exactly however
/// that one entry happened to be typed in.
///
/// Also collapses any run of whitespace between words down to one
/// space, and trims the ends -- "  smart   phone  " -> "Smart Phone".
///
/// This is plain word-by-word capitalization, not a dictionary of
/// brand-specific casing -- a brand typed as "iphone" becomes "Iphone"
/// here, not "iPhone". Good enough for the general look being asked
/// for; it always normalizes (there's no way to type around it to get
/// a different capitalization), and it only runs on fresh adds -- it
/// doesn't retroactively change any category/brand already saved
/// before this existed.
String toTitleCase(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return trimmed;
  final words = trimmed.split(RegExp(r'\s+'));
  return words.map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}
