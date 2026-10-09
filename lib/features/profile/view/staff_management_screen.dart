import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/employee.dart';
import '../../../core/repositories/employee_repository.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/owner_only_gate.dart';
import '../bloc/staff_bloc.dart';
import '../bloc/staff_event.dart';
import '../bloc/staff_state.dart';

/// Owner-only screen: list of every employee who has a real login for
/// this shop, plus a button to add a new one. This is Step 1 toward the
/// owner↔employee chat feature — chat needs each employee to have a
/// real account first, since messages are tied to who's actually
/// signed in, not just a typed name.
class StaffManagementScreen extends StatelessWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return OwnerOnlyGate(
      child: BlocProvider(
        create: (_) => StaffBloc()..add(const StaffSubscriptionRequested()),
        child: const _StaffManagementView(),
      ),
    );
  }
}

class _StaffManagementView extends StatelessWidget {
  const _StaffManagementView();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

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
                        Text('Staff Management', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<StaffBloc, StaffState>(
                builder: (context, state) {
                  if (state.isLoading && state.employees.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.errorMessage != null && state.employees.isEmpty) {
                    return Center(
                      child: Text(state.errorMessage!, style: TextStyle(color: p.textSecondary)),
                    );
                  }
                  if (state.employees.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No employees yet.\nTap "Add Employee" below to create the first login.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13.5, color: p.textSecondary, height: 1.5),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    itemCount: state.employees.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _EmployeeRow(
                      employee: state.employees[index],
                      palette: p,
                      onTap: () => _showEmployeeDetailSheet(context, state.employees[index]),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: BoxDecoration(
                color: p.card,
                border: Border(top: BorderSide(color: p.border)),
              ),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.addEmployee),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add_alt_1_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Add Employee', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
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

class _EmployeeRow extends StatelessWidget {
  final Employee employee;
  final AppPalette palette;
  final VoidCallback onTap;
  const _EmployeeRow({required this.employee, required this.palette, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final removed = employee.disabled;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: removed ? 0.55 : 1,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(color: AppColors.iconTint, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.person_rounded, size: 20, color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(employee.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                    const SizedBox(height: 2),
                    Text('@${employee.username}', style: TextStyle(fontSize: 12.5, color: palette.textSecondary)),
                  ],
                ),
              ),
              if (removed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: palette.divider, borderRadius: BorderRadius.circular(20)),
                  child: Text('Removed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: palette.textSecondary)),
                )
              else
                Icon(Icons.chevron_right_rounded, size: 20, color: palette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opened by tapping an employee row. There's no "Edit Employee" form
/// today (name/username were only ever set once, at account creation),
/// so this is just a detail-plus-remove sheet, not a full edit screen --
/// the one action here is removing their access.
void _showEmployeeDetailSheet(BuildContext context, Employee employee) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _EmployeeDetailSheet(employee: employee),
  );
}

class _EmployeeDetailSheet extends StatefulWidget {
  final Employee employee;
  const _EmployeeDetailSheet({required this.employee});

  @override
  State<_EmployeeDetailSheet> createState() => _EmployeeDetailSheetState();
}

class _EmployeeDetailSheetState extends State<_EmployeeDetailSheet> {
  bool _working = false;

  Future<void> _confirmRemove() async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Remove this employee?',
      message: "They won't be able to sign in anymore. Sales and jobs they already recorded stay on record, still showing their name.",
      confirmLabel: 'Yes, Remove Employee',
      cancelLabel: 'Keep Employee',
    );
    if (!confirmed || !mounted) return;

    setState(() => _working = true);
    try {
      await EmployeeRepository().setDisabled(widget.employee.id, true);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('${widget.employee.name} removed')));
    } catch (e, st) {
      AppLogger.error('_EmployeeDetailSheetState._confirmRemove', e, st);
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Couldn't remove -- check your connection and try again")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final employee = widget.employee;
    final removed = employee.disabled;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(color: p.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(color: AppColors.iconTint, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Icon(Icons.person_rounded, size: 22, color: AppColors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(employee.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.textPrimary)),
                      const SizedBox(height: 2),
                      Text('@${employee.username}', style: TextStyle(fontSize: 13, color: p.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (removed)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: p.divider, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  'This employee has been removed and can no longer sign in.',
                  style: TextStyle(fontSize: 13, color: p.textSecondary),
                ),
              )
            else
              GestureDetector(
                onTap: _working ? null : _confirmRemove,
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                  ),
                  child: _working
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.danger),
                        )
                      : const Text('Remove Employee', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.danger)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
