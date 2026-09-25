import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/routes/root_navigator_key.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/branch_select_dialog.dart';
import '../../pin/view/pin_unlock_screen.dart';
import '../../pin/view/set_pin_screen.dart';
import '../bloc/login_bloc.dart';
import '../bloc/login_event.dart';
import '../bloc/login_state.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginBloc(),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature — coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return BlocConsumer<LoginBloc, LoginState>(
      listener: (context, state) async {
        // Branch selection first — an account with more than one shop
        // stops here after a valid username/password until the popup
        // resolves, rather than logging straight in.
        if (state.needsBranchSelection) {
          final branch = await BranchSelectDialog.show(context, branches: state.availableBranches);
          if (branch != null && context.mounted) {
            context.read<LoginBloc>().add(BranchSelected(branchId: branch));
          }
          return;
        }
        if (state.isSuccess) {
          if (state.needsPin) {
            // Same pattern as Splash's authenticatedNeedsPin branch:
            // rootNavigatorKey for the delayed onUnlocked callback
            // (fires later, after this screen's own context may be
            // gone), plain context for the immediate replacement below
            // (still safe -- it runs synchronously in this listener).
            Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => PinUnlockScreen(
                onUnlocked: () =>
                    rootNavigatorKey.currentState?.pushReplacementNamed(AppRoutes.dashboard),
              ),
            ));
          } else if (state.needsSetPin) {
            // No PIN saved for this account yet -- Quick PIN is now a
            // required step of logging in (2026-09-25), not something
            // left for Profile later. SetPinScreen's mandatory mode
            // (onSetupComplete set) hides its back arrow and can't be
            // popped, same reasoning as the onUnlocked callback above.
            Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => SetPinScreen(
                onSetupComplete: () =>
                    rootNavigatorKey.currentState?.pushReplacementNamed(AppRoutes.dashboard),
              ),
            ));
          } else {
            Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
          }
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: p.background,

          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 56),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.smartphone_rounded, color: Colors.white),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Welcome back',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700, color: p.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to manage your shop',
                    style: TextStyle(fontSize: 14, color: p.textSecondary),
                  ),
                  const SizedBox(height: 28),
                  _LabeledField(
                    palette: p,
                    label: 'Username',
                    controller: _usernameController,
                    icon: Icons.person_outline_rounded,
                    hintText: 'Enter your username',
                  ),
                  const SizedBox(height: 16),
                  _LabeledField(
                    palette: p,
                    label: 'Password',
                    controller: _passwordController,
                    icon: Icons.lock_outline_rounded,
                    hintText: '••••••••••',
                    obscureText: true,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pushNamed(AppRoutes.forgotPassword),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent),
                      ),
                    ),
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(state.errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                  ],
                  const SizedBox(height: 18),
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
                          // The one real behavior change from Cubit:
                          // instead of calling a method directly, we
                          // dispatch an Event with `.add(...)`.
                          : () => context.read<LoginBloc>().add(
                                LoginSubmitted(
                                  username: _usernameController.text.trim(),
                                  password: _passwordController.text,
                                ),
                              ),
                      child: state.isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)),)
                          : const Text('Sign In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "New shop owner? ",
                          style: TextStyle(fontSize: 13.5, color: p.textSecondary),
                        ),
                        GestureDetector(
                          onTap: () => _comingSoon(context, 'Create account'),
                          child: const Text(
                            'Create account',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.accent),
                          ),
                        ),
                      ],
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

/// A password field (`obscureText: true`) grows a show/hide eye button
/// on the right — that needs its own `_obscured` state that flips
/// independently of `obscureText` (which just sets the *starting*
/// hidden state), so this is a StatefulWidget rather than the plain
/// stateless field it started as. A non-password field (Username)
/// asked for no toggle, so it gets no suffix icon at all.
class _LabeledField extends StatefulWidget {
  final AppPalette palette;
  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? maxLength;

  const _LabeledField({
    required this.palette,
    required this.label,
    required this.controller,
    this.icon,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.maxLength,
  });

  @override
  State<_LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<_LabeledField> {
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.textPrimary)),
        const SizedBox(height: 7),
        TextField(
          controller: widget.controller,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          maxLength: widget.maxLength,
          style: TextStyle(color: palette.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: palette.inputFill,
            hintText: widget.hintText,
            hintStyle: TextStyle(color: palette.textSecondary, fontSize: 14),
            prefixIcon: widget.icon == null ? null : Icon(widget.icon, size: 18, color: palette.textSecondary),
            prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 20),
            // Only a password-style field grows the eye toggle — a
            // plain field (Username) was never asked to hide/show.
            suffixIcon: widget.obscureText
                ? GestureDetector(
                    onTap: () => setState(() => _obscured = !_obscured),
                    child: Icon(
                      _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                      color: palette.textSecondary,
                    ),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 20),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            // maxLength defaults to showing a "n/10" counter under the
            // field — fine for the mobile number field, but this hides
            // it for every field so Password/Shop ID (no maxLength set)
            // don't get an empty gap, and Mobile Number stays clean too.
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent)),
          ),
        ),
      ],
    );
  }
}
