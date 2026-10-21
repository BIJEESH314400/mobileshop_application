import 'package:flutter/material.dart';

import '../services/voice_input_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

/// Small mic icon button dropped next to a Description/Notes field's
/// label, for someone who'd rather speak the note than type it (a big
/// shop may be too busy, or a customer standing right there, for
/// typing to be practical). Tap once to start listening, tap again to
/// stop -- the recognized text is then appended to [controller]'s
/// existing text (never silently overwrites whatever was already
/// typed), same "speak the whole note, see it appear once you're
/// done" behavior everywhere this button is used across the app.
///
/// Every call site owns its own `VoiceMicButton` instance, but they
/// all share one `VoiceInputService` underneath -- see that class's
/// doc comment for why (only one mic/listen session can be active on
/// a device at a time regardless).
class VoiceMicButton extends StatefulWidget {
  final TextEditingController controller;
  const VoiceMicButton({super.key, required this.controller});

  @override
  State<VoiceMicButton> createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends State<VoiceMicButton> with SingleTickerProviderStateMixin {
  bool _listening = false;
  bool _processing = false;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    // Best-effort, fire-and-forget -- if this button is disposed
    // (screen popped, etc.) while still mid-listen, don't leave the
    // shared service's mic session hanging open. Same "cleanup in
    // dispose, don't await it" convention as ConversationScreen's own
    // typing-flag clear.
    if (_listening) {
      VoiceInputService.instance.stopListening();
    }
    super.dispose();
  }

  void _insertText(String text) {
    final existing = widget.controller.text.trim();
    final combined = existing.isEmpty ? text : '$existing $text';
    widget.controller.text = combined;
    widget.controller.selection = TextSelection.fromPosition(TextPosition(offset: combined.length));
  }

  Future<void> _onTap() async {
    if (_listening) {
      setState(() => _processing = true);
      await VoiceInputService.instance.stopListening();
      // The pending listen's onResult callback (below) is what
      // actually flips _listening/_processing back off once the
      // final transcript arrives -- not this call itself.
      return;
    }

    final started = await VoiceInputService.instance.startListening(
      onResult: (text) {
        if (!mounted) return;
        _insertText(text);
        setState(() {
          _listening = false;
          _processing = false;
        });
      },
    );
    if (!mounted) return;
    if (started) {
      setState(() => _listening = true);
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Voice input isn't available on this device")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final scale = _listening ? 1.0 + (_pulse.value * 0.12) : 1.0;
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _listening ? AppColors.danger : Colors.transparent,
            border: Border.all(color: _listening ? AppColors.danger : p.border),
          ),
          alignment: Alignment.center,
          child: _processing
              ? SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.8, valueColor: AlwaysStoppedAnimation(_listening ? Colors.white : p.textSecondary)),
                )
              : Icon(
                  _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  size: 15,
                  color: _listening ? Colors.white : p.textSecondary,
                ),
        ),
      ),
    );
  }
}
