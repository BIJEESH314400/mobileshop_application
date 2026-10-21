import 'package:translator/translator.dart';

import '../utils/app_logger.dart';

/// Free Malayalam -> English text translation for the voice-note
/// feature, via the `translator` package (talks to Google Translate's
/// public web endpoint, not the paid/billed Cloud Translation API --
/// same "avoid a billing dependency" choice already made elsewhere in
/// this app for Firebase Storage, Google Maps, and background push).
///
/// That endpoint is unofficial/crawled rather than a documented API,
/// so it can occasionally fail or get rate-limited. Every caller
/// treats a `null` result as "couldn't translate right now" and
/// falls back to keeping just the Malayalam text -- never a crash,
/// never a blocked save, same fail-open shape as this app's other
/// best-effort network reads.
class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  final GoogleTranslator _translator = GoogleTranslator();

  Future<String?> malayalamToEnglish(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    try {
      final result = await _translator.translate(trimmed, from: 'ml', to: 'en');
      return result.text;
    } catch (e, st) {
      AppLogger.error('TranslationService.malayalamToEnglish', e, st);
      return null;
    }
  }
}
