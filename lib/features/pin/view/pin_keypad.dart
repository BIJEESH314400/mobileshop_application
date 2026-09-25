import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';

/// A row of small circles showing how many of the PIN's digits have
/// been entered so far -- filled + accent once typed, outlined red
/// (all of them, briefly) when the just-submitted PIN was wrong. Shared
/// by PinUnlockScreen and SetPinScreen so both look identical.
class PinDots extends StatelessWidget {
  final int length;
  final int filled;
  final bool error;
  const PinDots({super.key, required this.length, required this.filled, required this.error});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(length, (i) {
        final isFilled = i < filled;
        final color = error ? AppColors.danger : AppColors.accent;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (error || isFilled) ? color : Colors.transparent,
            border: Border.all(color: color, width: 1.6),
          ),
        );
      }),
    );
  }
}

/// A plain 3x4 numeric keypad (1-9, blank, 0, backspace) -- no phone-
/// dialer letters, just digits, matching a simple app-unlock PIN rather
/// than a real phone keypad. Shared by PinUnlockScreen and SetPinScreen.
class PinKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;
  const PinKeypad({super.key, required this.onDigit, required this.onBackspace, this.enabled = true});

  static const _layout = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'];

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.6,
      children: _layout.map((key) {
        if (key.isEmpty) return const SizedBox.shrink();
        final isBackspace = key == 'back';
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: !enabled ? null : (isBackspace ? onBackspace : () => onDigit(key)),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.border),
            ),
            child: isBackspace
                ? Icon(Icons.backspace_outlined, size: 19, color: palette.textPrimary)
                : Text(key, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: palette.textPrimary)),
          ),
        );
      }).toList(),
    );
  }
}
