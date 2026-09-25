import 'package:flutter/material.dart';

import '../../../core/models/customer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../customers/view/add_customer_sheet.dart';

/// Distinguishes "closed without changing anything" (null) from
/// "explicitly cleared back to walk-in" (`cleared: true`) from "picked
/// this customer" (`customer` set) -- same pattern as
/// DateRangeFilterResult in Sales History's date sheet, for the same
/// reason: a bare nullable return can't tell "no change" apart from
/// "changed to null" on its own.
class CustomerPickerResult {
  final bool cleared;
  final Customer? customer;
  const CustomerPickerResult({this.cleared = false, this.customer});
}

/// Search-or-add customer picker for checkout. `customers` is whatever
/// SalesBloc's live customer stream currently has -- no separate
/// Firestore read here, this sheet is purely a search/pick UI over
/// data the Sales screen already has loaded.
Future<CustomerPickerResult?> showCustomerPickerSheet(
  BuildContext context, {
  required List<Customer> customers,
  required Customer? selected,
}) {
  return showModalBottomSheet<CustomerPickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CustomerPickerSheet(customers: customers, selected: selected),
  );
}

class _CustomerPickerSheet extends StatefulWidget {
  final List<Customer> customers;
  final Customer? selected;
  const _CustomerPickerSheet({required this.customers, required this.selected});

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addNew() async {
    final created = await showAddCustomerSheet(context);
    if (created != null && mounted) {
      Navigator.of(context).pop(CustomerPickerResult(customer: created));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.customers
        : widget.customers
            .where((c) => c.name.toLowerCase().contains(query) || c.phone.contains(query))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: p.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Select Customer', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.textPrimary)),
                    ),
                    GestureDetector(
                      onTap: _addNew,
                      child: const Row(
                        children: [
                          Icon(Icons.add_rounded, size: 18, color: AppColors.accent),
                          SizedBox(width: 4),
                          Text('New', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.accent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 18, color: p.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _query = value),
                          style: TextStyle(color: p.textPrimary, fontSize: 13.5),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Search name or phone',
                            hintStyle: TextStyle(color: p.textSecondary, fontSize: 13.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.storefront_outlined, color: p.textSecondary),
                      title: Text('Walk-in customer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.textPrimary)),
                      subtitle: Text('No customer recorded for this sale', style: TextStyle(fontSize: 12, color: p.textSecondary)),
                      trailing: widget.selected == null ? const Icon(Icons.check_circle_rounded, color: AppColors.accent) : null,
                      onTap: () => Navigator.of(context).pop(const CustomerPickerResult(cleared: true)),
                    ),
                    Divider(color: p.divider, height: 20),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          widget.customers.isEmpty ? 'No customers yet — tap "New" to add one' : 'No match for "$query"',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: p.textSecondary),
                        ),
                      )
                    else
                      for (final customer in filtered)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppColors.accent.withOpacity(0.12),
                            child: Text(customer.initials, style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w700)),
                          ),
                          title: Text(customer.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.textPrimary)),
                          subtitle: customer.phone.isEmpty ? null : Text(customer.phone, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                          trailing: widget.selected?.id == customer.id ? const Icon(Icons.check_circle_rounded, color: AppColors.accent) : null,
                          onTap: () => Navigator.of(context).pop(CustomerPickerResult(customer: customer)),
                        ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
