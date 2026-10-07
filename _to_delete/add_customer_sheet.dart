import 'package:flutter/material.dart';

import '../../../core/models/customer.dart';
import '../../../core/constants/shop_constants.dart';
import '../../../core/repositories/customer_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/app_logger.dart';

/// Small "add a customer" form, shared by two entry points: the
/// Customers screen's own "Add Customer" button, and the Sales
/// screen's customer picker (add-while-checking-out). Either way it
/// saves straight to Firestore and hands back the real Customer
/// (with its Firestore-assigned id) so the caller can use it right
/// away -- the Sales screen attaches it to the sale being rung up in
/// the same breath, rather than waiting for the live customer list to
/// catch up.
///
/// Returns null if the sheet was dismissed without saving.
Future<Customer?> showAddCustomerSheet(BuildContext context) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AddCustomerSheet(),
  );
}

class _AddCustomerSheet extends StatefulWidget {
  const _AddCustomerSheet();

  @override
  State<_AddCustomerSheet> createState() => _AddCustomerSheetState();
}

class _AddCustomerSheetState extends State<_AddCustomerSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final customer = Customer(
        id: '', // Firestore assigns the real id -- see addCustomer below.
        shopId: currentShopId,
        name: name,
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
      );
      final id = await CustomerRepository().addCustomer(customer);
      if (!mounted) return;
      Navigator.of(context).pop(Customer(
        id: id,
        shopId: customer.shopId,
        name: customer.name,
        phone: customer.phone,
        email: customer.email,
      ));
    } catch (e, st) {
      AppLogger.error('AddCustomerSheet._save', e, st);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "Couldn't save — check your connection and try again";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Add Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary)),
            const SizedBox(height: 16),
            _Field(palette: p, controller: _nameController, label: 'Name', hint: 'Customer name', autofocus: true),
            const SizedBox(height: 12),
            _Field(palette: p, controller: _phoneController, label: 'Phone (optional)', hint: '10-digit number', keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _Field(palette: p, controller: _emailController, label: 'Email (optional)', hint: 'name@example.com', keyboardType: TextInputType.emailAddress),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                      )
                    : const Text('Save Customer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final AppPalette palette;
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final bool autofocus;

  const _Field({
    required this.palette,
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: keyboardType,
          style: TextStyle(color: palette.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: palette.card,
            hintText: hint,
            hintStyle: TextStyle(color: palette.textSecondary, fontSize: 13.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent)),
          ),
        ),
      ],
    );
  }
}
