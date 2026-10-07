import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

/// Shown by IdleLockGate once 5 minutes of real inactivity (foreground
/// or background) have passed. Styled like the app's other popups
/// (see BranchSelectDialog) rather than a bare default AlertDialog --
/// a plain informational stop, not a choice, so there's only one
/// button and `PopScope(canPop: false)` blocks the back
/// gesture/button, same reasoning as PinUnlockScreen's own lock.
class InactivityAlertDialog extends StatelessWidget {
  const InactivityAlertDialog({super.key});

  /// Shows the dialog and resolves once "OK" is tapped. Not
  /// dismissible any other way -- this isn't a choice, it's a notice
  /// on the way to the PIN unlock screen IdleLockGate shows right
  /// after this resolves.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const InactivityAlertDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.timer_off_rounded, color: AppColors.accent, size: 22),
              ),
              const SizedBox(height: 14),
              Text('App Inactive', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.textPrimary)),
              const SizedBox(height: 6),
              Text(
                "You've been inactive for 5 minutes. For your security, "
                "you'll need to unlock with your PIN to continue.",
                style: TextStyle(fontSize: 13, color: p.textSecondary),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('OK', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
