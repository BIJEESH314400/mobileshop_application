import 'dart:async';

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
final _rangeDateFormat = DateFormat('d MMM');

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Groups the (already newest-first) sales list into three buckets --
/// "Today" / "Yesterday" / "Older" -- same idea as most chat and
/// transaction-history apps. A sale with no `createdAt` yet (the brief
/// moment between a local write and the server timestamp coming back,
/// already shown as "Just now" on the row itself) is grouped under
/// "Today" too, since it only ever happens for a sale that was just made.
String _groupLabel(DateTime? createdAt) {
  final now = DateTime.now();
  if (createdAt == null || _isSameDay(createdAt, now)) return 'Today';
  final yesterday = now.subtract(const Duration(days: 1));
  if (_isSameDay(createdAt, yesterday)) return 'Yesterday';
  return 'Older';
}

/// "Updated just now" / "Updated N mins ago" -- the line under the
/// LIVE badge, driven by SalesHistoryState.lastUpdatedAt (stamped every
/// time the live Firestore stream delivers a snapshot). The view also
/// re-renders this on its own 30s timer so it keeps advancing even
/// while no new sale comes in to trigger a fresh state.
String _relativeUpdated(DateTime? updatedAt) {
  if (updatedAt == null) return 'Updating…';
  final diff = DateTime.now().difference(updatedAt);
  if (diff.inSeconds < 45) return 'Updated just now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return 'Updated $m min${m == 1 ? '' : 's'} ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return 'Updated $h hr${h == 1 ? '' : 's'} ago';
  }
  final d = diff.inDays;
  return 'Updated $d day${d == 1 ? '' : 's'} ago';
}

String _rangeLabel(DateTimeRange range) {
  if (_isSameDay(range.start, range.end)) return _rangeDateFormat.format(range.start);
  return '${_rangeDateFormat.format(range.start)} – ${_rangeDateFormat.format(range.end)}';
}

void _comingSoon(BuildContext context, String label) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label — coming soon')));
}

/// Revenue trend over the trailing 7 days vs. the 7 days before that --
/// computed from the FULL sales list regardless of the search/date
/// filter below (same "always trailing 7 days, independent of any other
/// filter" idea Reports & Analytics already uses for its own chart), so
/// the badge/sparkline read as an overall business trend, not something
/// that jumps around as the cashier types into search.
class _RevenueTrend {
  final double last7;
  final double prev7;
  final List<double> dailyLast7; // oldest -> newest, 7 entries, index 6 = today

  const _RevenueTrend({required this.last7, required this.prev7, required this.dailyLast7});

  bool get hasComparison => prev7 > 0;
  double get changePct => prev7 == 0 ? 0 : ((last7 - prev7) / prev7) * 100;
}

_RevenueTrend _computeTrend(List<Sale> sales) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final daily = List<double>.filled(7, 0);
  var prev7 = 0.0;

  for (final sale in sales) {
    final created = sale.createdAt;
    if (created == null) continue;
    final day = DateTime(created.year, created.month, created.day);
    final diff = today.difference(day).inDays;
    if (diff >= 0 && diff < 7) {
      daily[6 - diff] += sale.total;
    } else if (diff >= 7 && diff < 14) {
      prev7 += sale.total;
    }
  }

  final last7 = daily.fold(0.0, (sum, v) => sum + v);
  return _RevenueTrend(last7: last7, prev7: prev7, dailyLast7: daily);
}

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

class _SalesHistoryView extends StatefulWidget {
  const _SalesHistoryView();

  @override
  State<_SalesHistoryView> createState() => _SalesHistoryViewState();
}

class _SalesHistoryViewState extends State<_SalesHistoryView> {
  final _searchCtrl = TextEditingController();
  DateTimeRange? _dateRange;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    // Nothing new has to arrive for "Updated X ago" to keep advancing --
    // this just forces a rebuild every 30s so that line stays current.
    _tickTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _dateRange,
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  List<Sale> _filtered(List<Sale> sales) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final range = _dateRange;

    return sales.where((sale) {
      if (range != null) {
        final created = sale.createdAt;
        // A sale whose server timestamp hasn't resolved yet can't be
        // placed inside an explicit date range -- it briefly drops out
        // of a date-filtered view until that timestamp lands, same
        // trade-off already accepted for the Today/Yesterday grouping.
        if (created == null) return false;
        final day = DateTime(created.year, created.month, created.day);
        final start = DateTime(range.start.year, range.start.month, range.start.day);
        final end = DateTime(range.end.year, range.end.month, range.end.day);
        if (day.isBefore(start) || day.isAfter(end)) return false;
      }

      if (query.isEmpty) return true;
      final matchesItem = sale.items.any((item) => item.name.toLowerCase().contains(query));
      final matchesSeller = sale.soldByName.toLowerCase().contains(query);
      return matchesItem || matchesSeller;
    }).toList();
  }

  /// `sales` is already newest-first, so a run of consecutive sales
  /// sharing the same group label is always contiguous, and a plain
  /// `Map` (insertion-ordered in Dart) is enough to bucket them without
  /// a separate sort.
  Map<String, List<Sale>> _grouped(List<Sale> sales) {
    final map = <String, List<Sale>>{};
    for (final sale in sales) {
      (map[_groupLabel(sale.createdAt)] ??= []).add(sale);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: BlocBuilder<SalesHistoryBloc, SalesHistoryState>(
          builder: (context, state) {
            return Column(
              children: [
                _Header(palette: p, updatedText: _relativeUpdated(state.lastUpdatedAt)),
                Expanded(child: _buildBody(context, p, state)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppPalette p, SalesHistoryState state) {
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
            'No sales yet.\nCompleted sales will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: p.textSecondary, height: 1.5),
          ),
        ),
      );
    }

    final trend = _computeTrend(state.sales);
    final filtered = _filtered(state.sales);
    final groups = _grouped(filtered);

    final children = <Widget>[
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _RevenueStatCard(total: state.totalRevenue, trend: trend, palette: p)),
            const SizedBox(width: 12),
            Expanded(child: _OrdersStatCard(count: state.sales.length, palette: p)),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _SearchAndDateRow(
        palette: p,
        searchCtrl: _searchCtrl,
        dateRange: _dateRange,
        onSearchChanged: () => setState(() {}),
        onTapDates: () => _pickDateRange(context),
        onClearDates: () => setState(() => _dateRange = null),
      ),
    ];

    if (filtered.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Column(
            children: [
              Text(
                'No sales match your search or dates',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: p.textSecondary),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() {
                  _searchCtrl.clear();
                  _dateRange = null;
                }),
                child: const Text('Clear filters', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    } else {
      var isFirstGroup = true;
      for (final entry in groups.entries) {
        children.add(_DateGroupHeader(label: entry.key, count: entry.value.length, palette: p, isFirst: isFirstGroup));
        isFirstGroup = false;
        // One shared card per group (see _SaleGroupCard) -- rows inside
        // it are separated by a thin divider, not a gap.
        children.add(_SaleGroupCard(sales: entry.value, palette: p));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: children,
    );
  }
}

class _Header extends StatelessWidget {
  final AppPalette palette;
  final String updatedText;
  const _Header({required this.palette, required this.updatedText});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back_rounded, size: 20, color: palette.textPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Sales History',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: palette.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _LiveBadge(),
                  ],
                ),
                const SizedBox(height: 2),
                Text(updatedText, style: TextStyle(fontSize: 11.5, color: palette.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _comingSoon(context, 'Export'),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: palette.border),
              ),
              child: Icon(Icons.download_rounded, size: 18, color: palette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small green "LIVE" pill next to the title -- fixed colors (not
/// palette-driven), same convention as every other status badge in the
/// app (Low Stock, In Progress, ...), since it's always the same live
/// Firestore stream regardless of theme.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          const Text(
            'LIVE',
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.success, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}

class _RevenueStatCard extends StatelessWidget {
  final double total;
  final _RevenueTrend trend;
  final AppPalette palette;
  const _RevenueStatCard({required this.total, required this.trend, required this.palette});

  @override
  Widget build(BuildContext context) {
    final positive = trend.changePct >= 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TOTAL REVENUE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: palette.textSecondary),
                ),
              ),
              if (trend.hasComparison)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: positive ? AppColors.successBg : AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${positive ? '+' : ''}${trend.changePct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: positive ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _priceFormat.format(total),
            style: TextStyle(fontSize: 18.5, fontWeight: FontWeight.w800, color: palette.textPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            'TREND · LAST 7 DAYS',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.2, color: palette.textSecondary),
          ),
          const SizedBox(height: 4),
          _Sparkline(values: trend.dailyLast7, color: AppColors.accent),
        ],
      ),
    );
  }
}

class _OrdersStatCard extends StatelessWidget {
  final int count;
  final AppPalette palette;
  const _OrdersStatCard({required this.count, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(
                'ORDERS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: palette.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('$count', style: TextStyle(fontSize: 18.5, fontWeight: FontWeight.w800, color: palette.textPrimary)),
          const SizedBox(height: 10),
          // No partial/pending-payment concept in this app -- a sale is
          // always fully paid the moment it's created, so this is
          // always true, same as a fixed status label rather than
          // something computed per sale.
          Row(
            children: [
              const Icon(Icons.trending_up_rounded, size: 13, color: AppColors.success),
              const SizedBox(width: 4),
              const Text('All Settled', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success)),
            ],
          ),
        ],
      ),
    );
  }
}

/// A minimal line sparkline over 7 values, normalized to the card's
/// own min/max so it always reads as a shape even when the numbers are
/// small -- not meant to carry exact values (no axis/labels), just an
/// at-a-glance trend, same spirit as the rest of this app's charts.
class _Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  const _Sparkline({required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      width: double.infinity,
      child: CustomPaint(painter: _SparklinePainter(values: values, color: color)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  const _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV).abs() < 0.0001 ? 1.0 : (maxV - minV);
    final stepX = size.width / (values.length - 1);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = stepX * i;
      final normalized = (values[i] - minV) / range;
      // A flat-zero series (no sales at all in the window) would divide
      // to 0/0-ish noise -- pin it to the vertical middle instead.
      final y = range == 1.0 && maxV == 0 ? size.height / 2 : size.height - (normalized * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class _SearchAndDateRow extends StatelessWidget {
  final AppPalette palette;
  final TextEditingController searchCtrl;
  final DateTimeRange? dateRange;
  final VoidCallback onSearchChanged;
  final VoidCallback onTapDates;
  final VoidCallback onClearDates;

  const _SearchAndDateRow({
    required this.palette,
    required this.searchCtrl,
    required this.dateRange,
    required this.onSearchChanged,
    required this.onTapDates,
    required this.onClearDates,
  });

  @override
  Widget build(BuildContext context) {
    final active = dateRange != null;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 17, color: palette.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: searchCtrl,
                      onChanged: (_) => onSearchChanged(),
                      style: TextStyle(fontSize: 13, color: palette.textPrimary),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'Search sales...',
                        hintStyle: TextStyle(fontSize: 13, color: palette.textSecondary),
                      ),
                    ),
                  ),
                  if (searchCtrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        searchCtrl.clear();
                        onSearchChanged();
                      },
                      child: Icon(Icons.close_rounded, size: 16, color: palette.textSecondary),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onTapDates,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: active ? AppColors.accent : palette.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: active ? AppColors.accent : palette.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded, size: 15, color: active ? Colors.white : palette.textPrimary),
                  const SizedBox(width: 7),
                  Text(
                    active ? _rangeLabel(dateRange!) : 'Dates',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? Colors.white : palette.textPrimary),
                  ),
                  if (active) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onClearDates,
                      child: const Icon(Icons.close_rounded, size: 15, color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Today" / "Yesterday" / "Older" section label above a run of sales
/// sharing that bucket, with how many sales are in it on the right --
/// small bold caps + a lead dot, same visual language as the badges
/// elsewhere in the app. `isFirst` drops the usual top gap for the very
/// first header so it doesn't add extra space under the search row.
class _DateGroupHeader extends StatelessWidget {
  final String label;
  final int count;
  final AppPalette palette;
  final bool isFirst;

  const _DateGroupHeader({required this.label, required this.count, required this.palette, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 16 : 20, bottom: 8, left: 2, right: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: palette.textSecondary),
              ),
            ],
          ),
          Text(
            '$count order${count == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// One date group's sales as a SINGLE bordered/rounded card, with a
/// thin divider between rows instead of a gap -- per the user's
/// explicit "not want space [between rows]" correction, replacing the
/// earlier one-card-per-sale layout.
class _SaleGroupCard extends StatelessWidget {
  final List<Sale> sales;
  final AppPalette palette;
  const _SaleGroupCard({required this.sales, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < sales.length; i++) ...[
            _SaleRowContent(sale: sales[i], palette: palette),
            if (i != sales.length - 1)
              Divider(height: 1, thickness: 1, color: palette.divider, indent: 14, endIndent: 14),
          ],
        ],
      ),
    );
  }
}

/// Icon + tint pair per payment method -- reuses the exact same
/// accent/success/warning mapping Reports & Analytics already
/// established for UPI/Card/Cash (see _PaymentBreakdown there), so the
/// same payment method always reads as the same color everywhere in
/// the app, rather than a fresh set of hues invented just for this row.
class _PaymentStyle {
  final IconData icon;
  final Color bg;
  final Color fg;
  const _PaymentStyle(this.icon, this.bg, this.fg);
}

_PaymentStyle _paymentStyle(String method) {
  switch (method) {
    case 'upi':
      return const _PaymentStyle(Icons.qr_code_rounded, AppColors.iconTint, AppColors.accent);
    case 'card':
      return const _PaymentStyle(Icons.credit_card_rounded, AppColors.successBg, AppColors.success);
    default: // 'cash'
      return const _PaymentStyle(Icons.currency_rupee_rounded, AppColors.warningBg, AppColors.warningText);
  }
}

/// The actual row content -- no border/background of its own, since
/// _SaleGroupCard now supplies one shared card around a whole group.
class _SaleRowContent extends StatelessWidget {
  final Sale sale;
  final AppPalette palette;

  const _SaleRowContent({required this.sale, required this.palette});

  @override
  Widget build(BuildContext context) {
    final firstItem = sale.items.isNotEmpty ? sale.items.first : null;
    final extraCount = sale.items.length > 1 ? sale.items.length - 1 : 0;
    final paymentStyle = _paymentStyle(sale.paymentMethod);

    return GestureDetector(
      onTap: () => _showReceipt(context, sale, palette),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: paymentStyle.bg, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Icon(paymentStyle.icon, size: 19, color: paymentStyle.fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          firstItem?.name ?? 'No items',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.textPrimary),
                        ),
                      ),
                      if (firstItem != null && firstItem.qty > 1) ...[
                        const SizedBox(width: 6),
                        _Chip(label: '×${firstItem.qty}', palette: palette),
                      ],
                      if (extraCount > 0) ...[
                        const SizedBox(width: 6),
                        _Chip(label: '+$extraCount more', palette: palette, accent: true),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 11, color: palette.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        sale.createdAt == null ? 'Just now' : _dateFormat.format(sale.createdAt!),
                        style: TextStyle(fontSize: 11.5, color: palette.textSecondary),
                      ),
                      if (sale.soldByName.isNotEmpty) ...[
                        Text('  •  ', style: TextStyle(fontSize: 11.5, color: palette.textSecondary)),
                        Icon(Icons.person_outline_rounded, size: 11, color: palette.textSecondary),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            sale.soldByName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: palette.textSecondary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(_priceFormat.format(sale.total), style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: palette.textPrimary)),
          ],
        ),
      ),
    );
  }
}

/// Small pill used for the "×N" qty and "+N more" item-count hints on a
/// sale row -- fixed accent-on-iconTint colors, same as the rest of the
/// app's icon-tint chips, so it reads correctly in both themes.
class _Chip extends StatelessWidget {
  final String label;
  final AppPalette palette;
  // false (the qty chip, e.g. "×1") -> low-key neutral pill.
  // true (the "+N more" chip) -> accent-tinted, so it stands out as the
  // more attention-worthy of the two, matching the reference design.
  final bool accent;
  const _Chip({required this.label, required this.palette, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: accent ? AppColors.iconTint : palette.background,
        borderRadius: BorderRadius.circular(6),
        border: accent ? null : Border.all(color: palette.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: accent ? AppColors.accent : palette.textSecondary,
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
              if (sale.soldByName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Sold by ${sale.soldByName}${sale.soldByRole == 'owner' ? ' (Owner)' : ' (Staff)'}',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: palette.textSecondary),
                ),
              ],
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
