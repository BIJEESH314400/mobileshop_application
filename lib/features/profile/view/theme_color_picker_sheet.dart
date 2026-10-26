import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme_color.dart';
import '../../theme/bloc/theme_bloc.dart';
import '../../theme/bloc/theme_event.dart';

/// "App Theme" picker, opened from Profile -- lets anyone signed in
/// pick which of the 6 accent-color themes the whole app uses (2026-10-22).
/// Separate from Dark Mode: this only changes the brand accent color
/// (buttons, highlights, selected states); light/dark stays its own
/// independent switch right above this row.
///
/// Tapping a swatch dispatches straight to the app-wide ThemeBloc and
/// closes -- no separate "Save" step, same immediate-effect pattern as
/// the Dark Mode switch itself.
Future<void> showThemeColorPickerSheet(BuildContext context, {required AppThemeColor current}) {
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
              Text('App Theme', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.textPrimary)),
              const SizedBox(height: 4),
              Text(
                'Changes the app\'s accent color everywhere. Dark Mode stays separate.',
                style: TextStyle(fontSize: 12, color: p.textSecondary),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final theme in AppThemeColor.values)
                    _ThemeSwatch(
                      theme: theme,
                      selected: theme == current,
                      palette: p,
                      onTap: () {
                        bloc.add(ThemeColorChanged(theme));
                        Navigator.of(dialogContext).pop();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ThemeSwatch extends StatelessWidget {
  final AppThemeColor theme;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onTap;

  const _ThemeSwatch({required this.theme, required this.selected, required this.palette, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.color,
                border: selected ? Border.all(color: palette.textPrimary, width: 2.5) : null,
              ),
              alignment: Alignment.center,
              child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 22) : null,
            ),
            const SizedBox(height: 6),
            Text(
              theme.label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? palette.textPrimary : palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
