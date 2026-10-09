import 'package:flutter/material.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/customer.dart';
import '../../../core/repositories/customer_repository.dart';
import '../../../core/repositories/product_request_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/app_logger.dart';
import '../../sales/view/customer_picker_sheet.dart';

/// Add Request -- a full page, same "back-arrow header, labeled field
/// boxes, bottom Save button" shape as every other Add/Edit screen in
/// this app (Add Product, Add Customer, Add Service Job). Replaced a
/// popup dialog version 2026-10-07 -- the owner asked for this to look
/// and feel like the rest of the app, not a popup.
///
/// Reached from two places, both landing on this same page with just
/// different starting values: the Sales screen's out-of-stock picker
/// (pre-fills the product name, and the customer already selected for
/// the sale, if any) and the Waiting Customers screen's own "+ Add
/// Request" button (blank -- no catalog entry needed at all; see
/// ProductRequest's model doc comment for why `productId` is
/// optional).
///
/// **Customer field (2026-10-07 revision):** now the same pick-an-
/// existing-customer-or-add-a-new-one picker Sales/Service Jobs
/// already use, instead of a free-typed name -- so a request is
/// linked to a real customer record (phone included automatically)
/// rather than a name that might not match anyone in the directory.
/// Tapping it opens the shared customer picker; its own "+ New" link
/// opens the same quick-add sheet used everywhere else a customer
/// needs to be added mid-flow.
class AddRequestScreen extends StatefulWidget {
  final String? productId;
  final String initialItemName;
  final Customer? initialCustomer;

  const AddRequestScreen({
    super.key,
    this.productId,
    this.initialItemName = '',
    this.initialCustomer,
  });

  @override
  State<AddRequestScreen> createState() => _AddRequestScreenState();
}

class _AddRequestScreenState extends State<AddRequestScreen> {
  final _itemCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();

  Customer? _customer;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _itemCtrl.text = widget.initialItemName;
    _customer = widget.initialCustomer;
  }

  @override
  void dispose() {
    _itemCtrl.dispose();
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
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
      AppLogger.error('AddRequestScreen._pickCustomer', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Couldn't load customers -- check your connection and try again")));
    }
  }

  Future<void> _save() async {
    final item = _itemCtrl.text.trim();

    if (item.isEmpty) {
      setState(() => _error = 'What\'s the customer waiting for? (e.g. "Titan Watch")');
      return;
    }
    if (_customer == null) {
      setState(() => _error = 'Select or add the customer who\'s waiting');
      return;
    }

    final quantity = int.tryParse(_qtyCtrl.text.trim()) ?? 1;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ProductRequestRepository().addRequest(
        shopId: currentShopId,
        productId: widget.productId,
        productName: item,
        quantity: quantity < 1 ? 1 : quantity,
        customerId: _customer!.id,
        customerName: _customer!.name,
        customerPhone: _customer!.phone,
        note: _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Request saved')));
      Navigator.of(context).pop(true);
    } catch (e, st) {
      AppLogger.error('AddRequestScreen._save', e, st);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "Couldn't save -- check your connection and try again";
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
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_back_rounded, size: 20, color: p.textPrimary),
                        const SizedBox(width: 14),
                        Text('Add Request', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  Text(
                    "What's the customer waiting for? No need to add it as a Product first.",
                    style: TextStyle(fontSize: 13, color: p.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  _FieldLabel('Item name', palette: p, required: true),
                  const SizedBox(height: 7),
                  _FieldBox(
                    palette: p,
                    child: TextField(
                      controller: _itemCtrl,
                      style: TextStyle(fontSize: 14, color: p.textPrimary),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'e.g. Titan Watch',
                        hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FieldLabel('Quantity', palette: p),
                  const SizedBox(height: 7),
                  SizedBox(
                    width: 110,
                    child: _FieldBox(
                      palette: p,
                      child: TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(fontSize: 14, color: p.textPrimary),
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FieldLabel('Customer', palette: p, required: true),
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
                              _customer == null
                                  ? 'Select or add customer'
                                  : (_customer!.phone.isEmpty ? _customer!.name : '${_customer!.name} · ${_customer!.phone}'),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _FieldLabel('Note', palette: p),
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
                      controller: _noteCtrl,
                      maxLines: null,
                      style: TextStyle(fontSize: 13.5, height: 1.5, color: p.textSecondary),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'e.g. will check back in 3 days',
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
                onTap: _saving ? null : _save,
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
                      : const Text(
                          'Save Request',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
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

/// Same shared field-label/field-box shapes Add Service Job's own
/// private widgets use -- duplicated here rather than exported,
/// matching how this app keeps screen-local private widgets to their
/// own file.
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
