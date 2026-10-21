import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../utils/app_logger.dart';

/// Thin app-wide wrapper around the `speech_to_text` plugin -- one
/// shared `stt.SpeechToText` instance, since only one listen session
/// can ever be active on a device at a time anyway (starting a second
/// one while the first is still running isn't a case any screen in
/// this app needs to support). `VoiceMicButton` is the only caller --
/// see its own doc comment for the actual UI/tap behavior.
///
/// Deliberately on-device, free, no API key: `speech_to_text` talks to
/// the OS's own speech recognizer (Android `SpeechRecognizer` / iOS
/// `Speech` framework), not a cloud service of ours -- consistent with
/// every other "avoid a paid/billing dependency" choice already made
/// in this app (Firebase Storage, Google Maps, true background push).
class VoiceInputService {
  VoiceInputService._();
  static final VoiceInputService instance = VoiceInputService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;
  bool _initFailed = false;

  bool get isListening => _speech.isListening;

  /// `initialize()` is itself what triggers the OS's microphone/speech
  /// permission prompt the first time it's called -- no separate
  /// permission package needed. Cached after the first attempt (success
  /// OR failure) so a denied/unsupported device doesn't re-prompt on
  /// every single tap of the mic button; [reset] (not used today, kept
  /// for completeness) would let a caller force a fresh check if that
  /// ever changes.
  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    if (_initFailed) return false;
    try {
      _initialized = await _speech.initialize(
        onError: (e) => AppLogger.error('VoiceInputService.initialize.onError', e.errorMsg, null),
        onStatus: (_) {},
      );
    } catch (e, st) {
      AppLogger.error('VoiceInputService.initialize', e, st);
      _initialized = false;
    }
    _initFailed = !_initialized;
    return _initialized;
  }

  /// Starts listening. [onResult] fires once, with the final
  /// recognized text, when speech recognition actually finishes --
  /// either because [stopListening] was called, or because
  /// `speech_to_text`'s own silence timeout ([pauseFor]) fired on its
  /// own. Returns false (and never starts listening) if the device
  /// has no speech recognizer available or the permission was denied
  /// -- the caller (`VoiceMicButton`) is responsible for telling the
  /// person that, since this service has no BuildContext of its own.
  Future<bool> startListening({required void Function(String text) onResult}) async {
    final ok = await _ensureInitialized();
    if (!ok) return false;
    try {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
            onResult(result.recognizedWords.trim());
          }
        },
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 5),
        partialResults: false,
      );
      return true;
    } catch (e, st) {
      AppLogger.error('VoiceInputService.startListening', e, st);
      return false;
    }
  }

  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (e, st) {
      AppLogger.error('VoiceInputService.stopListening', e, st);
    }
  }
}
