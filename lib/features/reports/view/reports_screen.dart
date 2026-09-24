import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/models/sale.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../bloc/reports_bloc.dart';
import '../bloc/reports_event.dart';
import '../bloc/reports_state.dart';

final _priceFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

enum _Period { today, week, month, all }

/// Owner/staff screen: revenue, order count, a trailing-7-day bar
/// chart, top products and a payment-method breakdown -- all computed
/// client-side from the same live `sales` data Sales History already
/// uses (ReportsBloc -> SaleRepository.watchSales()). Nothing here is
/// written back to Firestore, purely a read/aggregate view, so all of
/// the period filtering and math below lives in this View rather than
/// the Bloc -- same shape Dashboard's own stat cards already use on
/// top of SalesHistoryBloc's raw list.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReportsBloc()..add(const ReportsSubscriptionRequested()),
      child: const _ReportsView(),
    );
  }
}

class _ReportsView extends StatefulWidget {
  const _ReportsView();

  @override
  State<_ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<_ReportsView> {
  _Period _period = _Period.week;

  List<Sale> _filtered(List<Sale> sales) {
    final now = DateTime.now();
    return sales.where((sale) {
      final at = sale.createdAt ?? now; // a just-written sale may not have its server timestamp back yet
      switch (_period) {
        case _Period.today:
          return _isSameDay(at, now);
        case _Period.week:
          return !at.isBefore(DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)));
        case _Period.month:
          return at.year == now.year && at.month == now.month;
        case _Period.all:
          return true;
      }
    }).toList();
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
                        Text('Reports & Analytics', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<ReportsBloc, ReportsState>(
                builder: (context, state) {
                  if (state.isLoading && state.sales.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.errorMessage != null && state.sales.isEmpty) {
                    return Center(child: Text(state.errorMessage!, style: TextStyle(color: p.textSecondary)));
                  }
                  if (state.sales.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No sales yet.\nReports will fill in once you have completed sales.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13.5, color: p.textSecondary, height: 1.5),
                        ),
                      ),
                    );
                  }

                  final filtered = _filtered(state.sales);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      _PeriodPills(period: _period, onChanged: (period) => setState(() => _period = period)),
                      const SizedBox(height: 16),
                      _StatRow(sales: filtered, palette: p),
                      const SizedBox(height: 16),
                      _WeeklyChart(sales: state.sales, palette: p),
                      const SizedBox(height: 16),
                      _TopProducts(sales: filtered, palette: p),
                      const SizedBox(height: 16),
                      _PaymentBreakdown(sales: filtered, palette: p),
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

class _PeriodPills extends StatelessWidget {
  final _Period period;
  final ValueChanged<_Period> onChanged;
  const _PeriodPills({required this.period, required this.onChanged});

  static const _labels = {
    _Period.today: 'Today',
    _Period.week: 'This Week',
    _Period.month: 'This Month',
    _Period.all: 'All Time',
  };

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in _labels.entries) ...[
            _Pill(
              label: entry.value,
              selected: period == entry.key,
              palette: p,
              onTap: () => onChanged(entry.key),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.selected, required this.palette, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : palette.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.accent : palette.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : palette.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Total revenue, order count and average order value for whatever
/// period is currently selected -- a single row of 3 compact tiles.
class _StatRow extends StatelessWidget {
  final List<Sale> sales;
  final AppPalette palette;
  const _StatRow({required this.sales, required this.palette});

  @override
  Widget build(BuildContext context) {
    final revenue = sales.fold(0.0, (sum, s) => sum + s.total);
    final orders = sales.length;
    final avgOrder = orders == 0 ? 0.0 : revenue / orders;

    return Row(
      children: [
        Expanded(child: _StatTile(label: 'Revenue', value: _priceFormat.format(revenue), palette: palette, emphasize: true)),
        const SizedBox(width: 10),
        Expanded(child: _StatTile(label: 'Orders', value: '$orders', palette: palette)),
        const SizedBox(width: 10),
        Expanded(child: _StatTile(label: 'Avg Order', value: _priceFormat.format(avgOrder), palette: palette)),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette palette;
  final bool emphasize;
  const _StatTile({required this.label, required this.value, required this.palette, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: emphasize ? AppColors.accent : palette.card,
        borderRadius: BorderRadius.circular(14),
        border: emphasize ? null : Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: emphasize ? Colors.white70 : palette.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: emphasize ? Colors.white : palette.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Always the trailing 7 days ending today, independent of the period
/// pills above (those affect the stat row / top products / payment
/// breakdown only) -- a fixed-window "how's this week trending" view,
/// same idea as Dashboard's own always-live stat cards.
class _WeeklyChart extends StatelessWidget {
  final List<Sale> sales;
  final AppPalette palette;
  const _WeeklyChart({required this.sales, required this.palette});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final totals = days.map((day) {
      return sales.where((s) => _isSameDay(s.createdAt ?? now, day)).fold(0.0, (sum, s) => sum + s.total);
    }).toList();
    final maxTotal = totals.fold(0.0, (m, v) => v > m ? v : m);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: palette.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last 7 Days', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: palette.textPrimary)),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final isToday = _isSameDay(days[i], now);
                final barHeight = maxTotal <= 0 ? 4.0 : (totals[i] / maxTotal) * 78 + 4;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: barHeight,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isToday ? AppColors.accent : AppColors.accent.withOpacity(0.3),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('E').format(days[i]).substring(0, 1),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                          color: isToday ? AppColors.accent : palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductAgg {
  final String name;
  final int qty;
  final double revenue;
  const _ProductAgg({required this.name, required this.qty, required this.revenue});

  _ProductAgg addLine(int addQty, double addRevenue) => _ProductAgg(name: name, qty: qty + addQty, revenue: revenue + addRevenue);
}

/// Top 5 products by revenue within the selected period, each as a
/// horizontal bar scaled relative to the top item -- so "what's
/// actually selling" is visible at a glance without a table.
class _TopProducts extends StatelessWidget {
  final List<Sale> sales;
  final AppPalette palette;
  const _TopProducts({required this.sales, required this.palette});

  @override
  Widget build(BuildContext context) {
    final byProduct = <String, _ProductAgg>{};
    for (final sale in sales) {
      for (final item in sale.items) {
        final existing = byProduct[item.productId];
        byProduct[item.productId] = existing == null
            ? _ProductAgg(name: item.name, qty: item.qty, revenue: item.lineTotal)
            : existing.addLine(item.qty, item.lineTotal);
      }
    }
    final top = byProduct.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue));
    final topFive = top.take(5).toList();
    final maxRevenue = topFive.isEmpty ? 0.0 : topFive.first.revenue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: palette.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Products', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: palette.textPrimary)),
          const SizedBox(height: 14),
          if (topFive.isEmpty)
            Text('No sales for this period.', style: TextStyle(fontSize: 12.5, color: palette.textSecondary))
          else
            for (var i = 0; i < topFive.length; i++) ...[
              _ProductBar(rank: i + 1, product: topFive[i], maxRevenue: maxRevenue, palette: palette),
              if (i != topFive.length - 1) const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _ProductBar extends StatelessWidget {
  final int rank;
  final _ProductAgg product;
  final double maxRevenue;
  final AppPalette palette;
  const _ProductBar({required this.rank, required this.product, required this.maxRevenue, required this.palette});

  @override
  Widget build(BuildContext context) {
    final fraction = maxRevenue <= 0 ? 0.0 : (product.revenue / maxRevenue).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$rank. ${product.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.textPrimary),
              ),
            ),
            const SizedBox(width: 8),
            Text('×${product.qty}', style: TextStyle(fontSize: 11.5, color: palette.textSecondary)),
            const SizedBox(width: 8),
            Text(_priceFormat.format(product.revenue), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.textPrimary)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: palette.divider,
            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
          ),
        ),
      ],
    );
  }
}

/// Revenue share across UPI / Card / Cash for the selected period --
/// fixed colors per method (not cycled), matching how status/brand
/// colors are already used elsewhere in this app rather than
/// inventing a new palette just for this one chart.
class _PaymentBreakdown extends StatelessWidget {
  final List<Sale> sales;
  final AppPalette palette;
  const _PaymentBreakdown({required this.sales, required this.palette});

  @override
  Widget build(BuildContext context) {
    var upi = 0.0, card = 0.0, cash = 0.0;
    for (final sale in sales) {
      switch (sale.paymentMethod) {
        case 'upi':
          upi += sale.total;
          break;
        case 'card':
          card += sale.total;
          break;
        default:
          cash += sale.total;
          break;
      }
    }
    final total = upi + card + cash;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: palette.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Methods', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: palette.textPrimary)),
          const SizedBox(height: 14),
          if (total <= 0)
            Text('No sales for this period.', style: TextStyle(fontSize: 12.5, color: palette.textSecondary))
          else ...[
            _PaymentRow(label: 'UPI', value: upi, total: total, color: AppColors.accent, palette: palette),
            const SizedBox(height: 10),
            _PaymentRow(label: 'Card', value: card, total: total, color: AppColors.success, palette: palette),
            const SizedBox(height: 10),
            _PaymentRow(label: 'Cash', value: cash, total: total, color: AppColors.warning, palette: palette),
          ],
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final String label;
  final double value;
  final double total;
  final Color color;
  final AppPalette palette;
  const _PaymentRow({required this.label, required this.value, required this.total, required this.color, required this.palette});

  @override
  Widget build(BuildContext context) {
    final fraction = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    final percent = (fraction * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.textPrimary))),
            Text('$percent% · ${_priceFormat.format(value)}', style: TextStyle(fontSize: 12, color: palette.textSecondary)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: fraction, minHeight: 6, backgroundColor: palette.divider, valueColor: AlwaysStoppedAnimation(color)),
        ),
      ],
    );
  }
}
