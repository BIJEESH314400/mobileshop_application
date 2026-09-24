import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/product.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/lookup_picker_dialog.dart';
import '../bloc/add_product_bloc.dart';
import '../bloc/add_product_event.dart';
import '../bloc/add_product_state.dart';

/// Add Product form — matches the design canvas exactly: photo upload
/// box, Product Name / Category / Brand / Price / Stock Qty / SKU-IMEI
/// fields, a New/Refurbished/Used condition segmented control, and a
/// description box. Category and Brand now open a live Firestore-backed
/// picker (with a built-in "+ Add New") instead of showing a fixed
/// value, and Save actually writes the product to Firestore.
class AddProductScreen extends StatelessWidget {
  /// Null when adding a brand-new product (the normal case, from the
  /// Products list's + button or Dashboard's quick action). Passing an
  /// existing product switches this same form into edit mode -- same
  /// fields, pre-filled, saving updates that product instead of creating
  /// a new one.
  final Product? product;

  const AddProductScreen({super.key, this.product});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AddProductBloc(),
      child: _AddProductView(product: product),
    );
  }
}

enum _Condition { new_, refurb, used }

extension on _Condition {
  String get label {
    switch (this) {
      case _Condition.new_:
        return 'New';
      case _Condition.refurb:
        return 'Refurbished';
      case _Condition.used:
        return 'Used';
    }
  }
}

class _AddProductView extends StatefulWidget {
  final Product? product;
  const _AddProductView({this.product});

  @override
  State<_AddProductView> createState() => _AddProductViewState();
}

class _AddProductViewState extends State<_AddProductView> {
  // Left blank on purpose (the old canvas demo pre-filled "iPhone 14" /
  // "68,999" / "12" etc.) — now that Save actually writes to Firestore,
  // pre-filled demo text would let someone save a fake product by
  // mistake just by tapping Save without typing anything.
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _category;
  String? _brand;
  _Condition _condition = _Condition.new_;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product == null) return;

    _nameCtrl.text = product.name;
    // Whole rupees show without decimals (e.g. "68999"); anything with
    // paise keeps them (e.g. "68999.50") rather than always forcing two
    // decimal places on a price that was entered as a round number.
    _priceCtrl.text =
        product.price == product.price.roundToDouble() ? product.price.toStringAsFixed(0) : product.price.toString();
    _stockCtrl.text = product.stockQty.toString();
    _skuCtrl.text = product.sku;
    _descCtrl.text = product.description;
    _category = product.category.isEmpty ? null : product.category;
    _brand = product.brand.isEmpty ? null : product.brand;
    _condition = _Condition.values.firstWhere(
      (c) => c.label == product.condition,
      orElse: () => _Condition.new_,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _skuCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCategory() async {
    final picked = await LookupPickerDialog.show(
      context,
      title: 'Select Category',
      subtitle: 'Choose or create product category',
      itemLabel: 'category',
      collection: 'categories',
      selected: _category,
    );
    if (picked != null) setState(() => _category = picked);
  }

  Future<void> _pickBrand() async {
    final picked = await LookupPickerDialog.show(
      context,
      title: 'Select Brand',
      subtitle: 'Choose or create product brand',
      itemLabel: 'brand',
      collection: 'brands',
      selected: _brand,
    );
    if (picked != null) setState(() => _brand = picked);
  }

  void _save(BuildContext context) {
    context.read<AddProductBloc>().add(
          AddProductSubmitted(
            name: _nameCtrl.text,
            category: _category ?? '',
            brand: _brand ?? '',
            price: _priceCtrl.text,
            stockQty: _stockCtrl.text,
            sku: _skuCtrl.text,
            condition: _condition.label,
            description: _descCtrl.text,
            productId: widget.product?.id,
          ),
        );
  }

  void _comingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label — coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return BlocConsumer<AddProductBloc, AddProductState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.errorMessage!), backgroundColor: AppColors.danger));
        }
        if (state.isSuccess) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(_isEditing ? 'Product updated' : 'Product saved')));
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
                            Text(
                              _isEditing ? 'Edit Product' : 'Add Product',
                              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.textPrimary),
                            ),
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
                      Center(
                        child: GestureDetector(
                          onTap: () => _comingSoon(context, 'Photo upload'),
                          child: Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              color: p.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFD8D8E0), width: 1.5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_a_photo_outlined, size: 24, color: Color(0xFF9C9CA6)),
                                const SizedBox(height: 6),
                                Text(
                                  'Add Photo',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _FieldLabel('Product Name', palette: p, required: true),
                      const SizedBox(height: 7),
                      _FieldBox(
                        palette: p,
                        child: TextField(
                          controller: _nameCtrl,
                          style: _fieldStyle(p),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            hintText: 'e.g. iPhone 15 Pro Max 256GB',
                            hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel('Category', palette: p),
                                const SizedBox(height: 7),
                                _SelectRow(
                                  palette: p,
                                  value: _category ?? 'Select category',
                                  isPlaceholder: _category == null,
                                  onTap: _pickCategory,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel('Brand', palette: p),
                                const SizedBox(height: 7),
                                _SelectRow(
                                  palette: p,
                                  value: _brand ?? 'Select brand',
                                  isPlaceholder: _brand == null,
                                  onTap: _pickBrand,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                          style: _fieldStyle(p),
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
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel('Stock Qty', palette: p),
                                const SizedBox(height: 7),
                                _FieldBox(
                                  palette: p,
                                  child: TextField(
                                    controller: _stockCtrl,
                                    keyboardType: TextInputType.number,
                                    style: _fieldStyle(p),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      hintText: '1',
                                      hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _FieldLabel('SKU / IMEI', palette: p),
                      const SizedBox(height: 7),
                      _FieldBox(
                        palette: p,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _skuCtrl,
                                style: _fieldStyle(p),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  hintText: 'Scan or enter IMEI number',
                                  hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                                ),
                              ),
                            ),
                            // Visual only for now — no camera/scanner wired up
                            // yet, typing the SKU/IMEI by hand still works.
                            GestureDetector(
                              onTap: () => _comingSoon(context, 'Barcode scan'),
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: AppColors.iconTint,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: AppColors.accent),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _FieldLabel('Condition', palette: p),
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFEFEF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _ConditionSegment(
                              label: 'New',
                              selected: _condition == _Condition.new_,
                              onTap: () => setState(() => _condition = _Condition.new_),
                            ),
                            _ConditionSegment(
                              label: 'Refurbished',
                              selected: _condition == _Condition.refurb,
                              onTap: () => setState(() => _condition = _Condition.refurb),
                            ),
                            _ConditionSegment(
                              label: 'Used',
                              selected: _condition == _Condition.used,
                              onTap: () => setState(() => _condition = _Condition.used),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _FieldLabel('Description', palette: p),
                          Text(
                            'Optional',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: p.textSecondary),
                          ),
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
                          controller: _descCtrl,
                          maxLines: null,
                          style: TextStyle(fontSize: 13.5, height: 1.5, color: p.textSecondary),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            hintText: 'Add key features, specifications, or warranty details...',
                            hintStyle: TextStyle(fontSize: 13.5, height: 1.5, color: Color(0xFF9C9CA6)),
                          ),
                        ),
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
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: state.isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                            )
                          : Text(
                              _isEditing ? 'Save Changes' : 'Save Product',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
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

TextStyle _fieldStyle(AppPalette p) => TextStyle(fontSize: 14, color: p.textPrimary);

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

/// A bordered 48px field container. The child (a `TextField`) is
/// responsible for its own `decoration` — pass
/// `decoration: const InputDecoration(border: InputBorder.none, isDense: true)`
/// (optionally with a `hintText`) on every `TextField` used inside this,
/// since this box supplies the visible border/background itself.
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

class _SelectRow extends StatelessWidget {
  final AppPalette palette;
  final String value;
  final bool isPlaceholder;
  final VoidCallback onTap;
  const _SelectRow({
    required this.palette,
    required this.value,
    required this.onTap,
    this.isPlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: isPlaceholder ? const Color(0xFF9C9CA6) : palette.textPrimary,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF9C9CA6)),
          ],
        ),
      ),
    );
  }
}

class _ConditionSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ConditionSegment({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 2, offset: const Offset(0, 1))]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.accent : const Color(0xFF6B6B76),
            ),
          ),
        ),
      ),
    );
  }
}
