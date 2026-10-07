import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/customer.dart';
import '../../../core/models/sale.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/app_logger.dart';
import '../bloc/customers_bloc.dart';
import '../bloc/customers_event.dart';
import '../bloc/customers_state.dart';
import 'add_customer_screen.dart';

final _priceFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _dateFormat = DateFormat('d MMM, h:mm a');

/// Customers — real Firestore-backed directory (2026-09-24), replacing
/// the "(build next)" placeholder. Reached from Dashboard's Quick
/// Actions, same pushed-screen convention (back arrow + title, no
/// bottom nav) as Sales History/Reports/Staff Management, matching how
/// it's actually wired in AppRoutes/Dashboard rather than the 5-tab
/// AppBottomNav screens.
class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CustomersBloc()
        ..add(const CustomersSubscriptionRequested())
        ..add(const CustomersSalesSubscriptionRequested()),
      child: const _CustomersView(),
    );
  }
}

class _CustomersView extends StatefulWidget {
  const _CustomersView();

  @override
  State<_CustomersView> createState() => _CustomersViewState();
}

class _CustomersViewState extends State<_CustomersView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addCustomer(BuildContext context) async {
    // 2026-09-25: the Customers screen's own "Add Customer" button now
    // opens the bigger full-page form (AddCustomerScreen) instead of
    // the small `showAddCustomerSheet` bottom sheet -- that sheet is
    // now only used by the Sales checkout's quick "+ New" shortcut,
    // which needs to stay fast mid-sale.
    await Navigator.of(context).pushNamed(AppRoutes.addCustomer);
    // No explicit refresh needed -- CustomersBloc's live stream picks
    // up the new document on its own, same as every other live list
    // in this app.
  }

  /// 2026-10-06: edit an existing customer. Pushed directly with the
  /// `customer` constructor arg rather than through a named route --
  /// same convention `ProductsScreen` already uses for Edit Product
  /// (`AddProductScreen(product: product)`), since a named route can't
  /// carry a non-primitive argument like this cleanly. Reached from the
  /// small pencil icon on each row, not the row's own tap target, which
  /// stays wired to opening order history exactly as before.
  Future<void> _editCustomer(BuildContext context, Customer customer) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddCustomerScreen(customer: customer)));
    // Same reasoning as _addCustomer above -- the live stream picks up
    // an edited document on its own, no explicit refresh needed.
  }

  /// 2026-10-06: tap-to-call on each Customers row, matching the
  /// reference design's phone icon. A brand-new capability -- nothing
  /// in this app launched a phone dialer before, so this is the first
  /// use of `url_launcher` -- opens the device's own dialer pre-filled
  /// with the customer's stored +91 number, same as any "Call" link
  /// anywhere else on the phone; it doesn't place the call itself.
  Future<void> _callCustomer(BuildContext context, Customer customer) async {
    try {
      final launched = await launchUrl(Uri(scheme: 'tel', path: customer.phone));
      if (!launched) throw Exception('launchUrl returned false for tel:\${customer.phone}');
    } catch (e, st) {
      AppLogger.error('CustomersScreen._callCustomer', e, st);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Couldn't open the dialer")));
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
                        Text('Customers', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 18, color: p.textSecondary),
                    const SizedBox(width: 9),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => context.read<CustomersBloc>().add(CustomersSearchChanged(value)),
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
            Expanded(
              child: BlocBuilder<CustomersBloc, CustomersState>(
                builder: (context, state) {
                  if (state.isLoading && state.customers.isEmpty) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
                  }
                  if (state.errorMessage != null && state.customers.isEmpty) {
                    return Center(child: Text(state.errorMessage!, style: TextStyle(color: p.textSecondary)));
                  }
                  final customers = state.filteredCustomers;
                  if (customers.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          state.customers.isEmpty
                              ? 'No customers yet.\nTap "Add Customer" below to add the first one.'
                              : 'No match for "${state.searchQuery}"',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13.5, color: p.textSecondary, height: 1.5),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    itemCount: customers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      return _CustomerRow(
                        palette: p,
                        customer: customer,
                        orderCount: state.orderCountFor(customer.id),
                        isVip: state.isVip(customer.id),
                        onTap: () => _openOrderHistory(context, p, customer, state.salesFor(customer.id)),
                        onEdit: () => _editCustomer(context, customer),
                        onCall: () => _callCustomer(context, customer),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.border))),
              child: GestureDetector(
                onTap: () => _addCustomer(context),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add_alt_1_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Add Customer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openOrderHistory(BuildContext context, AppPalette p, Customer customer, List<Sale> sales) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerOrdersSheet(palette: p, customer: customer, sales: sales),
    );
  }
}

/// Row redesigned 2026-10-06 to match a reference screenshot the user
/// shared: a top line (avatar, name, phone, a tap-to-call button) and a
/// second line below it (an order-count pill, "Edit", the chevron) --
/// replacing the old single-row layout that showed total spent on the
/// right and a gold "VIP" badge next to the name. Confirmed with the
/// user via AskUserQuestion before building: the call icon is wired to
/// a real phone dialer (not decorative), the old VIP badge is dropped
/// in favor of a colored order-count pill (still driven by
/// CustomersState.isVip/vipOrderThreshold under the hood, just shown
/// as a color instead of a separate label), and "Total spent" is no
/// longer shown here -- it's still shown inside the order-history sheet
/// (_CustomerOrdersSheet) when a row is tapped.
class _CustomerRow extends StatelessWidget {
  final AppPalette palette;
  final Customer customer;
  final int orderCount;
  final bool isVip;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onCall;

  const _CustomerRow({
    required this.palette,
    required this.customer,
    required this.orderCount,
    required this.isVip,
    required this.onTap,
    required this.onEdit,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhone = customer.phone.isNotEmpty;

    // 0 orders -> neutral grey, 1+ -> blue, VIP threshold (5+, from
    // CustomersState) -> green. Reuses the same threshold the old VIP
    // badge used, just expressed as a pill color instead of a label.
    final Color badgeBg;
    final Color badgeText;
    if (orderCount == 0) {
      badgeBg = AppColors.neutralBg;
      badgeText = AppColors.neutralText;
    } else if (isVip) {
      badgeBg = AppColors.successBg;
      badgeText = AppColors.success;
    } else {
      badgeBg = AppColors.infoBg;
      badgeText = AppColors.info;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), shape: BoxShape.circle),
                  child: Text(customer.initials, style: const TextStyle(color: AppColors.accent, fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: palette.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasPhone ? customer.phone : 'No phone on file',
                        style: TextStyle(fontSize: 12, color: palette.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: hasPhone ? onCall : null,
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: hasPhone ? AppColors.accent.withOpacity(0.1) : palette.border,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.call_outlined,
                      size: 16,
                      color: hasPhone ? AppColors.accent : palette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(7)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_bag_outlined, size: 12, color: badgeText),
                      const SizedBox(width: 5),
                      Text(
                        orderCount == 1 ? '1 order' : '$orderCount orders',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: badgeText),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onEdit,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 14, color: palette.textSecondary),
                      const SizedBox(width: 4),
                      Text('Edit', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: palette.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, size: 18, color: palette.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Order-history bottom sheet for one customer, opened by tapping their
/// row. Read-only -- sales are never edited once completed anywhere
/// else in the app either (see Sale's own doc comment), so this just
/// looks back, same as Sales History does for the whole shop.
class _CustomerOrdersSheet extends StatelessWidget {
  final AppPalette palette;
  final Customer customer;
  final List<Sale> sales;

  const _CustomerOrdersSheet({required this.palette, required this.customer, required this.sales});

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final totalSpent = sales.fold(0.0, (sum, s) => sum + s.total);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(color: p.background, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.textPrimary)),
                          const SizedBox(height: 2),
                          Text(
                            sales.isEmpty
                                ? 'No orders yet'
                                : '${sales.length} order${sales.length == 1 ? '' : 's'} · ${_priceFormat.format(totalSpent)} total',
                            style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: sales.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'This customer has no orders linked yet.\nOrders get linked automatically once they\'re picked at checkout.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: p.textSecondary, height: 1.5),
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: sales.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final sale = sales[index];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: p.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: p.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sale.createdAt == null ? '—' : _dateFormat.format(sale.createdAt!),
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.textPrimary),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${sale.items.length} item${sale.items.length == 1 ? '' : 's'} · ${sale.paymentMethod.toUpperCase()}',
                                        style: TextStyle(fontSize: 11.5, color: p.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _priceFormat.format(sale.total),
                                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: p.textPrimary),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
