import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';

/// Add Product form — matches the design canvas exactly: photo upload box,
/// Product Name / Category / Brand / Price / Stock Qty / SKU-IMEI fields,
/// a New/Refurbished/Used condition segmented control, and a description
/// box. Pushed on top of Products (no bottom nav, matching the canvas).
/// Fields are real, editable — pre-filled with the canvas's own demo
/// values — but Save doesn't persist anywhere yet, no AddProductBloc.
class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

enum _Condition { new_, refurb, used }

class _AddProductScreenState extends State<AddProductScreen> {
  final _nameCtrl = TextEditingController(text: 'iPhone 14');
  final _priceCtrl = TextEditingController(text: '68,999');
  final _stockCtrl = TextEditingController(text: '12');
  final _skuCtrl = TextEditingController();
  final _descCtrl = TextEditingController(
    text: '6.1" Super Retina XDR display, A15 Bionic chip, dual-camera system...',
  );

  String _category = 'Smartphones';
  String _brand = 'Apple';
  _Condition _condition = _Condition.new_;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _skuCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _save(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product saved (demo) — not persisted yet')),
    );
    Navigator.pop(context);
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
                          'Add Product',
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
                  _FieldLabel('Product Name', palette: p),
                  const SizedBox(height: 7),
                  _FieldBox(
                    palette: p,
                    child: TextField(
                      controller: _nameCtrl,
                      style: _fieldStyle(p),
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true),
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
                              value: _category,
                              onTap: () => _comingSoon(context, 'Category picker'),
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
                              value: _brand,
                              onTap: () => _comingSoon(context, 'Brand picker'),
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
                            _FieldLabel('Price (₹)', palette: p),
                            const SizedBox(height: 7),
                            _FieldBox(
                              palette: p,
                              child: TextField(
                                controller: _priceCtrl,
                                keyboardType: TextInputType.number,
                                style: _fieldStyle(p),
                                decoration: const InputDecoration(border: InputBorder.none, isDense: true),
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
                                decoration: const InputDecoration(border: InputBorder.none, isDense: true),
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
                    child: TextField(
                      controller: _skuCtrl,
                      style: _fieldStyle(p),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'Scan or enter IMEI number',
                        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                      ),
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
                  _FieldLabel('Description', palette: p),
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
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true),
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
                onTap: () => _save(context),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Save Product',
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

TextStyle _fieldStyle(AppPalette p) => TextStyle(fontSize: 14, color: p.textPrimary);

void _comingSoon(BuildContext context, String label) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$label — coming soon')),
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final AppPalette palette;
  const _FieldLabel(this.text, {required this.palette});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.textPrimary));
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
  final VoidCallback onTap;
  const _SelectRow({required this.palette, required this.value, required this.onTap});

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
            Text(value, style: TextStyle(fontSize: 14, color: palette.textPrimary)),
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
              color: selected ? const Color(0xFF1C1C24) : const Color(0xFF6B6B76),
            ),
          ),
        ),
      ),
    );
  }
}
