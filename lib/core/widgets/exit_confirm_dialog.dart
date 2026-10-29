import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

/// Shown when the user presses the system back button while on one of
/// the app's root tab screens (Home/Dashboard today -- see
/// DashboardScreen for the reference usage). Those screens are reached
/// via AppBottomNav's `pushReplacement` tab switching, so none of them
/// have anything left in the navigation stack to pop back to -- without
/// this, Android's default behavior is to close the app immediately
/// with no warning at all.
///
/// Shaped like the app's shared `ConfirmDeleteDialog` bottom sheet
/// (drag handle, centered icon circle, centered title/message, stacked
/// full-width buttons) rather than a centered popup -- changed
/// 2026-10-28 from an earlier centered-`Dialog` version with a
/// left-aligned icon and side-by-side buttons, to match that
/// established in-app sheet style instead.
class ExitConfirmDialog extends StatelessWidget {
  const ExitConfirmDialog({super.key});

  /// Shows the sheet and resolves `true` only if "Exit" was tapped --
  /// tapping Cancel, the scrim, or swiping the sheet down all resolve
  /// to `false`. Call this from a screen's `PopScope.onPopInvoked` and
  /// call `SystemNavigator.pop()` if it resolves `true`.
  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ExitConfirmDialog(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
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
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(Icons.exit_to_app_rounded, size: 26, color: AppColors.accent),
            ),
            const SizedBox(height: 14),
            Text(
              'Exit App?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to close 4B Mobiles?',
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
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.exit_to_app_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text(
                      'Exit',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
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
                  'Cancel',
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
