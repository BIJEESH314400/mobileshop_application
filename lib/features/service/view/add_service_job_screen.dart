import 'package:flutter/material.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/service_job.dart';
import '../../../core/repositories/customer_repository.dart';
import '../../../core/repositories/service_job_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../sales/view/customer_picker_sheet.dart';

/// Add/Edit Service Job -- same "one form, optional existing-record
/// constructor arg" pattern as Edit Product/Edit Customer, and the same
/// "call the repository directly from the View, no dedicated Bloc"
/// shape Add/Edit Customer uses (this form is a plain few-field CRUD
/// screen, not complex enough to need its own Bloc the way Add Product
/// did for its category/brand picker + validation).
class AddServiceJobScreen extends StatefulWidget {
  /// Null when creating a brand-new job (from the Service screen's "+"
  /// button). Passing an existing job switches this into edit mode --
  /// same fields, pre-filled; saving updates that job's own info
  /// without touching its status (see ServiceJobRepository.updateJob).
  final ServiceJob? job;

  const AddServiceJobScreen({super.key, this.job});

  @override
  State<AddServiceJobScreen> createState() => _AddServiceJobScreenState();
}

class _AddServiceJobScreenState extends State<AddServiceJobScreen> {
  final _titleCtrl = TextEditingController();
  final _deviceCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  Customer? _customer;
  bool _saving = false;
  bool _deleting = false;
  String? _error;

  bool get _isEditing => widget.job != null;

  @override
  void initState() {
    super.initState();
    final job = widget.job;
    if (job == null) return;

    _titleCtrl.text = job.title;
    _deviceCtrl.text = job.deviceModel;
    _priceCtrl.text = job.price == job.price.roundToDouble() ? job.price.toStringAsFixed(0) : job.price.toString();
    _notesCtrl.text = job.notes;
    if (job.customerId.isNotEmpty) {
      // A lightweight stand-in, not a full re-fetch -- good enough to
      // show the previously-linked name/phone on the form and to carry
      // the same customerId back through on save if it isn't changed.
      _customer = Customer(id: job.customerId, shopId: currentShopId, name: job.customerName, phone: job.customerPhone);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _deviceCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCustomer() async {
    try {
      final customers = await CustomerRepository().watchCustomers(shopId: currentShopId).first;
      if (!mounted) return;
      final result = await showCustomerPickerSheet(context, customers: customers, selected: _customer);
      if (result == null) return;
      setState(() => _customer = result.cleared ? null : result.customer);
    } catch (e, st) {
      AppLogger.error('AddServiceJobScreen._pickCustomer', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Couldn't load customers -- check your connection and try again")));
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final device = _deviceCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '').trim());

    if (title.isEmpty) {
      setState(() => _error = 'What needs repairing? (e.g. "Screen replacement")');
      return;
    }
    if (device.isEmpty) {
      setState(() => _error = 'Device is required (e.g. "iPhone 12")');
      return;
    }
    if (price == null || price <= 0) {
      setState(() => _error = 'Enter a valid price');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final job = ServiceJob(
        id: widget.job?.id ?? '',
        shopId: currentShopId,
        title: title,
        deviceModel: device,
        customerId: _customer?.id ?? '',
        customerName: _customer?.name ?? '',
        customerPhone: _customer?.phone ?? '',
        price: price,
        notes: _notesCtrl.text.trim(),
      );
      if (_isEditing) {
        await ServiceJobRepository().updateJob(job.id, job);
      } else {
        await ServiceJobRepository().addJob(job);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_isEditing ? 'Job updated' : 'Job saved')));
      Navigator.of(context).pop(true);
    } catch (e, st) {
      AppLogger.error('AddServiceJobScreen._save', e, st);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "Couldn't save -- check your connection and try again";
      });
    }
  }

  Future<void> _confirmDelete() async {
    final job = widget.job;
    if (job == null) return;
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete this job permanently?',
      message: "This can't be undone. It will be removed from the Service Jobs list for good.",
      confirmLabel: 'Yes, Delete Job',
      cancelLabel: 'Keep Job',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ServiceJobRepository().deleteJob(job.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Job deleted')));
      Navigator.of(context).pop(true);
    } catch (e, st) {
      AppLogger.error('AddServiceJobScreen._confirmDelete', e, st);
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = "Couldn't delete -- check your connection and try again";
      });
    }
  }

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
              decoration: BoxDecoration(color: p.background, border: Border(bottom: BorderSide(color: p.border))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_back_rounded, size: 20, color: p.textPrimary),
                        const SizedBox(width: 14),
                        Text(
                          _isEditing ? 'Edit Job' : 'New Repair',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  if (_isEditing) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: (_saving || _deleting) ? null : _confirmDelete,
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.delete_outline_rounded, size: 19, color: AppColors.danger),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  _FieldLabel('What needs repairing?', palette: p, required: true),
                  const SizedBox(height: 7),
                  _FieldBox(
                    palette: p,
                    child: TextField(
                      controller: _titleCtrl,
                      style: TextStyle(fontSize: 14, color: p.textPrimary),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'e.g. Screen replacement',
                        hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FieldLabel('Device', palette: p, required: true),
                  const SizedBox(height: 7),
                  _FieldBox(
                    palette: p,
                    child: TextField(
                      controller: _deviceCtrl,
                      style: TextStyle(fontSize: 14, color: p.textPrimary),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'e.g. iPhone 12',
                        hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _FieldLabel('Customer', palette: p),
                      Text('Optional', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: p.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 7),
                  GestureDetector(
                    onTap: _pickCustomer,
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: p.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 17, color: p.textSecondary),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              _customer == null ? 'No customer selected' : _customer!.name,
                              style: TextStyle(
                                fontSize: 14,
                                color: _customer == null ? const Color(0xFF9C9CA6) : p.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF9C9CA6)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FieldLabel('Price (₹)', palette: p, required: true),
                  const SizedBox(height: 7),
                  _FieldBox(
                    palette: p,
                    child: Row(
                      children: [
                        const Text('₹', style: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6))),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _priceCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(fontSize: 14, color: p.textPrimary),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              hintText: '0.00',
                              hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _FieldLabel('Notes', palette: p),
                      Text('Optional', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: p.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Container(
                    constraints: const BoxConstraints(minHeight: 80),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: p.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.border),
                    ),
                    child: TextField(
                      controller: _notesCtrl,
                      maxLines: null,
                      style: TextStyle(fontSize: 13.5, height: 1.5, color: p.textSecondary),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'What the customer reported, what was found, anything to remember...',
                        hintStyle: TextStyle(fontSize: 13.5, height: 1.5, color: Color(0xFF9C9CA6)),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.border))),
              child: GestureDetector(
                onTap: (_saving || _deleting) ? null : _save,
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : Text(
                          _isEditing ? 'Save Changes' : 'Save Job',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
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

class _FieldLabel extends StatelessWidget {
  final String text;
  final AppPalette palette;
  final bool required;
  const _FieldLabel(this.text, {required this.palette, this.required = false});

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

/// A bordered 48px field container -- same shared shape Add Product's
/// own private `_FieldBox` uses, duplicated here rather than exported
/// and shared, matching how this app's screen-local private widgets
/// are generally kept to their own file.
class _FieldBox extends StatelessWidget {
  final AppPalette palette;
  final Widget child;
  const _FieldBox({required this.palette, required this.child});

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
