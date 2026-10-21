import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../utils/app_logger.dart';

/// Thin app-wide wrapper around the `speech_to_text` plugin -- one
/// shared `stt.SpeechToText` instance, since only one listen session
/// can ever be active on a device at a time anyway. `VoiceNoteFieldBody`
/// (`lib/core/widgets/voice_note_field.dart`) is the only caller --
/// see its own doc comment for the actual recording-card UI/behavior.
///
/// Deliberately on-device, free, no API key: `speech_to_text` talks to
/// the OS's own speech recognizer (Android `SpeechRecognizer` / iOS
/// `Speech` framework), not a cloud service of ours -- consistent with
/// every other "avoid a paid/billing dependency" choice already made
/// in this app (Firebase Storage, Google Maps, true background push).
enum VoiceMicPermission { granted, denied, permanentlyDenied }

class VoiceInputService {
  VoiceInputService._();
  static final VoiceInputService instance = VoiceInputService._();

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool get isListening => _speech.isListening;

  /// Explicitly requests the microphone (and, on iOS, Speech
  /// Recognition) permission before listening -- matching a reference
  /// implementation confirmed working reliably, rather than relying
  /// only on [startListening]'s own implicit prompt inside
  /// `initialize()`. Call this first so a permanently denied
  /// permission can be told apart from "not asked yet" and the caller
  /// can offer to open the OS settings screen. `Permission.speech` is
  /// a no-op on Android (always granted) and maps to the iOS Speech
  /// framework permission there.
  Future<VoiceMicPermission> ensureMicrophonePermission() async {
    final micStatus = await Permission.microphone.status;
    final speechStatus = await Permission.speech.status;
    if (micStatus.isPermanentlyDenied || speechStatus.isPermanentlyDenied) {
      return VoiceMicPermission.permanentlyDenied;
    }
    final results = await [Permission.microphone, Permission.speech].request();
    if (results[Permission.microphone]?.isGranted ?? false) {
      return VoiceMicPermission.granted;
    }
    final anyPermanentlyDenied = results.values.any((s) => s.isPermanentlyDenied);
    return anyPermanentlyDenied ? VoiceMicPermission.permanentlyDenied : VoiceMicPermission.denied;
  }

  /// Re-initializes the recognizer fresh on every call -- deliberately
  /// NOT cached/short-circuited after a failure. An early transient
  /// failure (a slow permission dialog, a recognizer service that
  /// hadn't finished binding yet, etc.) used to permanently "stick"
  /// this service as broken for the rest of the app session; always
  /// retrying matches the reference implementation and costs very
  /// little since `initialize()` itself is cheap once permission is
  /// already granted.
  Future<bool> _ensureInitialized() async {
    try {
      return await _speech.initialize(
        onError: (e) => AppLogger.error('VoiceInputService.initialize.onError', e.errorMsg, null),
        onStatus: (_) {},
      );
    } catch (e, st) {
      AppLogger.error('VoiceInputService.initialize', e, st);
      return false;
    }
  }

  /// Starts listening. [onResult] fires repeatedly as recognition
  /// makes progress: `isFinal: false` for a live partial guess (for
  /// the recording card's running transcript preview), and once more
  /// with `isFinal: true` when the session actually ends -- either
  /// because [stopListening] was called, or because `speech_to_text`'s
  /// own silence timeout ([pauseFor]) fired on its own. [onSoundLevelChange]
  /// (when given) fires continuously with the mic's current input
  /// level, for the recording card's live waveform. Returns false (and
  /// never starts listening) if the device has no speech recognizer
  /// available or the permission was denied -- the caller is
  /// responsible for telling the person that, since this service has
  /// no BuildContext of its own.
  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    void Function(double level)? onSoundLevelChange,
    String? localeId,
  }) async {
    final ok = await _ensureInitialized();
    if (!ok) return false;
    try {
      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords.trim();
          if (text.isNotEmpty || result.finalResult) {
            onResult(text, result.finalResult);
          }
        },
        onSoundLevelChange: onSoundLevelChange,
        localeId: localeId,
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 8),
        partialResults: true,
      );
      return true;
    } catch (e, st) {
      AppLogger.error('VoiceInputService.startListening', e, st);
      return false;
    }
  }

  /// Whether the device's own speech recognizer has a locale
  /// installed whose id starts with [languagePrefix] (e.g. `'ml'` for
  /// any Malayalam variant, case-insensitive) -- checked before
  /// starting a Malayalam recording so a device that doesn't have it
  /// gets a clear message instead of silently recognizing nothing (or
  /// the wrong language) once it starts listening.
  Future<bool> isLocaleSupported(String languagePrefix) async {
    final ids = await availableLocaleIds();
    final prefix = languagePrefix.toLowerCase();
    return ids.any((id) => id.toLowerCase().startsWith(prefix));
  }

  /// The locale ids the device's own speech recognizer currently
  /// offers (e.g. `en-IN`, `hi-IN`...), straight from `speech_to_text`
  /// -- used to tell [isLocaleSupported]'s caller exactly what IS
  /// available when the one they wanted isn't, so a missing language
  /// can be told apart from the recognizer being unavailable/denied
  /// entirely (an empty list either way, but worth knowing which).
  Future<List<String>> availableLocaleIds() async {
    final ok = await _ensureInitialized();
    if (!ok) return [];
    try {
      final locales = await _speech.locales();
      return locales.map((l) => l.localeId).toList();
    } catch (e, st) {
      AppLogger.error('VoiceInputService.availableLocaleIds', e, st);
      return [];
    }
  }

  /// Ends the current session and keeps whatever was recognized --
  /// the pending [startListening] call's `onResult` still fires once
  /// more with `isFinal: true` for the finished transcript. Used by
  /// the recording card's Pause and Done buttons.
  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (e, st) {
      AppLogger.error('VoiceInputService.stopListening', e, st);
    }
  }

  /// Ends the current session and throws away whatever was mid-
  /// recognition -- unlike [stopListening], the caller should not
  /// expect a further `isFinal: true` transcript to arrive after
  /// this. Used by the recording card's Trash/discard button.
  Future<void> cancelListening() async {
    try {
      await _speech.cancel();
    } catch (e, st) {
      AppLogger.error('VoiceInputService.cancelListening', e, st);
    }
  }
}
