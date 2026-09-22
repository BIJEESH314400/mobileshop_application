import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/models/sale.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../bloc/sales_history_bloc.dart';
import '../bloc/sales_history_event.dart';
import '../bloc/sales_history_state.dart';

final _priceFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _dateFormat = DateFormat('d MMM, h:mm a');

/// Owner/staff screen: every completed sale for this shop, newest
/// first, live via SalesHistoryBloc → SaleRepository.watchSales(). A
/// sale never changes once completed, so this is a read-only list —
/// tapping a row opens the full itemized receipt in a bottom sheet.
class SalesHistoryScreen extends StatelessWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SalesHistoryBloc()..add(const SalesHistorySubscriptionRequested()),
      child: const _SalesHistoryView(),
    );
  }
}

class _SalesHistoryView extends StatelessWidget {
  const _SalesHistoryView();

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
                        Text('Sales History', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<SalesHistoryBloc, SalesHistoryState>(
                builder: (context, state) {
                  if (state.isLoading && state.sales.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.errorMessage != null && state.sales.isEmpty) {
                    return Center(
                      child: Text(state.errorMessage!, style: TextStyle(color: p.textSecondary)),
                    );
                  }
                  if (state.sales.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No sales yet.\nCompleted sales will show up here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13.5, color: p.textSecondary, height: 1.5),
                        ),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    children: [
                      _SummaryStrip(palette: p, state: state),
                      const SizedBox(height: 16),
                      for (var i = 0; i < state.sales.length; i++) ...[
                        _SaleRow(sale: state.sales[i], palette: p),
                        if (i != state.sales.length - 1) const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final AppPalette palette;
  final SalesHistoryState state;

  const _SummaryStrip({required this.palette, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total sales', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
                const SizedBox(height: 4),
                Text('${state.sales.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total revenue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
                const SizedBox(height: 4),
                Text(_priceFormat.format(state.totalRevenue), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleRow extends StatelessWidget {
  final Sale sale;
  final AppPalette palette;

  const _SaleRow({required this.sale, required this.palette});

  String get _itemSummary {
    if (sale.items.isEmpty) return 'No items';
    final first = sale.items.first;
    final firstLabel = '${first.name} ×${first.qty}';
    if (sale.items.length == 1) return firstLabel;
    return '$firstLabel + ${sale.items.length - 1} more';
  }

  IconData get _paymentIcon {
    switch (sale.paymentMethod) {
      case 'upi':
        return Icons.qr_code_rounded;
      case 'card':
        return Icons.credit_card_rounded;
      default:
        return Icons.currency_rupee_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showReceipt(context, sale, palette),
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
              child: Icon(_paymentIcon, size: 19, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_itemSummary, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    sale.createdAt == null ? 'Just now' : _dateFormat.format(sale.createdAt!),
                    style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
                  ),
                ],
              ),
            ),
            Text(_priceFormat.format(sale.total), style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: palette.textPrimary)),
          ],
        ),
      ),
    );
  }
}

void _showReceipt(BuildContext context, Sale sale, AppPalette palette) {
  showModalBottomSheet(
    context: context,
    backgroundColor: palette.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Receipt', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: palette.textPrimary)),
              const SizedBox(height: 2),
              Text(
                sale.createdAt == null ? 'Just now' : _dateFormat.format(sale.createdAt!),
                style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
              ),
              const SizedBox(height: 16),
              for (final item in sale.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.name} ×${item.qty}',
                          style: TextStyle(fontSize: 13.5, color: palette.textPrimary),
                        ),
                      ),
                      Text(_priceFormat.format(item.lineTotal), style: TextStyle(fontSize: 13.5, color: palette.textPrimary)),
                    ],
                  ),
                ),
              Divider(color: palette.divider, height: 24),
              _ReceiptTotalRow(label: 'Subtotal', value: sale.subtotal, palette: palette),
              if (sale.discount > 0) _ReceiptTotalRow(label: 'Discount', value: -sale.discount, palette: palette),
              _ReceiptTotalRow(label: 'Tax', value: sale.tax, palette: palette),
              const SizedBox(height: 4),
              _ReceiptTotalRow(label: 'Total', value: sale.total, palette: palette, emphasize: true),
              const SizedBox(height: 4),
              Text(
                'Paid via ${sale.paymentMethod.toUpperCase()}',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: palette.textSecondary),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ReceiptTotalRow extends StatelessWidget {
  final String label;
  final double value;
  final AppPalette palette;
  final bool emphasize;

  const _ReceiptTotalRow({required this.label, required this.value, required this.palette, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: emphasize ? 15 : 13,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: emphasize ? palette.textPrimary : palette.textSecondary,
            ),
          ),
          Text(
            _priceFormat.format(value),
            style: TextStyle(
              fontSize: emphasize ? 15 : 13,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
              color: emphasize ? palette.textPrimary : palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
