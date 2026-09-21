import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../bloc/forgot_password_bloc.dart';
import '../bloc/forgot_password_event.dart';
import '../bloc/forgot_password_state.dart';

/// Forgot Password — wired to Firebase for real. Looks up the
/// username's real email (UsernameLookupRepository, the `usernames`
/// Firestore collection) and asks Firebase Auth to send an actual
/// reset email to it. Requires that collection to have a document for
/// the username being reset, and that account's Firebase Auth email
/// to match — see the project status doc.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ForgotPasswordBloc(),
      child: const _ForgotPasswordView(),
    );
  }
}

class _ForgotPasswordView extends StatefulWidget {
  const _ForgotPasswordView();

  @override
  State<_ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<_ForgotPasswordView> {
  final _usernameController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return BlocConsumer<ForgotPasswordBloc, ForgotPasswordState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: p.background,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: p.card,
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(color: p.border),
                              ),
                              child: Icon(Icons.arrow_back_rounded, size: 18, color: p.textPrimary),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(Icons.lock_reset_rounded, color: Colors.white),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Forgot password?',
                            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700, color: p.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            state.isSuccess
                                ? "We've sent a reset link to the email on file for this account."
                                : "Enter your username and we'll send a password reset link to the email on file.",
                            style: TextStyle(fontSize: 14, color: p.textSecondary, height: 1.4),
                          ),
                          const SizedBox(height: 28),
                          if (!state.isSuccess) ...[
                            _ForgotField(palette: p, controller: _usernameController),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: state.isSubmitting
                                    ? null
                                    : () => context.read<ForgotPasswordBloc>().add(
                                          ForgotPasswordSubmitted(username: _usernameController.text),
                                        ),
                                child: state.isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                                      )
                                    : const Text('Send Reset Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.successBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.mark_email_read_rounded, color: AppColors.success, size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Check your inbox for the reset link.',
                                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.success),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const Spacer(),
                          Center(
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.arrow_back_rounded, size: 15, color: AppColors.accent),
                                  const SizedBox(width: 5),
                                  const Text(
                                    'Back to Sign In',
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.accent),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ForgotField extends StatelessWidget {
  final AppPalette palette;
  final TextEditingController controller;

  const _ForgotField({required this.palette, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Username', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.textPrimary)),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          style: TextStyle(color: palette.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: palette.inputFill,
            hintText: 'Enter your username',
            hintStyle: TextStyle(color: palette.textSecondary, fontSize: 14),
            prefixIcon: Icon(Icons.person_outline_rounded, size: 18, color: palette.textSecondary),
            prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 20),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent)),
          ),
        ),
      ],
    );
  }
}
