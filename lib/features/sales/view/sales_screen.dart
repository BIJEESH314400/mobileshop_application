import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/models/product.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../bloc/sales_bloc.dart';
import '../bloc/sales_event.dart';
import '../bloc/sales_state.dart';


final _priceFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// New Sale — cart, discount, tax/total summary and payment method, all
/// backed by real Firestore data via SalesBloc. "Add Product" opens a
/// picker over the shop's real, live-stocked products; "Complete Sale"
/// writes a real sale document and decrements each sold product's
/// stock in one Firestore transaction (see SaleRepository).
class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SalesBloc()..add(const SalesSubscriptionRequested()),
      child: const _SalesView(),
    );
  }
}

class _SalesView extends StatefulWidget {
  const _SalesView();

  @override
  State<_SalesView> createState() => _SalesViewState();
}

class _SalesViewState extends State<_SalesView> {
  final _discountController = TextEditingController();

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return BlocListener<SalesBloc, SalesState>(
      // Only reacts to the false->true transition, so an unrelated
      // rebuild after the cart resets doesn't re-fire the confirmation.
      listenWhen: (previous, current) => !previous.isSuccess && current.isSuccess,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sale completed · ${_priceFormat.format(state.completedTotal ?? 0)}')),
        );
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.dashboard, (route) => false);
      },
      child: BlocConsumer<SalesBloc, SalesState>(
        listenWhen: (previous, current) =>
            current.errorMessage != null && current.errorMessage != previous.errorMessage,
        listener: (context, state) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        },
        builder: (context, state) {
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'New Sale',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.textPrimary),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pushNamed(AppRoutes.salesHistory),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: p.card,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: p.border),
                                ),
                                child: Icon(Icons.history_rounded, size: 19, color: p.textPrimary),
                              ),
                            ),
                          ],
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
                          'CART · ${state.itemCount} ITEM${state.itemCount == 1 ? '' : 'S'}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        if (state.cartItems.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: p.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: p.border),
                            ),
                            child: Text(
                              'Cart is empty — tap Add Product below to start a sale',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: p.textSecondary),
                            ),
                          )
                        else
                          for (final item in state.cartItems) ...[
                            _CartItemCard(
                              palette: p,
                              item: item,
                              onDec: () => context
                                  .read<SalesBloc>()
                                  .add(SaleItemQtyChanged(productId: item.productId, delta: -1)),
                              onInc: () => context
                                  .read<SalesBloc>()
                                  .add(SaleItemQtyChanged(productId: item.productId, delta: 1)),
                              onRemove: () => context.read<SalesBloc>().add(SaleItemRemoved(item.productId)),
                            ),
                            const SizedBox(height: 10),
                          ],
                        GestureDetector(
                          onTap: () => _openProductPicker(context),
                          child: Container(
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFD8D8E0), width: 1.5, style: BorderStyle.solid),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
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
                        Text(
                          'DISCOUNT',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _discountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: p.textPrimary),
                          onChanged: (value) => context.read<SalesBloc>().add(SaleDiscountChanged(value)),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: p.card,
                            hintText: 'Enter discount amount (optional)',
                            hintStyle: TextStyle(color: p.textSecondary, fontSize: 13.5),
                            prefixIcon: Icon(Icons.sell_outlined, size: 18, color: p.textSecondary),
                            prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent)),
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
                              _SummaryRow(label: 'Subtotal', value: _priceFormat.format(state.subtotal), palette: p),
                              const SizedBox(height: 10),
                              _SummaryRow(
                                label: 'Discount',
                                value: state.discount > 0 ? '– ${_priceFormat.format(state.discount)}' : _priceFormat.format(0),
                                palette: p,
                                valueColor: state.discount > 0 ? AppColors.success : null,
                              ),
                              const SizedBox(height: 10),
                              _SummaryRow(
                                label: 'Tax (GST ${(SalesState.taxRate * 100).toStringAsFixed(0)}%)',
                                value: _priceFormat.format(state.tax),
                                palette: p,
                              ),
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
                                    _priceFormat.format(state.total),
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
                                selected: state.paymentMethod == PaymentMethod.upi,
                                onTap: () => context.read<SalesBloc>().add(const SalePaymentMethodChanged(PaymentMethod.upi)),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: _PayTile(
                                palette: p,
                                icon: Icons.credit_card_rounded,
                                label: 'Card',
                                selected: state.paymentMethod == PaymentMethod.card,
                                onTap: () => context.read<SalesBloc>().add(const SalePaymentMethodChanged(PaymentMethod.card)),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: _PayTile(
                                palette: p,
                                icon: Icons.currency_rupee_rounded,
                                label: 'Cash',
                                selected: state.paymentMethod == PaymentMethod.cash,
                                onTap: () => context.read<SalesBloc>().add(const SalePaymentMethodChanged(PaymentMethod.cash)),
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
                      onTap: state.isSubmitting || state.cartItems.isEmpty
                          ? null
                          : () => context.read<SalesBloc>().add(const SaleSubmitted()),
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: state.cartItems.isEmpty ? AppColors.accent.withOpacity(0.4) : AppColors.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: state.isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                              )
                            : Text(
                                'Complete Sale · ${_priceFormat.format(state.total)}',
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
        },
      ),
    );
  }

  void _openProductPicker(BuildContext context) {
    // showModalBottomSheet's builder isn't a descendant of the
    // BlocProvider above (the sheet mounts into the Navigator's
    // overlay, not this widget's subtree), so the bloc is handed down
    // explicitly with BlocProvider.value — the sheet reads it live via
    // BlocBuilder rather than working off a frozen snapshot passed in,
    // so "in cart" / "remaining" counts update the instant a tap adds
    // an item, without any manual setState bookkeeping.
    final bloc = context.read<SalesBloc>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: bloc,
        child: const _ProductPickerSheet(),
      ),
    );
  }
}

void _comingSoon(BuildContext context, String label) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$label — coming soon')),
  );
}

/// The "Add Product" sheet — the shop's real, live products, with
/// remaining stock shown per row. Tapping a row adds one to the cart
/// and keeps the sheet open, so the cashier can add several items in a
/// row without reopening it each time.
class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet();

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    // Reads SalesBloc directly (handed down via BlocProvider.value in
    // _openProductPicker) so the list, stock and "in cart" counts stay
    // live while this sheet is open — no snapshot to go stale.
    return BlocBuilder<SalesBloc, SalesState>(
      builder: (context, state) {
        final products = state.availableProducts;
        final cartQtyByProductId = {for (final item in state.cartItems) item.productId: item.qty};
        final filtered = _query.isEmpty
            ? products
            : products.where((product) {
                final haystack = '${product.name} ${product.sku} ${product.brand}'.toLowerCase();
                return haystack.contains(_query);
              }).toList();

        return _buildSheet(context, p, products, cartQtyByProductId, filtered);
      },
    );
  }

  Widget _buildSheet(
    BuildContext context,
    AppPalette p,
    List<Product> products,
    Map<String, int> cartQtyByProductId,
    List<Product> filtered,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(999)),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Add Product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary)),
                            const SizedBox(height: 3),
                            Text('Tap an item to add it to the cart', style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(color: p.background, shape: BoxShape.circle),
                          child: Icon(Icons.close_rounded, size: 16, color: p.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (products.length > 5) ...[
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: p.background,
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
                              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                              style: TextStyle(fontSize: 13.5, color: p.textPrimary),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'Search products, SKU or brand',
                                hintStyle: TextStyle(fontSize: 13.5, color: p.textSecondary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Flexible(
                    child: products.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text('No products yet — add one from the Products tab first.', style: TextStyle(fontSize: 13, color: p.textSecondary)),
                          )
                        : filtered.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Text('No match for "${_searchController.text.trim()}"', style: TextStyle(fontSize: 13, color: p.textSecondary)),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final product = filtered[i];
                                  final inCartQty = cartQtyByProductId[product.id] ?? 0;
                                  final remaining = product.stockQty - inCartQty;
                                  final disabled = remaining <= 0;
                                  final spec = [product.brand, product.condition].where((part) => part.isNotEmpty).join(' \u00b7 ');
                                  final stockStyle = remaining <= 0
                                      ? const _PickerStockStyle(AppColors.danger, 'Out of Stock')
                                      : remaining <= 5
                                          ? const _PickerStockStyle(AppColors.warningText, 'Low Stock')
                                          : const _PickerStockStyle(AppColors.success, 'In Stock');

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: p.card,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: p.border),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(color: AppColors.iconTint, borderRadius: BorderRadius.circular(12)),
                                          child: const Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.accent),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.name,
                                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.textPrimary),
                                              ),
                                              if (spec.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(spec, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                                              ],
                                              const SizedBox(height: 4),
                                              Text(
                                                _priceFormat.format(product.price),
                                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: p.textPrimary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _PickerStepBtn(
                                                  icon: Icons.remove_rounded,
                                                  palette: p,
                                                  enabled: inCartQty > 0,
                                                  onTap: () {
                                                    // At qty 1, SaleItemQtyChanged(-1) is a no-op by
                                                    // design (the main cart list floors at 1 and uses
                                                    // a separate trash icon to remove). This picker
                                                    // has no trash icon, so "-" at qty 1 removes the
                                                    // item outright instead of silently doing nothing.
                                                    if (inCartQty <= 1) {
                                                      context.read<SalesBloc>().add(SaleItemRemoved(product.id));
                                                    } else {
                                                      context
                                                          .read<SalesBloc>()
                                                          .add(SaleItemQtyChanged(productId: product.id, delta: -1));
                                                    }
                                                  },
                                                ),
                                                SizedBox(
                                                  width: 44,
                                                  child: Column(
                                                    children: [
                                                      Text(
                                                        '$remaining',
                                                        textAlign: TextAlign.center,
                                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: p.textPrimary),
                                                      ),
                                                      Text(
                                                        'STOCK',
                                                        textAlign: TextAlign.center,
                                                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: p.textSecondary),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                _PickerStepBtn(
                                                  icon: Icons.add_rounded,
                                                  palette: p,
                                                  enabled: !disabled,
                                                  onTap: () => context.read<SalesBloc>().add(SaleItemAdded(product)),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 7,
                                                  height: 7,
                                                  decoration: BoxDecoration(color: stockStyle.color, shape: BoxShape.circle),
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  stockStyle.label,
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: stockStyle.color),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerStockStyle {
  final Color color;
  final String label;
  const _PickerStockStyle(this.color, this.label);
}

/// Small square +/- button used in the "Add Product" picker sheet, next
/// to the live stock count — lets the cashier adjust how many of an
/// item go into the cart without leaving the sheet. Disabled (dimmed,
/// no tap) when there's nothing to add or remove.
class _PickerStepBtn extends StatelessWidget {
  final IconData icon;
  final AppPalette palette;
  final bool enabled;
  final VoidCallback onTap;

  const _PickerStepBtn({
    required this.icon,
    required this.palette,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // Always a solid, visible fill + border (not palette.background,
          // which is close in shade to the card behind it and can look
          // like "no button" on first render) — enabled/disabled is shown
          // by the border/icon color, never by making the box itself faint.
          color: AppColors.iconTint,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: enabled ? AppColors.accent : palette.border, width: enabled ? 1.4 : 1),
        ),
        child: Icon(
          icon,
          size: 15,
          color: enabled ? palette.textPrimary : palette.textSecondary.withOpacity(0.4),
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final AppPalette palette;
  final CartItem item;
  final VoidCallback onDec;
  final VoidCallback onInc;
  final VoidCallback onRemove;

  const _CartItemCard({
    required this.palette,
    required this.item,
    required this.onDec,
    required this.onInc,
    required this.onRemove,
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
            decoration: BoxDecoration(color: AppColors.iconTint, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.smartphone_rounded, size: 20, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  '${_priceFormat.format(item.price)} each',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: palette.textSecondary),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.delete_outline_rounded, size: 18, color: palette.textSecondary),
            ),
          ),
          Row(
            children: [
              _StepButton(palette: palette, filled: false, label: '–', onTap: onDec),
              SizedBox(
                width: 24,
                child: Text(
                  '${item.qty}',
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
