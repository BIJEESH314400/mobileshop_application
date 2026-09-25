import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';

final _cardDateFormat = DateFormat('EEE, MMM d');
final _cardYearFormat = DateFormat('EEE, MMM d, yyyy');

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// What the sheet handed back -- distinguishes "the X was tapped, don't
/// touch the existing filter" (a plain `null` from `showModalBottomSheet`)
/// from "Clear was tapped, actively remove the filter" (`cleared: true`,
/// no range) from "a range was applied" (`range` set). A bare `DateTimeRange?`
/// return value couldn't tell the first two apart.
class DateRangeFilterResult {
  final bool cleared;
  final DateTimeRange? range;
  const DateRangeFilterResult({this.cleared = false, this.range});
}

/// A custom-built replacement for Flutter's stock [showDateRangePicker],
/// matching the shop owner's reference design: quick filter pills
/// (Today/Yesterday/Last 7 Days/Custom), a real two-month calendar with
/// the selected range highlighted and future days grayed out (sales data
/// can't exist for a day that hasn't happened yet), and a bottom summary
/// bar. See the project status doc for the full design discussion.
Future<DateRangeFilterResult?> showDateRangeFilterSheet(
  BuildContext context, {
  DateTimeRange? initialRange,
}) {
  return showModalBottomSheet<DateRangeFilterResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _DateRangeFilterSheet(initialRange: initialRange),
  );
}

enum _QuickFilter { custom, today, yesterday, last7 }

class _DateRangeFilterSheet extends StatefulWidget {
  final DateTimeRange? initialRange;
  const _DateRangeFilterSheet({this.initialRange});

  @override
  State<_DateRangeFilterSheet> createState() => _DateRangeFilterSheetState();
}

class _DateRangeFilterSheetState extends State<_DateRangeFilterSheet> {
  late final DateTime _today;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  _QuickFilter _quickFilter = _QuickFilter.custom;

  // Which month the calendar is currently showing -- browsable with the
  // prev/next chevrons or a direct month/year jump (see _openMonthYearPicker),
  // not locked to "this month" the way the first version of this sheet was
  // (a real bug the shop owner caught: no way to reach January, or 2025,
  // 2024 ... older sales at all).
  late DateTime _viewMonth;

  // How far back browsing goes -- 30 years is generous for a shop's own
  // sales history while still being a concrete, sane bound rather than
  // unbounded. Forward is capped at the current month since a future
  // month can't have any sales yet.
  DateTime get _minMonth => DateTime(_today.year - 30, 1, 1);
  DateTime get _maxMonth => DateTime(_today.year, _today.month, 1);
  bool get _canGoPrev => _viewMonth.isAfter(_minMonth);
  bool get _canGoNext => _viewMonth.isBefore(_maxMonth);

  @override
  void initState() {
    super.initState();
    _today = _dayOnly(DateTime.now());
    final initial = widget.initialRange;
    if (initial != null) {
      _rangeStart = _dayOnly(initial.start);
      _rangeEnd = _dayOnly(initial.end);
      _quickFilter = _detectQuickFilter(_rangeStart, _rangeEnd);
      // Open the calendar on the selected range's own month rather than
      // always "this month" -- reopening the filter to tweak an older
      // custom range should land you back where you left it.
      _viewMonth = DateTime(_rangeStart!.year, _rangeStart!.month, 1);
    } else {
      _viewMonth = DateTime(_today.year, _today.month, 1);
    }
  }

  void _goPrevMonth() {
    if (!_canGoPrev) return;
    setState(() => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1, 1));
  }

  void _goNextMonth() {
    if (!_canGoNext) return;
    setState(() => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 1));
  }

  Future<void> _openMonthYearPicker() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _MonthYearPicker(
        initialMonth: _viewMonth,
        minMonth: _minMonth,
        maxMonth: _maxMonth,
      ),
    );
    if (picked != null) setState(() => _viewMonth = picked);
  }

  _QuickFilter _detectQuickFilter(DateTime? start, DateTime? end) {
    if (start == null || end == null) return _QuickFilter.custom;
    final yesterday = _today.subtract(const Duration(days: 1));
    final last7Start = _today.subtract(const Duration(days: 6));
    if (start == _today && end == _today) return _QuickFilter.today;
    if (start == yesterday && end == yesterday) return _QuickFilter.yesterday;
    if (start == last7Start && end == _today) return _QuickFilter.last7;
    return _QuickFilter.custom;
  }

  void _applyQuickFilter(_QuickFilter filter) {
    setState(() {
      _quickFilter = filter;
      switch (filter) {
        case _QuickFilter.today:
          _rangeStart = _today;
          _rangeEnd = _today;
          break;
        case _QuickFilter.yesterday:
          final y = _today.subtract(const Duration(days: 1));
          _rangeStart = y;
          _rangeEnd = y;
          break;
        case _QuickFilter.last7:
          _rangeStart = _today.subtract(const Duration(days: 6));
          _rangeEnd = _today;
          break;
        case _QuickFilter.custom:
          // Just switches the mode so a calendar tap starts a fresh pick --
          // doesn't clear whatever's already selected on its own, and
          // deliberately doesn't jump the calendar view either (unlike
          // the other three cases below) -- there's no new date to reveal.
          break;
      }
      // Today/Yesterday/Last 7 Days all pick dates anchored at "today" --
      // if the calendar was left showing some other month (e.g. browsed
      // back to June 2012), the pill would silently pick the right dates
      // but never show them, since the visible grid never moved to match.
      // Jump the view to the new selection's own month so what's picked
      // is always what's on screen.
      if (filter != _QuickFilter.custom) {
        _viewMonth = DateTime(_rangeStart!.year, _rangeStart!.month, 1);
      }
    });
  }

  void _tapDay(DateTime day) {
    if (day.isAfter(_today)) return; // future days have no sales yet
    setState(() {
      _quickFilter = _QuickFilter.custom;
      if (_rangeStart == null || _rangeEnd != null) {
        // Nothing picked yet, or a complete range already exists -- start over.
        _rangeStart = day;
        _rangeEnd = null;
      } else if (day.isBefore(_rangeStart!)) {
        _rangeEnd = _rangeStart;
        _rangeStart = day;
      } else {
        _rangeEnd = day;
      }
    });
  }

  void _reset() {
    setState(() {
      _rangeStart = null;
      _rangeEnd = null;
      _quickFilter = _QuickFilter.custom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final effectiveEnd = _rangeEnd ?? _rangeStart;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              _SheetHeader(
                palette: palette,
                onClose: () => Navigator.pop(context),
                onReset: _reset,
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  children: [
                    _FilterRangeCards(palette: palette, start: _rangeStart, end: effectiveEnd, today: _today),
                    const SizedBox(height: 14),
                    _QuickFilterRow(selected: _quickFilter, onSelect: _applyQuickFilter, palette: palette),
                    const SizedBox(height: 18),
                    _LegendRow(palette: palette, today: _today),
                    const SizedBox(height: 12),
                    _MonthCalendar(
                      month: _viewMonth,
                      palette: palette,
                      today: _today,
                      rangeStart: _rangeStart,
                      rangeEnd: effectiveEnd,
                      onTapDay: _tapDay,
                      canGoPrev: _canGoPrev,
                      canGoNext: _canGoNext,
                      onPrevMonth: _goPrevMonth,
                      onNextMonth: _goNextMonth,
                      onTapMonthYear: _openMonthYearPicker,
                    ),
                  ],
                ),
              ),
              _SheetBottomBar(
                palette: palette,
                start: _rangeStart,
                end: effectiveEnd,
                onClear: () => Navigator.pop(context, const DateRangeFilterResult(cleared: true)),
                onApply: _rangeStart == null
                    ? null
                    : () => Navigator.pop(
                          context,
                          DateRangeFilterResult(range: DateTimeRange(start: _rangeStart!, end: effectiveEnd!)),
                        ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final AppPalette palette;
  final VoidCallback onClose;
  final VoidCallback onReset;
  const _SheetHeader({required this.palette, required this.onClose, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.divider))),
      child: Row(
        children: [
          // A small centered drag-handle above the title row would be nice,
          // but DraggableScrollableSheet doesn't paint one for free -- this
          // header row already gives enough of a "sheet" affordance via its
          // rounded top corners + close button.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: Icon(Icons.close_rounded, size: 22, color: palette.textSecondary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sales History', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: palette.textSecondary)),
                Text('Select Date Range', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: palette.textPrimary)),
              ],
            ),
          ),
          TextButton(
            onPressed: onReset,
            style: TextButton.styleFrom(foregroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _FilterRangeCards extends StatelessWidget {
  final AppPalette palette;
  final DateTime? start;
  final DateTime? end;
  final DateTime today;
  const _FilterRangeCards({required this.palette, required this.start, required this.end, required this.today});

  String _tagFor(DateTime? d) {
    if (d == null) return '--';
    if (d == today) return 'Today';
    final diff = today.difference(d).inDays;
    if (diff == 1) return '1d ago';
    if (diff > 1) return '${diff}d ago';
    return _cardDateFormat.format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.card,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FILTER RANGE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: palette.textSecondary, letterSpacing: 0.6)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _DateSlot(label: 'START DATE', value: start, tag: _tagFor(start), palette: palette, tagColor: AppColors.accent)),
              const SizedBox(width: 10),
              Expanded(
                child: _DateSlot(
                  label: 'END DATE',
                  value: end,
                  tag: end == today ? 'Today' : _tagFor(end),
                  palette: palette,
                  tagColor: end == today ? AppColors.success : AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateSlot extends StatelessWidget {
  final String label;
  final DateTime? value;
  final String tag;
  final AppPalette palette;
  final Color tagColor;
  const _DateSlot({required this.label, required this.value, required this.tag, required this.palette, required this.tagColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: palette.background, border: Border.all(color: palette.border), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: palette.textSecondary, letterSpacing: 0.4)),
              if (value != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: tagColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(tag, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: tagColor)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value == null ? 'Select' : _cardDateFormat.format(value!),
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: palette.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _QuickFilterRow extends StatelessWidget {
  final _QuickFilter selected;
  final ValueChanged<_QuickFilter> onSelect;
  final AppPalette palette;
  const _QuickFilterRow({required this.selected, required this.onSelect, required this.palette});

  @override
  Widget build(BuildContext context) {
    final items = const [
      (_QuickFilter.custom, 'Custom'),
      (_QuickFilter.today, 'Today'),
      (_QuickFilter.yesterday, 'Yesterday'),
      (_QuickFilter.last7, 'Last 7 Days'),
    ];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (filter, label) = items[i];
          final isSelected = filter == selected;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(filter),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent : palette.card,
                border: Border.all(color: isSelected ? AppColors.accent : palette.border),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : palette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final AppPalette palette;
  final DateTime today;
  const _LegendRow({required this.palette, required this.today});

  @override
  Widget build(BuildContext context) {
    final yesterday = today.subtract(const Duration(days: 1));
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _LegendDot(color: AppColors.success, label: 'Today (${DateFormat('MMM d').format(today)})', palette: palette),
        _LegendDot(color: palette.textSecondary, label: 'Yesterday (${DateFormat('MMM d').format(yesterday)})', palette: palette, outlined: true),
        Text('Gray = Future (No Data)', style: TextStyle(fontSize: 10.5, color: palette.textSecondary)),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final AppPalette palette;
  final bool outlined;
  const _LegendDot({required this.color, required this.label, required this.palette, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: outlined ? Colors.transparent : color,
            border: outlined ? Border.all(color: color, width: 1.4) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: palette.textSecondary)),
      ],
    );
  }
}

/// Calendar-quarter fiscal label + a status word for the month header
/// badge ("Q3 FY26 · Completed" / "In Progress" / "Future Period") --
/// this app has no separately-defined fiscal-year start, so calendar
/// quarters are used directly rather than inventing an FY convention
/// nothing else in the app follows.
String _fiscalBadge(DateTime month, DateTime today) {
  final quarter = ((month.month - 1) ~/ 3) + 1;
  final fy = month.year % 100;
  final monthEnd = DateTime(month.year, month.month + 1, 0);
  final String status;
  if (monthEnd.isBefore(today)) {
    status = 'Completed';
  } else if (month.year == today.year && month.month == today.month) {
    status = 'In Progress';
  } else {
    status = 'Future Period';
  }
  return 'Q$quarter FY$fy • $status';
}

class _MonthCalendar extends StatelessWidget {
  final DateTime month; // first-of-month, the month currently being viewed
  final AppPalette palette;
  final DateTime today;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final ValueChanged<DateTime> onTapDay;
  final bool canGoPrev;
  final bool canGoNext;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onTapMonthYear;

  const _MonthCalendar({
    required this.month,
    required this.palette,
    required this.today,
    required this.rangeStart,
    required this.rangeEnd,
    required this.onTapDay,
    required this.canGoPrev,
    required this.canGoNext,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onTapMonthYear,
  });

  List<DateTime?> _cells() {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = DateTime(month.year, month.month, 1).weekday % 7; // Sunday = 0
    return [
      ...List<DateTime?>.filled(leading, null),
      for (var d = 1; d <= daysInMonth; d++) DateTime(month.year, month.month, d),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cells = _cells();
    final yesterday = today.subtract(const Duration(days: 1));

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prev/next chevrons + a tappable "September 2026" label --
          // browsing to any month (including past years, e.g. Jan or a
          // prior year's Sep) needs a real way in, which the first version
          // of this sheet was missing entirely (it only ever showed the
          // current month).
          Row(
            children: [
              _NavChevron(icon: Icons.chevron_left_rounded, enabled: canGoPrev, onTap: onPrevMonth, palette: palette),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTapMonthYear,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(DateFormat('MMMM yyyy').format(month), style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: palette.textPrimary)),
                        const SizedBox(width: 4),
                        Icon(Icons.expand_more_rounded, size: 18, color: palette.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
              _NavChevron(icon: Icons.chevron_right_rounded, enabled: canGoNext, onTap: onNextMonth, palette: palette),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: palette.divider, borderRadius: BorderRadius.circular(8)),
              child: Text(_fiscalBadge(month, today), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: palette.textSecondary)),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ))
                  .toList(),
            ),
          ),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.05,
            children: cells.map((day) {
              if (day == null) return const SizedBox.shrink();
              final isToday = day == today;
              final isYesterday = day == yesterday;
              final isFuture = day.isAfter(today);
              final isStart = rangeStart != null && day == rangeStart;
              final isEnd = rangeEnd != null && day == rangeEnd;
              final inRange = rangeStart != null &&
                  rangeEnd != null &&
                  day.isAfter(rangeStart!) &&
                  day.isBefore(rangeEnd!);
              final isEndpoint = isStart || isEnd;

              String? caption;
              if (isStart && isEnd) {
                caption = isToday ? 'TODAY' : null;
              } else if (isStart) {
                caption = 'START';
              } else if (isEnd) {
                caption = isToday ? 'TODAY' : 'END';
              } else if (isToday) {
                caption = 'TODAY';
              } else if (isYesterday) {
                caption = 'YESTERDAY';
              }

              Color bg = Colors.transparent;
              Color fg = isFuture ? palette.textSecondary.withOpacity(0.45) : palette.textPrimary;
              BoxBorder? border;
              if (isEndpoint) {
                bg = AppColors.accent;
                fg = Colors.white;
              } else if (inRange) {
                bg = AppColors.accent.withOpacity(0.14);
              } else if (isToday) {
                border = Border.all(color: AppColors.success, width: 1.4);
                fg = AppColors.success;
              } else if (isYesterday) {
                border = Border.all(color: palette.textSecondary, width: 1.2);
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: !isFuture ? () => onTapDay(day) : null,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: bg, border: border, shape: BoxShape.circle),
                        child: Text(
                          '${day.day}',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: fg),
                        ),
                      ),
                      if (caption != null)
                        Text(
                          caption,
                          style: TextStyle(
                            fontSize: 6.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                            color: isEndpoint ? AppColors.accent : palette.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
  }
}

class _NavChevron extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final AppPalette palette;
  const _NavChevron({required this.icon, required this.enabled, required this.onTap, required this.palette});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: palette.border),
          color: palette.card,
        ),
        child: Icon(icon, size: 18, color: enabled ? palette.textPrimary : palette.textSecondary.withOpacity(0.35)),
      ),
    );
  }
}

/// Two-step month/year jump sheet, opened by tapping the month/year label
/// on the calendar -- lets the shop owner reach an arbitrary past month
/// (e.g. "September 2024") in two taps instead of pressing a chevron
/// dozens of times.
class _MonthYearPicker extends StatefulWidget {
  final DateTime initialMonth;
  final DateTime minMonth;
  final DateTime maxMonth;
  const _MonthYearPicker({required this.initialMonth, required this.minMonth, required this.maxMonth});

  @override
  State<_MonthYearPicker> createState() => _MonthYearPickerState();
}

class _MonthYearPickerState extends State<_MonthYearPicker> {
  late int? _selectedYear = widget.initialMonth.year;
  bool _pickingMonth = true;

  static const _monthLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    // Straight into the month grid for the year the calendar's already
    // on -- picking the year again would be a wasted extra tap for the
    // common case of "jump to a different month, same year".
    _pickingMonth = true;
  }

  bool _monthEnabled(int year, int month1based) {
    final candidate = DateTime(year, month1based, 1);
    return !candidate.isBefore(DateTime(widget.minMonth.year, widget.minMonth.month, 1)) &&
        !candidate.isAfter(DateTime(widget.maxMonth.year, widget.maxMonth.month, 1));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final years = [for (var y = widget.maxMonth.year; y >= widget.minMonth.year; y--) y];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_pickingMonth)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _pickingMonth = false),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chevron_left_rounded, size: 20, color: palette.textSecondary),
                        Text('${_selectedYear}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: palette.textPrimary)),
                      ],
                    ),
                  )
                else
                  Text('Select Year', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: palette.textPrimary)),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close_rounded, size: 20, color: palette.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (!_pickingMonth)
              SizedBox(
                height: 280,
                child: GridView.count(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.8,
                  children: years.map((y) {
                    final isSelected = y == _selectedYear;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() {
                        _selectedYear = y;
                        _pickingMonth = true;
                      }),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.accent : palette.background,
                          border: Border.all(color: isSelected ? AppColors.accent : palette.border),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$y',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : palette.textPrimary),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              )
            else
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
                children: List.generate(12, (i) {
                  final month1based = i + 1;
                  final year = _selectedYear!;
                  final enabled = _monthEnabled(year, month1based);
                  final isCurrent = year == widget.initialMonth.year && month1based == widget.initialMonth.month;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: enabled ? () => Navigator.pop(context, DateTime(year, month1based, 1)) : null,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isCurrent ? AppColors.accent : palette.background,
                        border: Border.all(color: isCurrent ? AppColors.accent : palette.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _monthLabels[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: !enabled
                              ? palette.textSecondary.withOpacity(0.35)
                              : isCurrent
                                  ? Colors.white
                                  : palette.textPrimary,
                        ),
                      ),
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}

class _SheetBottomBar extends StatelessWidget {
  final AppPalette palette;
  final DateTime? start;
  final DateTime? end;
  final VoidCallback onClear;
  final VoidCallback? onApply;
  const _SheetBottomBar({required this.palette, required this.start, required this.end, required this.onClear, required this.onApply});

  @override
  Widget build(BuildContext context) {
    final count = (start != null && end != null) ? end!.difference(start!).inDays + 1 : 0;
    final summary = start == null
        ? 'No date selected'
        : (end == null || start == end)
            ? _cardYearFormat.format(start!)
            : '${DateFormat('MMM d').format(start!)} - ${_cardYearFormat.format(end!)}';

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: palette.card, border: Border(top: BorderSide(color: palette.divider))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(summary, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.textPrimary), overflow: TextOverflow.ellipsis),
              ),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.iconTint, borderRadius: BorderRadius.circular(8)),
                  child: Text('$count Selected', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.accent)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onClear,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.textPrimary,
                    side: BorderSide(color: palette.border),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    disabledBackgroundColor: AppColors.accent.withOpacity(0.35),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('View Sales Report', style: TextStyle(fontWeight: FontWeight.w800)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
