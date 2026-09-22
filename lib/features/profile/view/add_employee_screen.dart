import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../bloc/add_employee_bloc.dart';
import '../bloc/add_employee_event.dart';
import '../bloc/add_employee_state.dart';

/// Owner-only form: creates a real Firebase Auth login for a new
/// employee (name, username, password) — same "username only" login
/// style as the owner's own account, so the employee signs in on the
/// exact same Login screen afterward. Needed before employee↔owner
/// chat can be identity-based instead of just typed names.
class AddEmployeeScreen extends StatelessWidget {
  const AddEmployeeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AddEmployeeBloc(),
      child: const _AddEmployeeView(),
    );
  }
}

class _AddEmployeeView extends StatefulWidget {
  const _AddEmployeeView();

  @override
  State<_AddEmployeeView> createState() => _AddEmployeeViewState();
}

class _AddEmployeeViewState extends State<_AddEmployeeView> {
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _save(BuildContext context) {
    context.read<AddEmployeeBloc>().add(
          AddEmployeeSubmitted(
            name: _nameCtrl.text,
            username: _usernameCtrl.text,
            password: _passwordCtrl.text,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return BlocConsumer<AddEmployeeBloc, AddEmployeeState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.errorMessage!), backgroundColor: AppColors.danger));
        }
        if (state.isSuccess) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Employee login created')));
          Navigator.pop(context);
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: p.background,
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                  decoration: BoxDecoration(
                    color: p.background,
                    border: Border(bottom: BorderSide(color: p.border)),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Row(
                          children: [
                            Icon(Icons.arrow_back_rounded, size: 20, color: p.textPrimary),
                            const SizedBox(width: 14),
                            Text('Add Employee', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.textPrimary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    children: [
                      _Label('Full Name', p, required: true),
                      const SizedBox(height: 7),
                      _Box(
                        p,
                        child: TextField(
                          controller: _nameCtrl,
                          style: TextStyle(fontSize: 14, color: p.textPrimary),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            hintText: 'e.g. Ravi Kumar',
                            hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _Label('Username', p, required: true),
                      const SizedBox(height: 7),
                      _Box(
                        p,
                        child: TextField(
                          controller: _usernameCtrl,
                          autocorrect: false,
                          style: TextStyle(fontSize: 14, color: p.textPrimary),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            hintText: 'e.g. ravi',
                            hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This is what the employee types to sign in — no spaces or symbols.',
                        style: TextStyle(fontSize: 11.5, color: p.textSecondary),
                      ),
                      const SizedBox(height: 14),
                      _Label('Password', p, required: true),
                      const SizedBox(height: 7),
                      _Box(
                        p,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _passwordCtrl,
                                obscureText: !_showPassword,
                                style: TextStyle(fontSize: 14, color: p.textPrimary),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  hintText: 'At least 6 characters',
                                  hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _showPassword = !_showPassword),
                              child: Icon(
                                _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 18,
                                color: p.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Share this username and password with the employee — they sign in on the same Login screen.',
                        style: TextStyle(fontSize: 11.5, color: p.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  decoration: BoxDecoration(
                    color: p.card,
                    border: Border(top: BorderSide(color: p.border)),
                  ),
                  child: GestureDetector(
                    onTap: state.isSubmitting ? null : () => _save(context),
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                      child: state.isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                            )
                          : const Text('Create Login', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final AppPalette palette;
  final bool required;
  const _Label(this.text, this.palette, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.textPrimary),
        children: [
          TextSpan(text: text),
          if (required) const TextSpan(text: ' *', style: TextStyle(color: AppColors.danger)),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  final AppPalette palette;
  final Widget child;
  const _Box(this.palette, {required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}
