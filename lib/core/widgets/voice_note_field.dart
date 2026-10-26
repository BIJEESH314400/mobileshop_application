import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/translation_service.dart';
import '../services/voice_input_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

enum _PendingAction { none, pause, done }

/// Which way a recording should be translated, picked above the box
/// before tapping the mic. `plainEnglish` is the original, untouched
/// behavior -- recognized English speech goes in as-is, no
/// translation. The other two both translate on Done (see
/// `_finishAndClose`), one in each direction.
enum TranslateMode { plainEnglish, englishToMalayalam, malayalamToEnglish }

/// Which language a voice recording (or a tagged run of already-
/// recognized text) is in. See [LanguageTaggedTextController].
enum VoiceLanguage { english, malayalam }

class _TaggedRange {
  int start;
  int end; // exclusive
  final VoiceLanguage language;
  _TaggedRange(this.start, this.end, this.language);
}

/// A [TextEditingController] that remembers which stretches of its
/// text came from a Malayalam voice note's **original** Malayalam
/// words versus that note's **English translation**, so
/// [VoiceNoteFieldBody] can render each in its own color
/// (`AppColors.voiceMalayalam` / `voiceEnglish`) while everything else
/// -- anything typed by hand, or loaded from a previously saved
/// record -- stays the field's normal text color. What's actually
/// *saved* is still just the plain combined string ([text]) -- the
/// color tagging is presentation-only, kept in memory for this
/// screen visit, same as any other in-memory UI state.
///
/// Tagged ranges survive ordinary edits via a simple common-prefix/
/// common-suffix diff against the previous text on every change
/// (cheap, and good enough for a notes field -- not a full diff/patch
/// algorithm). If an edit lands inside a tagged run, that run simply
/// reverts to the plain color rather than risk showing a wrong one.
class LanguageTaggedTextController extends TextEditingController {
  final List<_TaggedRange> _tags = [];
  String _lastText = '';

  @override
  set value(TextEditingValue newValue) {
    _reconcile(newValue.text);
    super.value = newValue;
  }

  void _reconcile(String newText) {
    if (newText == _lastText) return;
    final oldText = _lastText;
    final maxCommon = oldText.length < newText.length ? oldText.length : newText.length;
    var prefix = 0;
    while (prefix < maxCommon && oldText[prefix] == newText[prefix]) {
      prefix++;
    }
    var suffix = 0;
    final maxSuffix = maxCommon - prefix;
    while (suffix < maxSuffix && oldText[oldText.length - 1 - suffix] == newText[newText.length - 1 - suffix]) {
      suffix++;
    }
    final oldRegionStart = prefix;
    final oldRegionEnd = oldText.length - suffix;
    final newRegionEnd = newText.length - suffix;
    final delta = (newRegionEnd - prefix) - (oldRegionEnd - oldRegionStart);

    final kept = <_TaggedRange>[];
    for (final t in _tags) {
      if (t.end <= oldRegionStart) {
        kept.add(t);
      } else if (t.start >= oldRegionEnd) {
        kept.add(_TaggedRange(t.start + delta, t.end + delta, t.language));
      }
      // else: the edit lands inside this tagged run -- drop the tag,
      // the text itself is untouched, it just loses its color.
    }
    _tags
      ..clear()
      ..addAll(kept);
    _lastText = newText;
  }

  /// Appends [malayalamText] (the words as spoken) and [englishText]
  /// (their translation) onto whatever's already in the field,
  /// tagging each run so [buildTextSpan] colors them apart.
  void appendTranslatedVoiceNote({required String malayalamText, required String englishText}) {
    final existing = text.trim();
    final prefix = existing.isEmpty ? '' : '$existing ';
    final newText = '$prefix$malayalamText $englishText';
    final mlStart = prefix.length;
    final mlEnd = mlStart + malayalamText.length;
    final enStart = mlEnd + 1;
    final enEnd = enStart + englishText.length;
    // Apply the text change first -- this runs _reconcile (via the
    // `value` setter above) against the OLD tag list, so the two new
    // runs below are recorded fresh rather than double-shifted.
    value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length));
    _tags.add(_TaggedRange(mlStart, mlEnd, VoiceLanguage.malayalam));
    _tags.add(_TaggedRange(enStart, enEnd, VoiceLanguage.english));
  }

  /// Appends plain, untagged [plainText] -- the ordinary English-voice
  /// behavior, unchanged from before Malayalam support existed.
  void appendPlain(String plainText) {
    final existing = text.trim();
    final newText = existing.isEmpty ? plainText : '$existing $plainText';
    value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, bool withComposing = false}) {
    if (_tags.isEmpty || text.isEmpty) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    final sorted = [..._tags]..sort((a, b) => a.start.compareTo(b.start));
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final t in sorted) {
      final start = t.start.clamp(0, text.length);
      final end = t.end.clamp(0, text.length);
      if (end <= cursor || start >= end) continue; // stale/invalid, skip
      if (start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, start), style: style));
      }
      final color = t.language == VoiceLanguage.malayalam ? AppColors.voiceMalayalam : AppColors.voiceEnglish;
      spans.add(TextSpan(text: text.substring(start, end), style: style?.copyWith(color: color)));
      cursor = end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: style));
    }
    return TextSpan(style: style, children: spans);
  }
}

/// A Description/Notes box that can turn into a WhatsApp-style voice
/// recording card -- for someone who'd rather speak the note than
/// type it (a busy shop, or a customer standing right there, make
/// typing impractical). Tapping the mic swaps the plain text box for
/// a card showing a pulsing "LISTENING..." dot, an `m:ss` timer, a
/// live sound-reactive waveform, and a running quoted transcript
/// preview, with Trash (discard)/Pause/Done (commit) controls.
///
/// A small EN/ML toggle next to the mic picks the spoken language.
/// For English, recognized speech is appended as-is -- unchanged from
/// before Malayalam support existed. For Malayalam, the card shows
/// the Malayalam words live while you're speaking, same as English
/// does; on Done they're translated to English (`TranslationService`)
/// and **only the English translation** is appended to the field --
/// matching a reference voice-translator app's own proven behavior.
/// If translation fails (no signal, the free translate endpoint being
/// flaky), the Malayalam text is kept instead and a snackbar explains
/// why -- never a lost recording.
///
/// Every call site owns its own instance, but they all share one
/// `VoiceInputService` underneath -- see that class's doc comment for
/// why (only one mic/listen session can be active on a device at a
/// time regardless).
///
/// Pausing isn't something the underlying OS speech recognizer truly
/// supports mid-session, so it's simulated: Pause stops the current
/// recognizer session but keeps the card open and the transcript so
/// far on screen; Resume starts a brand-new session (same language)
/// and appends whatever it hears onto the same running transcript.
/// Trash discards everything spoken this recording -- [controller]'s
/// text from before the mic was tapped is left completely untouched
/// either way; only Done merges the spoken transcript into it.
class VoiceNoteFieldBody extends StatefulWidget {
  final LanguageTaggedTextController controller;
  final String hintText;
  final TextStyle textStyle;
  final TextStyle hintStyle;
  final EdgeInsetsGeometry padding;
  final BoxConstraints? constraints;
  final int? minLines;
  final int? maxLines;
  final double borderRadius;

  const VoiceNoteFieldBody({
    super.key,
    required this.controller,
    required this.hintText,
    required this.textStyle,
    required this.hintStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.constraints,
    this.minLines,
    this.maxLines,
    this.borderRadius = 12,
  });

  @override
  State<VoiceNoteFieldBody> createState() => _VoiceNoteFieldBodyState();
}

class _VoiceNoteFieldBodyState extends State<VoiceNoteFieldBody> with SingleTickerProviderStateMixin {
  bool _recording = false;
  bool _paused = false;
  bool _busy = false;
  String? _statusOverride;

  TranslateMode _mode = TranslateMode.plainEnglish;

  String _committedSegments = '';
  String _liveText = '';
  final List<double> _levels = [];

  int _sessionId = 0;
  _PendingAction _pendingAction = _PendingAction.none;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;

  late final AnimationController _dotPulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ticker?.cancel();
    _dotPulse.dispose();
    // Best-effort, fire-and-forget -- if this field is disposed
    // (screen popped, etc.) while still mid-recording, don't leave
    // the shared service's mic session hanging open.
    if (_recording && !_paused) {
      VoiceInputService.instance.cancelListening();
    }
    super.dispose();
  }

  String _joinNonEmpty(List<String> parts) => parts.where((p) => p.trim().isNotEmpty).map((p) => p.trim()).join(' ');

  String get _fullLiveText => _joinNonEmpty([_committedSegments, _liveText]);

  String get _elapsedLabel {
    final s = _stopwatch.elapsed.inSeconds;
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  Future<void> _beginRecording({required bool isResume}) async {
    if (_busy) return;
    setState(() => _busy = true);
    // Explicit permission check before every recording, matching a
    // reference implementation confirmed working reliably -- and no
    // locale pre-check before Malayalam recordings any more: Android's
    // recognizer can often still attempt a language (via its online
    // path) that isn't in the "installed offline languages" list a
    // pre-check would see, so asking it to just try is more reliable
    // than guessing from that list first.
    final permission = await VoiceInputService.instance.ensureMicrophonePermission();
    if (!mounted) return;
    if (permission != VoiceMicPermission.granted) {
      setState(() => _busy = false);
      if (permission == VoiceMicPermission.permanentlyDenied) {
        _showPermissionSettingsDialog();
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Microphone permission is needed to record a voice note')));
      }
      return;
    }
    if (!isResume) {
      _committedSegments = '';
      _liveText = '';
      _levels.clear();
    }
    _sessionId++;
    final mySession = _sessionId;
    final started = await VoiceInputService.instance.startListening(
      localeId: _mode == TranslateMode.malayalamToEnglish ? 'ml-IN' : null,
      onResult: (text, isFinal) {
        if (!mounted || mySession != _sessionId) return;
        setState(() => _liveText = text);
        if (isFinal) _onSegmentFinished(mySession);
      },
      onSoundLevelChange: (level) {
        if (!mounted || mySession != _sessionId) return;
        setState(() {
          _levels.add(level);
          if (_levels.length > 28) _levels.removeAt(0);
        });
      },
    );
    if (!mounted) return;
    if (!started) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Voice input isn't available on this device")));
      return;
    }
    _stopwatch.start();
    _ticker ??= Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
    setState(() {
      _busy = false;
      _recording = true;
      _paused = false;
    });
  }

  void _onSegmentFinished(int sessionId) {
    if (!mounted || sessionId != _sessionId) return;
    final pending = _pendingAction;
    _pendingAction = _PendingAction.none;
    if (pending == _PendingAction.pause) {
      setState(() {
        _committedSegments = _joinNonEmpty([_committedSegments, _liveText]);
        _liveText = '';
        _paused = true;
      });
      _stopwatch.stop();
    } else {
      // Explicit Done, or the recognizer's own silence timeout ending
      // the segment on its own -- either way, wrap up the same as a
      // Done tap would.
      _finishAndClose(commit: true);
    }
  }

  Future<void> _onPausePressed() async {
    if (_busy || _paused) return;
    _pendingAction = _PendingAction.pause;
    setState(() => _busy = true);
    await VoiceInputService.instance.stopListening();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _onDonePressed() async {
    if (_busy) return;
    if (_paused) {
      _finishAndClose(commit: true);
      return;
    }
    _pendingAction = _PendingAction.done;
    setState(() => _busy = true);
    await VoiceInputService.instance.stopListening();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _onTrashPressed() async {
    if (_busy) return;
    _sessionId++; // invalidates any late callback from the cancelled session
    _pendingAction = _PendingAction.none;
    if (_recording && !_paused) {
      await VoiceInputService.instance.cancelListening();
    }
    _finishAndClose(commit: false);
  }

  Future<void> _onResumePressed() => _beginRecording(isResume: true);

  /// Wipes the field instantly -- the small delete icon next to the
  /// mic, separate from the recording card's own Trash button (that
  /// one only discards an in-progress recording; this clears whatever
  /// is already saved in the field, typed or from earlier voice
  /// notes). No confirmation prompt -- it's a plain text field, same
  /// as clearing it by hand with backspace, just immediate.
  void _clearAllText() {
    widget.controller.clear();
  }

  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Microphone permission needed'),
        content: const Text(
          "Voice notes need microphone access, and it's currently turned off for this app. Turn it on from the app's settings to use voice notes.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _finishAndClose({required bool commit}) async {
    if (!mounted) return;
    if (commit) {
      final full = _fullLiveText;
      if (full.isNotEmpty) {
        // Matches the reference app's own flow: the spoken words were
        // already visible live in the card while recording -- on
        // Done, only the translated result goes into the field
        // (appended after whatever was already there, same as plain
        // dictation), not both the original and the translation.
        if (_mode == TranslateMode.malayalamToEnglish) {
          setState(() {
            _busy = true;
            _statusOverride = 'TRANSLATING...';
          });
          final english = await TranslationService.instance.malayalamToEnglish(full);
          if (!mounted) return;
          if (english != null && english.trim().isNotEmpty) {
            widget.controller.appendPlain(english.trim());
          } else {
            widget.controller.appendPlain(full);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text("Couldn't translate right now -- kept the Malayalam text")));
          }
        } else if (_mode == TranslateMode.englishToMalayalam) {
          setState(() {
            _busy = true;
            _statusOverride = 'TRANSLATING...';
          });
          final malayalam = await TranslationService.instance.englishToMalayalam(full);
          if (!mounted) return;
          if (malayalam != null && malayalam.trim().isNotEmpty) {
            widget.controller.appendPlain(malayalam.trim());
          } else {
            widget.controller.appendPlain(full);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text("Couldn't translate right now -- kept the English text")));
          }
        } else {
          widget.controller.appendPlain(full);
        }
      }
    }
    if (!mounted) return;
    _stopwatch
      ..stop()
      ..reset();
    _ticker?.cancel();
    _ticker = null;
    setState(() {
      _recording = false;
      _paused = false;
      _busy = false;
      _statusOverride = null;
      _committedSegments = '';
      _liveText = '';
      _levels.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      constraints: widget.constraints,
      padding: _recording ? const EdgeInsets.all(12) : widget.padding,
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: _recording ? AppColors.danger.withOpacity(0.35) : p.border),
      ),
      child: _recording ? _buildRecordingCard(p) : _buildIdleField(p),
    );
  }

  Widget _buildIdleField(AppPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TranslateModeSelector(
          mode: _mode,
          onChanged: _busy ? null : (m) => setState(() => _mode = m),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                minLines: widget.minLines,
                maxLines: widget.maxLines,
                style: widget.textStyle,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: widget.hintText,
                  hintStyle: widget.hintStyle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) {
                final hasText = widget.controller.text.isNotEmpty;
                return GestureDetector(
                  onTap: (!hasText || _busy) ? null : _clearAllText,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.border)),
                    alignment: Alignment.center,
                    child: Icon(Icons.delete_outline_rounded, size: 15, color: hasText ? AppColors.danger : p.border),
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _busy ? null : () => _beginRecording(isResume: false),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent),
                alignment: Alignment.center,
                child: _busy
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.8, valueColor: AlwaysStoppedAnimation(Colors.white)),
                      )
                    : const Icon(Icons.mic_rounded, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecordingCard(AppPalette p) {
    final transcript = _fullLiveText;
    String listeningLabel;
    switch (_mode) {
      case TranslateMode.englishToMalayalam:
        listeningLabel = 'LISTENING... (EN→ML)';
        break;
      case TranslateMode.malayalamToEnglish:
        listeningLabel = 'LISTENING... (ML→EN)';
        break;
      case TranslateMode.plainEnglish:
        listeningLabel = 'LISTENING...';
        break;
    }
    final pillText = _statusOverride ?? (_paused ? 'PAUSED' : listeningLabel);
    final dotColor = _statusOverride != null ? AppColors.accent : (_paused ? AppColors.warning : AppColors.danger);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (_statusOverride == null && !_paused)
              AnimatedBuilder(
                animation: _dotPulse,
                builder: (_, __) => Opacity(opacity: 0.4 + (_dotPulse.value * 0.6), child: _dot(dotColor)),
              )
            else
              _dot(dotColor),
            const SizedBox(width: 7),
            Text(
              pillText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: _statusOverride != null ? AppColors.accent : (_paused ? AppColors.warningText : AppColors.danger),
              ),
            ),
            const Spacer(),
            Text(_elapsedLabel, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.textSecondary)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 28,
          child: _Waveform(
            levels: _levels,
            color: (_paused || _statusOverride != null) ? p.textSecondary.withOpacity(0.35) : AppColors.accent,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          transcript.isEmpty ? 'Listening…' : '"$transcript"',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: p.textSecondary),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RoundButton(icon: Icons.delete_outline_rounded, bg: AppColors.dangerBg, fg: AppColors.danger, onTap: _busy ? null : _onTrashPressed),
            _RoundButton(
              icon: _paused ? Icons.mic_rounded : Icons.pause_rounded,
              bg: p.background,
              fg: p.textPrimary,
              border: p.border,
              onTap: _busy ? null : (_paused ? _onResumePressed : _onPausePressed),
            ),
            _RoundButton(icon: Icons.check_rounded, bg: AppColors.accent, fg: Colors.white, onTap: _busy ? null : _onDonePressed),
          ],
        ),
      ],
    );
  }

  Widget _dot(Color color) => Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}

/// Sits above the box in its idle state, picking how the next
/// recording should be handled: plain English dictation (no
/// translation -- the original, default behavior), English spoken but
/// written as Malayalam, or Malayalam spoken but written as English.
/// Each option is tinted with the color its result would get
/// (`AppColors.voiceEnglish`/`voiceMalayalam`, or the app's accent
/// color for plain dictation), so the row doubles as a quick legend.
class _TranslateModeSelector extends StatelessWidget {
  final TranslateMode mode;
  final ValueChanged<TranslateMode>? onChanged;
  const _TranslateModeSelector({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(context, 'English', TranslateMode.plainEnglish, AppColors.accent, p),
          _divider(p),
          _segment(context, 'EN → ML', TranslateMode.englishToMalayalam, AppColors.voiceEnglish, p),
          _divider(p),
          _segment(context, 'ML → EN', TranslateMode.malayalamToEnglish, AppColors.voiceMalayalam, p),
        ],
      ),
    );
  }

  Widget _divider(AppPalette p) => Container(
        width: 1,
        height: 14,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        color: p.border,
      );

  Widget _segment(BuildContext context, String label, TranslateMode value, Color activeColor, AppPalette p) {
    final selected = mode == value;
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? activeColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: selected ? activeColor : p.textSecondary),
        ),
      ),
    );
  }
}

/// A simple VU-meter style waveform: the most recent mic sound levels
/// (from `VoiceInputService`'s `onSoundLevelChange`), each drawn as a
/// bar whose height reflects how loud that moment was. Levels arrive
/// in roughly a -2..10 range from the plugin (silence to loud speech);
/// normalized and clamped so a quiet mic still shows faint bars rather
/// than a flat line.
class _Waveform extends StatelessWidget {
  final List<double> levels;
  final Color color;
  static const int _barCount = 28;

  const _Waveform({required this.levels, required this.color});

  @override
  Widget build(BuildContext context) {
    final bars = List<double>.filled(_barCount, 0.08);
    final start = levels.length > _barCount ? levels.length - _barCount : 0;
    for (var i = start; i < levels.length; i++) {
      final norm = ((levels[i] + 2) / 12).clamp(0.08, 1.0);
      bars[_barCount - (levels.length - i)] = norm;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final v in bars)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 4 + (v * 24),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  final Color? border;
  final VoidCallback? onTap;

  const _RoundButton({required this.icon, required this.bg, required this.fg, this.border, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: border != null ? Border.all(color: border!) : null,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: fg),
      ),
    );
  }
}
