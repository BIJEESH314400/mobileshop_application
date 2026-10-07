import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

/// Shared "are you sure" confirmation for every delete/remove action in
/// the app (Products, Customers, Service Jobs, Employees).
///
/// Redesigned 2026-10-06 (twice): first from a bare default
/// `AlertDialog` to an app-styled centered `Dialog`, then again from
/// that centered dialog to this bottom sheet -- the user shared a
/// reference screenshot of a "DANGER ZONE" bottom-sheet style (drag
/// handle, red eyebrow label, icon circle, stacked full-width buttons
/// with the item name baked into each label) and asked for that shape
/// specifically. Content (title/message/button wording) stays whatever
/// each call site already had -- only the container changed from a
/// centered popup to a sheet.
class ConfirmDeleteDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  const ConfirmDeleteDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  /// Shows the sheet and resolves to true only if the destructive
  /// button was tapped -- tapping "Keep ...", the scrim, or swiping the
  /// sheet down all resolve to false.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ConfirmDeleteDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(color: p.divider, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 18),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.delete_outline_rounded, size: 26, color: AppColors.danger),
            ),
            const SizedBox(height: 14),
            const Text(
              'DANGER ZONE',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.danger, letterSpacing: 0.8),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: p.textSecondary, height: 1.45),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(true),
              child: Container(
                width: double.infinity,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      confirmLabel,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(false),
              child: Container(
                width: double.infinity,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.background, borderRadius: BorderRadius.circular(14)),
                child: Text(
                  cancelLabel,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.textPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
