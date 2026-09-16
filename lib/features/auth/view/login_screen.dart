import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
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
  final _mobileController = TextEditingController();
  final _shopIdController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _mobileController.dispose();
    _shopIdController.dispose();
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
      listener: (context, state) {
        if (state.isSuccess) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: p.background,
          // LayoutBuilder + SingleChildScrollView + ConstrainedBox(minHeight)
          // + IntrinsicHeight: the standard fix for "Column overflows when
          // the keyboard opens (or on a short screen), but I still want a
          // Spacer() to push the footer to the bottom when there's room."
          // A plain Column doesn't scroll — once its fixed-size children
          // (icon, heading, fields, button, footer) don't fit the
          // available height, it overflows instead of scrolling, which is
          // exactly what the yellow/black striped error was. Wrapping in
          // SingleChildScrollView fixes that; ConstrainedBox(minHeight)
          // + IntrinsicHeight is what lets Spacer() still work inside a
          // scroll view (Expanded/Spacer normally need a bounded height,
          // which a scroll view doesn't provide on its own).
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
                    label: 'Mobile Number',
                    controller: _mobileController,
                    icon: Icons.call_outlined,
                    hintText: '98765 43210',
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                  ),
                  const SizedBox(height: 16),
                  _LabeledField(
                    palette: p,
                    label: 'Shop ID',
                    controller: _shopIdController,
                    icon: Icons.storefront_outlined,
                    hintText: 'e.g. 4BMOBILES01',
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
                      onPressed: () => _comingSoon(context, 'Forgot password'),
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
                                  mobile: _mobileController.text.trim(),
                                  shopId: _shopIdController.text.trim(),
                                  password: _passwordController.text,
                                ),
                              ),
                      child: state.isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                            )
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

class _LabeledField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.textPrimary)),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLength: maxLength,
          style: TextStyle(color: palette.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: palette.inputFill,
            hintText: hintText,
            hintStyle: TextStyle(color: palette.textSecondary, fontSize: 14),
            prefixIcon: icon == null ? null : Icon(icon, size: 18, color: palette.textSecondary),
            prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 20),
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
