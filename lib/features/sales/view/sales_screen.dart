import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_bottom_nav.dart';

/// New Sale — matches the design canvas exactly: a 2-item cart with qty
/// steppers, a live subtotal/discount/tax/total summary, and a UPI/Card/Cash
/// payment picker. Static reference items (Galaxy A54 + Tempered Glass
/// Pro); qty/payment are local widget state, no SalesBloc yet — matching
/// the canvas's own plain-state-object behavior.
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

enum _PayMethod { upi, card, cash }

class _SalesScreenState extends State<SalesScreen> {
  // Reference prices from the canvas — Galaxy A54 ₹31,499, Tempered Glass
  // Pro ₹399, a flat ₹399 discount, 18% GST.
  static const int _price1 = 31499;
  static const int _price2 = 399;
  static const int _discountFlat = 399;
  static const double _taxRate = 0.18;

  int _qty1 = 1;
  int _qty2 = 1;
  _PayMethod _payment = _PayMethod.upi;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    final subtotal = _price1 * _qty1 + _price2 * _qty2;
    final afterDiscount = (subtotal - _discountFlat).clamp(0, subtotal);
    final tax = (afterDiscount * _taxRate).round();
    final total = afterDiscount + tax;

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Sale',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.textPrimary),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: p.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.accent),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Walk-in Customer',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.textPrimary),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _comingSoon(context, 'Change customer'),
                          child: const Text(
                            'Change',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                children: [
                  Text(
                    'CART · 2 ITEMS',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  _CartItemCard(
                    palette: p,
                    icon: Icons.smartphone_rounded,
                    title: 'Galaxy A54 · 256GB',
                    unitLine: '${_inr(_price1)} each',
                    qty: _qty1,
                    onDec: () => setState(() => _qty1 = (_qty1 - 1).clamp(1, 99)),
                    onInc: () => setState(() => _qty1 = (_qty1 + 1).clamp(1, 99)),
                  ),
                  const SizedBox(height: 10),
                  _CartItemCard(
                    palette: p,
                    icon: Icons.shopping_bag_outlined,
                    title: 'Tempered Glass Pro',
                    unitLine: '${_inr(_price2)} each',
                    qty: _qty2,
                    onDec: () => setState(() => _qty2 = (_qty2 - 1).clamp(1, 99)),
                    onInc: () => setState(() => _qty2 = (_qty2 + 1).clamp(1, 99)),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, AppRoutes.products),
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD8D8E0), width: 1.5, style: BorderStyle.solid),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_rounded, size: 16, color: AppColors.accent),
                          SizedBox(width: 8),
                          Text(
                            'Add Product',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: p.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: p.border),
                    ),
                    child: Column(
                      children: [
                        _SummaryRow(label: 'Subtotal', value: _inr(subtotal), palette: p),
                        const SizedBox(height: 10),
                        _SummaryRow(
                          label: 'Discount',
                          value: '– ${_inr(_discountFlat)}',
                          palette: p,
                          valueColor: AppColors.success,
                        ),
                        const SizedBox(height: 10),
                        _SummaryRow(label: 'Tax (GST 18%)', value: _inr(tax), palette: p),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, color: p.divider),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.textPrimary),
                            ),
                            Text(
                              _inr(total),
                              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: p.textPrimary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'PAYMENT METHOD',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _PayTile(
                          palette: p,
                          icon: Icons.qr_code_rounded,
                          label: 'UPI',
                          selected: _payment == _PayMethod.upi,
                          onTap: () => setState(() => _payment = _PayMethod.upi),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _PayTile(
                          palette: p,
                          icon: Icons.credit_card_rounded,
                          label: 'Card',
                          selected: _payment == _PayMethod.card,
                          onTap: () => setState(() => _payment = _PayMethod.card),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _PayTile(
                          palette: p,
                          icon: Icons.currency_rupee_rounded,
                          label: 'Cash',
                          selected: _payment == _PayMethod.cash,
                          onTap: () => setState(() => _payment = _PayMethod.cash),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: BoxDecoration(
                color: p.card,
                border: Border(top: BorderSide(color: p.border)),
              ),
              child: GestureDetector(
                onTap: () => _completeSale(context, total),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Complete Sale · ${_inr(total)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.sales),
    );
  }

  void _completeSale(BuildContext context, int total) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sale completed · ${_inr(total)}')),
    );
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.dashboard, (route) => false);
  }
}

void _comingSoon(BuildContext context, String label) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$label — coming soon')),
  );
}

/// Indian-grouped currency string, e.g. 3149900 -> "₹31,499,00"... actually
/// groups by 2 after the first 3 digits (en-IN convention): 3100000 ->
/// "₹31,00,000". Matches the canvas's `n.toLocaleString('en-IN')`.
String _inr(int n) {
  final neg = n < 0;
  final abs = n.abs();
  final s = abs.toString();
  if (s.length <= 3) return (neg ? '-' : '') + '₹$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  return '${neg ? '-' : ''}₹${groups.join(',')},$last3';
}

class _CartItemCard extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;
  final String title;
  final String unitLine;
  final int qty;
  final VoidCallback onDec;
  final VoidCallback onInc;

  const _CartItemCard({
    required this.palette,
    required this.icon,
    required this.title,
    required this.unitLine,
    required this.qty,
    required this.onDec,
    required this.onInc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.iconTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: palette.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  unitLine,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: palette.textSecondary),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _StepButton(palette: palette, filled: false, label: '–', onTap: onDec),
              SizedBox(
                width: 24,
                child: Text(
                  '$qty',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: palette.textPrimary),
                ),
              ),
              _StepButton(palette: palette, filled: true, label: '+', onTap: onInc),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final AppPalette palette;
  final bool filled;
  final String label;
  final VoidCallback onTap;

  const _StepButton({
    required this.palette,
    required this.filled,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.accent : palette.card,
          borderRadius: BorderRadius.circular(8),
          border: filled ? null : Border.all(color: palette.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: filled ? Colors.white : palette.textSecondary,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette palette;
  final Color? valueColor;

  const _SummaryRow({required this.label, required this.value, required this.palette, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.textSecondary)),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor ?? palette.textPrimary),
        ),
      ],
    );
  }
}

class _PayTile extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PayTile({
    required this.palette,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : palette.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withOpacity(0.08) : palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.accent : palette.border, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}
