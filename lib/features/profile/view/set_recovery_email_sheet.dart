import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/app_logger.dart';

/// "Recovery Email" dialog, opened from Profile -- lets whoever's
/// signed in (owner or employee) attach a real email to their own
/// account, so Forgot Password actually has somewhere to send a reset
/// link. Every account starts with only a synthetic
/// `<username>@4bmobiles.app` placeholder that nobody can read mail at.
///
/// Deliberately uses `verifyBeforeUpdateEmail`, not the older/simpler
/// `updateEmail` -- Firebase sends a confirmation link to the NEW
/// address first, and the account's actual email only changes once
/// that link is clicked. This means there's a short window right
/// after submitting where the new email isn't "live" yet; the account
/// keeps working exactly as before (same old sign-in) until it is.
/// `CurrentUserRepository.loadCurrentUser()` is what later notices the
/// change went through and keeps `usernames/<username>` in sync -- this
/// dialog itself only ever triggers the Firebase side, nothing else.
Future<void> showSetRecoveryEmailSheet(BuildContext context, {String? currentEmail}) {
  final p = AppPalette.of(context);
  final controller = TextEditingController();
  String? error;
  bool submitting = false;
  bool sent = false;

  final isReal = currentEmail != null && !currentEmail.toLowerCase().endsWith('@4bmobiles.app');

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: p.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recovery Email', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: p.textPrimary)),
                  const SizedBox(height: 6),
                  if (!sent) ...[
                    Text(
                      isReal
                          ? 'Currently: $currentEmail\n\nEnter a new email to change it. We\'ll send a link there to confirm it\'s yours before anything changes.'
                          : "No recovery email set yet -- Forgot Password can't help you until you add one. We'll send a link to confirm it's yours before it's attached to your account.",
                      style: TextStyle(fontSize: 13, color: p.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: p.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: error != null ? AppColors.danger : p.border),
                      ),
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(fontSize: 15, color: p.textPrimary),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                          hintText: 'you@example.com',
                        ),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 6),
                      Text(error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: submitting ? null : () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: p.border),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text('Cancel', style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: submitting
                                ? null
                                : () async {
                                    final email = controller.text.trim();
                                    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
                                    if (!valid) {
                                      setDialogState(() => error = 'Enter a valid email address');
                                      return;
                                    }
                                    setDialogState(() {
                                      submitting = true;
                                      error = null;
                                    });
                                    try {
                                      await FirebaseAuth.instance.currentUser!.verifyBeforeUpdateEmail(email);
                                      setDialogState(() {
                                        submitting = false;
                                        sent = true;
                                      });
                                    } on FirebaseAuthException catch (e) {
                                      setDialogState(() {
                                        submitting = false;
                                        error = _messageFor(e);
                                      });
                                    } catch (e, st) {
                                      AppLogger.error('showSetRecoveryEmailSheet (verifyBeforeUpdateEmail)', e, st);
                                      setDialogState(() {
                                        submitting = false;
                                        error = "Couldn't send the link -- check your connection and try again";
                                      });
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                                  )
                                : const Text('Send Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        const Icon(Icons.mark_email_read_rounded, color: AppColors.success, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "We've sent a confirmation link to ${controller.text.trim()}. Click it there, and this becomes your account's real recovery email.",
                            style: TextStyle(fontSize: 13, color: p.textPrimary, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

String _messageFor(FirebaseAuthException e) {
  switch (e.code) {
    case 'email-already-in-use':
      return 'That email is already used by another account';
    case 'invalid-email':
      return 'Enter a valid email address';
    case 'requires-recent-login':
      return 'Please log out and log back in, then try again';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again';
    case 'network-request-failed':
      return 'No internet connection. Please check your network';
    default:
      return "Couldn't send the link. Please try again";
  }
}
