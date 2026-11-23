import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/theme/app_palette.dart';
import '../../theme/bloc/theme_bloc.dart';
import '../../theme/bloc/theme_event.dart';

/// "Font Style" picker, opened from Profile -- lets anyone signed in
/// pick which of the 5 app-wide fonts the whole app uses (2026-11-20).
/// Separate from App Theme (accent color) and Dark Mode: this only
/// changes the font family read by ThemeData.fontFamily (see
/// buildAppTheme()/buildAppDarkTheme()); everything else about a
/// screen's look stays the same.
///
/// Each row renders its own label IN that font -- a real preview, not
/// just a name. Tapping dispatches straight to the app-wide ThemeBloc
/// and closes -- no separate "Save" step, same immediate-effect
/// pattern as App Theme / Dark Mode.
Future<void> showFontPickerSheet(BuildContext context, {required AppFont current}) {
  final p = AppPalette.of(context);
  final bloc = context.read<ThemeBloc>();

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Font Style', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.textPrimary)),
              const SizedBox(height: 4),
              Text(
                'Changes the font used everywhere in the app.',
                style: TextStyle(fontSize: 12, color: p.textSecondary),
              ),
              const SizedBox(height: 10),
              for (final font in AppFont.values)
                _FontRow(
                  font: font,
                  selected: font == current,
                  palette: p,
                  onTap: () {
                    bloc.add(ThemeFontChanged(font));
                    Navigator.of(dialogContext).pop();
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _FontRow extends StatelessWidget {
  final AppFont font;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onTap;

  const _FontRow({required this.font, required this.selected, required this.palette, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                font.label,
                // The actual preview -- rendered in the font it names,
                // not the dialog's own ambient font. `fontFamily: null`
                // (systemDefault) falls back to the platform default
                // exactly like it does app-wide.
                style: TextStyle(
                  fontFamily: font.fontFamily,
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? palette.textPrimary : palette.textSecondary,
                ),
              ),
            ),
            if (selected) Icon(Icons.check_rounded, color: AppColors.accent, size: 20),
          ],
        ),
      ),
    );
  }
}
