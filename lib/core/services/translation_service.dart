import 'dart:convert';

import 'package:dio/dio.dart';

import '../utils/app_logger.dart';

/// Free English <-> Malayalam text translation for the voice-note
/// feature. Ported directly from a reference Flutter app (confirmed
/// working on the test phone): a plain `dio` GET to Google Translate's
/// free public web endpoint (`translate.googleapis.com`) -- not the
/// paid/billed Cloud Translation API, same no-billing pattern as
/// everywhere else in this app (Firebase Storage, Google Maps,
/// background push).
///
/// That endpoint is unofficial/crawled rather than a documented API,
/// so it can occasionally fail or get rate-limited. Every caller
/// treats a `null` result as "couldn't translate right now" and falls
/// back to keeping the original (untranslated) text -- never a crash,
/// never a blocked save.
class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

  Future<String?> malayalamToEnglish(String text) => translate(text, from: 'ml', to: 'en');

  Future<String?> englishToMalayalam(String text) => translate(text, from: 'en', to: 'ml');

  Future<String?> translate(String text, {required String from, required String to}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    try {
      final response = await _dio.get(
        'https://translate.googleapis.com/translate_a/single',
        queryParameters: {'client': 'gtx', 'sl': from, 'tl': to, 'dt': 't', 'q': trimmed},
      );
      if (response.statusCode == 200) {
        final dynamic decoded = response.data is String ? jsonDecode(response.data) : response.data;
        if (decoded != null && decoded is List && decoded.isNotEmpty) {
          final buffer = StringBuffer();
          for (final item in decoded[0]) {
            if (item is List && item.isNotEmpty) buffer.write(item[0].toString());
          }
          final result = buffer.toString();
          return result.isEmpty ? null : result;
        }
      }
      return null;
    } catch (e, st) {
      AppLogger.error('TranslationService.translate', e, st);
      return null;
    }
  }
}
