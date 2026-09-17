import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

/// A reusable popup for picking which shop/branch to continue into.
///
/// Shown right after login, but only for an account whose login
/// response says it has more than one branch — a single-branch
/// account never sees this at all. Kept as a generic, reusable widget
/// (not baked into the login screen) so the same popup can be reused
/// later for an in-app "switch branch" action, e.g. from Profile,
/// once the owner is managing more than one shop day to day.
class BranchSelectDialog extends StatelessWidget {
  final List<String> branches;

  const BranchSelectDialog({super.key, required this.branches});

  /// Shows the dialog and returns the branch the person picked.
  /// `barrierDismissible: false` — picking a branch isn't optional
  /// once the login response says there's more than one, so tapping
  /// outside the dialog doesn't close it without a choice.
  static Future<String?> show(BuildContext context, {required List<String> branches}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BranchSelectDialog(branches: branches),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Dialog(
      backgroundColor: p.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select your shop',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Your account has more than one branch — choose which one to open.',
              style: TextStyle(fontSize: 13, color: p.textSecondary),
            ),
            const SizedBox(height: 16),
            for (final branch in branches)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(branch),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: p.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront_outlined, size: 18, color: AppColors.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            branch,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.textPrimary),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 18, color: p.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
