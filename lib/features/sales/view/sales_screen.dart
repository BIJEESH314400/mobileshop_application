import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/product.dart';
import '../../../core/repositories/product_unit_repository.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../product_requests/view/add_request_screen.dart';
import '../../products/view/barcode_scanner_screen.dart';
import '../bloc/sales_bloc.dart';
import '../bloc/sales_event.dart';
import '../bloc/sales_state.dart';
import 'customer_picker_sheet.dart';


final _priceFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// Result of looking a scanned/typed code up against this shop's
/// products and ProductUnits (see [_SalesViewState._resolveBarcode]).
/// The two named constructors keep "resolved" and "failed" mutually
/// exclusive -- every call site needs either a product+barcode+
/// optional unitId, or a human-readable reason it failed, never both.
class _BarcodeResolution {
  final Product? product;
  final String? barcode;
  final String? unitId;
  final String? error;

  const _BarcodeResolution.ok({required this.product, required this.barcode, this.unitId}) : error = null;

  const _BarcodeResolution.error(this.error)
      : product = null,
        barcode = null,
        unitId = null;

  bool get isOk => error == null;
}

/// Points at one specific pending slot -- one physical unit still
/// needing a barcode -- on one cart line. Used by "Scan All Barcodes"
/// to walk the whole cart in order.
class _PendingSlotRef {
  final String productId;
  final int slotIndex;
  const _PendingSlotRef(this.productId, this.slotIndex);
}

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
      create: (_) => SalesBloc()
        ..add(const SalesSubscriptionRequested())
        ..add(const SalesCustomersSubscriptionRequested()),
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
  final _unitRepository = ProductUnitRepository();

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
      listener: (context, state) async {
        await _showSaleSuccessOverlay(context, state.completedTotal ?? 0);
        if (!context.mounted) return;
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
                        if (state.cartItems.isEmpty) ...[
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
                          ),
                          const SizedBox(height: 14),
                        ] else
                          for (final item in state.cartItems) ...[
                            _CartLineAnimated(
                              key: ValueKey(item.productId),
                              child: _CartItemCard(
                                palette: p,
                                item: item,
                                onIncrement: () => _incrementCartItem(context, item),
                                onDecrement: () => context.read<SalesBloc>().add(SaleItemUnitRemoved(item.productId)),
                                onQuickRemove: (count) => context
                                    .read<SalesBloc>()
                                    .add(SaleItemQuickRemove(productId: item.productId, count: count)),
                                onRemove: () => context.read<SalesBloc>().add(SaleItemRemoved(item.productId)),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _scanBarcode(context),
                                child: Container(
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.qr_code_scanner_rounded, size: 16, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text(
                                        'Scan Barcode',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _openProductPicker(context),
                                child: Container(
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFD8D8E0), width: 1.5, style: BorderStyle.solid),
                                  ),
                                  child: Row(
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
                            ),
                          ],
                        ),
                        if (state.cartItems.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'ITEM BARCODES (${state.cartItems.fold(0, (sum, item) => sum + item.verifiedCount)} OF '
                                  '${state.cartItems.fold(0, (sum, item) => sum + item.qty)} ASSIGNED)',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.textSecondary),
                                ),
                              ),
                              if (!state.allBarcodesVerified)
                                GestureDetector(
                                  onTap: () => _scanAllBarcodes(context),
                                  child: Text(
                                    'Scan All Barcodes',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline_rounded, size: 14, color: AppColors.accent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Every unit in the cart needs its own barcode scanned or typed before you can complete the sale.',
                                    style: TextStyle(fontSize: 11.5, color: p.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (final item in state.cartItems)
                            if (item.tracksUniqueUnits)
                              for (var i = 0; i < item.slots.length; i++) ...[
                                _BarcodeSlotRow(
                                  palette: p,
                                  productName: item.name,
                                  hintBarcode: item.barcode,
                                  slotNumber: i + 1,
                                  slotCount: item.slots.length,
                                  slot: item.slots[i],
                                  onScan: () => _assignSlotByScan(context, item.productId, i),
                                  onType: (code) => _assignSlot(context, item.productId, i, code),
                                  onRemove: () => context
                                      .read<SalesBloc>()
                                      .add(SaleItemSlotRemoved(productId: item.productId, slotIndex: i)),
                                ),
                                const SizedBox(height: 8),
                              ]
                            else ...[
                              // Bulk product (tracksUniqueUnits == false) -- every
                              // physical unit on this line carries the exact same
                              // printed barcode (think a stack of identical comic
                              // books), so one row represents the WHOLE line rather
                              // than one row per unit. Confirming it here marks
                              // every slot on the line verified at once -- see
                              // SalesBloc._verifyWholeLineIfBulk.
                              _BarcodeSlotRow(
                                palette: p,
                                productName: item.name,
                                hintBarcode: item.barcode,
                                slotNumber: 1,
                                slotCount: item.qty,
                                slot: item.slots.isEmpty ? const CartUnitSlot() : item.slots.first,
                                isBulkSummary: true,
                                onScan: () => _assignSlotByScan(context, item.productId, 0),
                                onType: (code) => _assignSlot(context, item.productId, 0, code),
                              ),
                              const SizedBox(height: 8),
                            ],
                        ],
                        const SizedBox(height: 18),
                        Text(
                          'CUSTOMER (OPTIONAL)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () async {
                            final result = await showCustomerPickerSheet(
                              context,
                              customers: state.availableCustomers,
                              selected: state.selectedCustomer,
                            );
                            if (result == null || !context.mounted) return;
                            context.read<SalesBloc>().add(SaleCustomerSelected(result.customer));
                          },
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: p.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: p.border),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.person_outline_rounded, size: 18, color: p.textSecondary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    state.selectedCustomer == null
                                        ? 'Walk-in customer — tap to add'
                                        : state.selectedCustomer!.name,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: state.selectedCustomer == null ? FontWeight.w500 : FontWeight.w700,
                                      color: state.selectedCustomer == null ? p.textSecondary : p.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (state.selectedCustomer != null)
                                  GestureDetector(
                                    onTap: () => context.read<SalesBloc>().add(const SaleCustomerSelected(null)),
                                    child: Icon(Icons.close_rounded, size: 18, color: p.textSecondary),
                                  )
                                else
                                  Icon(Icons.chevron_right_rounded, size: 18, color: p.textSecondary),
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
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.accent)),
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
                                label: 'Tax (GST ${state.taxRatePercent.toStringAsFixed(state.taxRatePercent == state.taxRatePercent.roundToDouble() ? 0 : 1)}%)',
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.pendingBarcodeCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${state.pendingBarcodeCount} Barcode${state.pendingBarcodeCount == 1 ? '' : 's'} pending',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.danger),
                            ),
                          ),
                        GestureDetector(
                          onTap: state.isSubmitting || state.cartItems.isEmpty || !state.allBarcodesVerified
                              ? null
                              : () => _confirmAndSubmit(context, state),
                          child: Container(
                            height: 52,
                            width: double.infinity,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: state.cartItems.isEmpty || !state.allBarcodesVerified
                                  ? AppColors.accent.withOpacity(0.4)
                                  : AppColors.accent,
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
                      ],
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

  /// Opens the shared camera scanner, resolves the code via
  /// [_resolveBarcode] (no specific product expected -- the top
  /// button's job is "figure out what this is"), then adds it to the
  /// cart already-verified via SaleItemScannedAdded. No match just
  /// shows a plain error and leaves the cart untouched; manual search
  /// (the "Add Product" button) is always right there as a fallback.
  Future<void> _scanBarcode(BuildContext context) async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || code.trim().isEmpty || !context.mounted) return;

    final resolution = await _resolveBarcode(context, rawCode: code);
    if (!context.mounted) return;

    if (!resolution.isOk) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(resolution.error!), backgroundColor: AppColors.danger));
      return;
    }

    context.read<SalesBloc>().add(SaleItemScannedAdded(
          product: resolution.product!,
          barcode: resolution.barcode!,
          unitId: resolution.unitId,
        ));
  }

  /// Looks a scanned/typed code up against this shop's own
  /// already-loaded products (same in-memory list the picker uses) and
  /// ProductUnits -- shared by the top "Scan Barcode" button, each
  /// pending slot's own Scan/Type controls, and "Scan All Barcodes",
  /// so there's one lookup path instead of three near-copies.
  ///
  /// `expectedProductId` is null for the top button and "Scan All"
  /// (which don't know in advance which product a code belongs to --
  /// any real match is accepted). Set, it's a specific pending slot on
  /// one cart line, so a code that resolves to a DIFFERENT product is
  /// rejected even though it's otherwise a real, known code.
  Future<_BarcodeResolution> _resolveBarcode(
    BuildContext context, {
    required String rawCode,
    String? expectedProductId,
  }) async {
    final code = rawCode.trim();
    if (code.isEmpty) return const _BarcodeResolution.error('Enter or scan a barcode');

    final bloc = context.read<SalesBloc>();
    final products = bloc.state.availableProducts;

    // 1. A specific ProductUnit's own individually-generated code (see
    // ProductUnit, minted by Print Barcode Labels' "Unique code per
    // sticker" toggle).
    final unit = await _unitRepository.findByCode(code, shopId: currentShopId);
    if (unit != null) {
      if (expectedProductId != null && unit.productId != expectedProductId) {
        return const _BarcodeResolution.error('This code belongs to a different product');
      }
      if (!unit.isAvailable) {
        return const _BarcodeResolution.error("That unit was already sold — it can't be sold again");
      }
      if (bloc.state.cartItems.any((item) => item.unitIds.contains(unit.id))) {
        return const _BarcodeResolution.error('That unit is already in this cart');
      }
      final unitMatches = products.where((p) => p.id == unit.productId);
      final unitProduct = unitMatches.isEmpty ? null : unitMatches.first;
      if (unitProduct == null) {
        return const _BarcodeResolution.error("That unit's product couldn't be found");
      }
      return _BarcodeResolution.ok(product: unitProduct, barcode: code, unitId: unit.id);
    }

    // 2. A product's own shared barcode.
    final directMatches = products.where((p) => p.barcode.isNotEmpty && p.barcode == code);
    final direct = directMatches.isEmpty ? null : directMatches.first;
    if (direct != null) {
      if (expectedProductId != null && direct.id != expectedProductId) {
        return const _BarcodeResolution.error('This barcode belongs to a different product');
      }
      return _BarcodeResolution.ok(product: direct, barcode: code, unitId: null);
    }

    return const _BarcodeResolution.error('Barcode not recognized — try Add Product to search manually');
  }

  /// Fills one specific pending slot in, whichever of Scan/Type
  /// produced the raw code.
  Future<void> _assignSlot(BuildContext context, String productId, int slotIndex, String rawCode) async {
    final resolution = await _resolveBarcode(context, rawCode: rawCode, expectedProductId: productId);
    if (!context.mounted) return;
    if (!resolution.isOk) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(resolution.error!), backgroundColor: AppColors.danger));
      return;
    }
    context.read<SalesBloc>().add(SaleItemSlotVerified(
          productId: productId,
          slotIndex: slotIndex,
          barcode: resolution.barcode!,
          unitId: resolution.unitId,
        ));
  }

  Future<void> _assignSlotByScan(BuildContext context, String productId, int slotIndex) async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || !context.mounted) return;
    await _assignSlot(context, productId, slotIndex, code);
  }

  /// "Scan All Barcodes" -- repeatedly opens the scanner and feeds each
  /// successful scan into the next still-pending slot across the WHOLE
  /// cart (in cart order), looping until nothing's pending or the
  /// cashier backs out of the scanner. A code that resolves but
  /// belongs to a different product than the next pending slot shows
  /// an error and lets them rescan for that same slot, rather than
  /// silently skipping ahead.
  Future<void> _scanAllBarcodes(BuildContext context) async {
    final bloc = context.read<SalesBloc>();
    while (context.mounted) {
      final pending = _firstPendingSlot(bloc.state);
      if (pending == null) break;

      final code = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
      );
      if (code == null || !context.mounted) break;

      final resolution = await _resolveBarcode(context, rawCode: code, expectedProductId: pending.productId);
      if (!context.mounted) return;
      if (!resolution.isOk) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(resolution.error!), backgroundColor: AppColors.danger));
        continue;
      }
      bloc.add(SaleItemSlotVerified(
        productId: pending.productId,
        slotIndex: pending.slotIndex,
        barcode: resolution.barcode!,
        unitId: resolution.unitId,
      ));
    }
  }

  _PendingSlotRef? _firstPendingSlot(SalesState state) {
    for (final item in state.cartItems) {
      for (var i = 0; i < item.slots.length; i++) {
        if (!item.slots[i].isVerified) return _PendingSlotRef(item.productId, i);
      }
    }
    return null;
  }

  /// Adds one more pending slot to an existing cart line, from the
  /// cart card's own "+" button -- reuses SaleItemAdded (the same
  /// event the picker dispatches for a brand-new line) rather than a
  /// separate event, since the bloc's handler already knows how to
  /// grow an existing line and enforce live stock. The cart line
  /// itself only keeps a stock SNAPSHOT (CartItem.availableStock), not
  /// the live Product, so this looks the product back up by id and
  /// shows an error instead of incrementing if it's gone missing
  /// (deleted/archived) since it was added.
  void _incrementCartItem(BuildContext context, CartItem item) {
    final bloc = context.read<SalesBloc>();
    final matches = bloc.state.availableProducts.where((product) => product.id == item.productId);
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('${item.name} is no longer available'), backgroundColor: AppColors.danger));
      return;
    }
    bloc.add(SaleItemAdded(matches.first));
  }

  /// Tapping Complete Sale no longer submits straight away -- it
  /// opens a confirmation sheet first (the user asked for this
  /// explicitly: a final "all items verified, complete this sale?"
  /// check before the Firestore transaction actually runs). The
  /// button itself is already disabled unless `allBarcodesVerified`,
  /// so this isn't a new validation -- it's a visible confirmation
  /// of a fact that's already true, giving the cashier one more
  /// chance to back out of a mis-tap before the sale is final.
  Future<void> _confirmAndSubmit(BuildContext context, SalesState state) async {
    final confirmed = await _CompleteSaleConfirmSheet.show(context, state);
    if (!confirmed || !context.mounted) return;
    context.read<SalesBloc>().add(const SaleSubmitted());
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
                                  final spec = [product.category, product.brand, product.condition].where((part) => part.isNotEmpty).join(' \u00b7 ');
                                  final stockStyle = remaining <= 0
                                      ? const _PickerStockStyle(AppColors.danger, 'Out of Stock')
                                      : remaining <= 5
                                          ? const _PickerStockStyle(AppColors.warningText, 'Low Stock')
                                          : const _PickerStockStyle(AppColors.success, 'In Stock');

                                  return GestureDetector(
                                    onTap: disabled
                                        ? null
                                        : () {
                                            context.read<SalesBloc>().add(SaleItemAdded(product));
                                            Navigator.of(context).pop();
                                          },
                                    child: Container(
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
                                          child: Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.accent),
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
                                              // Tapping ANY row (unique-barcode product or
                                              // plain) now adds/binds one unit to the cart --
                                              // no +/- stepper here any more (see
                                              // SaleItemAdded's doc comment).
                                              if (inCartQty > 0) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  '$inCartQty in cart · tap to add another',
                                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.accent),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            SizedBox(
                                              width: 50,
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
                                            // Truly out of stock (not just "all of it is
                                            // already in the cart") -- offer to save who's
                                            // waiting for it. Added 2026-10-07.
                                            if (product.stockQty <= 0) ...[
                                              const SizedBox(height: 6),
                                              GestureDetector(
                                                onTap: () {
                                                  final selected = context.read<SalesBloc>().state.selectedCustomer;
                                                  Navigator.of(context).push(MaterialPageRoute(
                                                    builder: (_) => AddRequestScreen(
                                                      productId: product.id,
                                                      initialItemName: product.name,
                                                      initialCustomer: selected,
                                                    ),
                                                  ));
                                                },
                                                child: Text(
                                                  '+ Save request',
                                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.accent),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
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

/// Small square +/- button used on each cart line to grow or shrink
/// its quantity by one slot at a time. Disabled (dimmed, no tap) when
/// there's nothing to add (out of stock) or remove (qty already 0).
class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepBtn({
    required this.icon,
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
          //
          // AppColors.iconTint is a FIXED light tint in both themes (same
          // square used behind every product/cart icon app-wide) -- so the
          // icon on top must also use fixed colors, not palette.textPrimary
          // (which turns near-white in dark mode and disappears against
          // this always-light fill). Matches the accent-icon-on-iconTint
          // pattern already used everywhere else (Products list, Chat,
          // Notifications, etc.).
          color: AppColors.iconTint,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: enabled ? AppColors.accent : AppColors.border, width: enabled ? 1.4 : 1),
        ),
        child: Icon(
          icon,
          size: 15,
          color: enabled ? AppColors.accent : AppColors.textSecondary.withOpacity(0.4),
        ),
      ),
    );
  }
}

/// One cart line -- a +/- stepper (`_StepBtn`) changes quantity by
/// growing or shrinking the line's slots (see CartUnitSlot), the
/// trash icon removes the whole line, and the "Remove qty" row below
/// offers quick -1/-2/Delete-all shortcuts for correcting a miscount
/// without tapping the stepper repeatedly. Per-unit barcode status
/// for this line's slots lives separately, in the ITEM BARCODES
/// checklist below the cart -- this card is quantity only.
/// Fades + grows a cart line in the moment it's first added to the
/// tree -- keyed by productId (see the call site above) so a brand
/// new line animates in while an existing line that just changed qty
/// rebuilds in place with no animation (same element, same key).
class _CartLineAnimated extends StatefulWidget {
  final Widget child;
  const _CartLineAnimated({super.key, required this.child});

  @override
  State<_CartLineAnimated> createState() => _CartLineAnimatedState();
}

class _CartLineAnimatedState extends State<_CartLineAnimated> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 260))..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SizeTransition(sizeFactor: curved, axisAlignment: -1, child: widget.child),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final AppPalette palette;
  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final ValueChanged<int> onQuickRemove;
  final VoidCallback onRemove;

  const _CartItemCard({
    required this.palette,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onQuickRemove,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.iconTint, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.smartphone_rounded, size: 20, color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      '${_priceFormat.format(item.price)} each · ${_priceFormat.format(item.lineTotal)}',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  child: Icon(Icons.delete_outline_rounded, size: 18, color: palette.textSecondary),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StepBtn(icon: Icons.remove_rounded, enabled: item.qty > 0, onTap: onDecrement),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${item.qty}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: palette.textPrimary),
                    ),
                  ),
                  _StepBtn(
                    icon: Icons.add_rounded,
                    enabled: item.qty < item.availableStock,
                    onTap: onIncrement,
                  ),
                ],
              ),
            ],
          ),
          if (item.qty > 1) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Remove qty:', style: TextStyle(fontSize: 11, color: palette.textSecondary)),
                const SizedBox(width: 6),
                _QuickChip(label: '−1', onTap: () => onQuickRemove(1)),
                if (item.qty > 2) ...[
                  const SizedBox(width: 6),
                  _QuickChip(label: '−2', onTap: () => onQuickRemove(2)),
                ],
                const SizedBox(width: 6),
                _QuickChip(label: 'Delete all ${item.qty}', onTap: onRemove),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One row in the ITEM BARCODES checklist -- one physical unit of one
/// cart line. A verified slot just shows its confirmed code and a
/// green border; a pending slot additionally offers an inline text
/// field (type the barcode printed on the item/box) and a Scan
/// button (camera), either of which hands the raw code to the same
/// shared [_SalesViewState._resolveBarcode] lookup via [onType]/
/// [onScan]. Its own StatefulWidget (not inline) so the
/// TextEditingController survives the list rebuilding around it
/// every time any slot anywhere in the cart changes.
class _BarcodeSlotRow extends StatefulWidget {
  final AppPalette palette;
  final String productName;
  final String hintBarcode;
  final int slotNumber;
  final int slotCount;
  final CartUnitSlot slot;
  final bool isBulkSummary;
  final VoidCallback onScan;
  final ValueChanged<String> onType;
  final VoidCallback? onRemove;

  const _BarcodeSlotRow({
    required this.palette,
    required this.productName,
    required this.hintBarcode,
    required this.slotNumber,
    required this.slotCount,
    required this.slot,
    this.isBulkSummary = false,
    required this.onScan,
    required this.onType,
    this.onRemove,
  });

  @override
  State<_BarcodeSlotRow> createState() => _BarcodeSlotRowState();
}

class _BarcodeSlotRowState extends State<_BarcodeSlotRow> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    widget.onType(code);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final verified = widget.slot.isVerified;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: verified ? AppColors.success.withOpacity(0.4) : p.border,
          width: verified ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.isBulkSummary
                      ? '${widget.productName} × ${widget.slotCount}'
                      : '${widget.productName} · Unit ${widget.slotNumber}/${widget.slotCount}',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Container(
                  key: ValueKey(verified),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: verified ? AppColors.success.withOpacity(0.12) : AppColors.warningText.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (verified) ...[
                        const Icon(Icons.check_circle_rounded, size: 11, color: AppColors.success),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        verified ? 'Verified' : 'Pending',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: verified ? AppColors.success : AppColors.warningText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.onRemove != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onRemove,
                  child: Text('Remove', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.textSecondary)),
                ),
              ],
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(sizeFactor: animation, axisAlignment: -1, child: child),
            ),
            child: verified
                ? Column(
                    key: const ValueKey('verified'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 4),
                      Text(widget.slot.barcode!, style: TextStyle(fontSize: 11.5, color: p.textSecondary)),
                    ],
                  )
                : Column(
                    key: const ValueKey('pending'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              style: TextStyle(fontSize: 13, color: p.textPrimary),
                              onSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: widget.hintBarcode.isNotEmpty ? 'Type barcode (e.g. ${widget.hintBarcode})' : 'Type barcode',
                                hintStyle: TextStyle(fontSize: 12, color: p.textSecondary),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: p.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: p.border)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.accent)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _submit,
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.accent, width: 1.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: widget.onScan,
                            child: Container(
                              height: 36,
                              width: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Small pill-shaped quick-action chip -- "Remove qty: -1 -2 Delete
/// all N" under a cart line with more than one unit.
class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.iconTint,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent)),
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

/// A final itemized review shown before a sale actually submits --
/// "audit" styled rather than a bare "are you sure": the customer,
/// the pre-selected payment method, every cart line with its
/// confirmed barcode(s), and the payable total, all laid out so the
/// cashier can visually cross-check the whole sale in one glance
/// before it becomes final. The button itself is already disabled
/// unless every barcode is verified, so nothing here is a new
/// validation -- it's a visible, line-by-line proof of a fact that's
/// already true.
class _CompleteSaleConfirmSheet extends StatelessWidget {
  final SalesState state;

  const _CompleteSaleConfirmSheet({required this.state});

  /// Shows the sheet and resolves to true only if "Confirm Sale" was
  /// tapped -- tapping "Edit Barcodes / Cart", the scrim, or swiping
  /// the sheet down all resolve to false.
  static Future<bool> show(BuildContext context, SalesState state) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CompleteSaleConfirmSheet(state: state),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final customer = state.selectedCustomer;
    final customerName = (customer != null && customer.name.trim().isNotEmpty) ? customer.name.trim() : 'Walk-in Customer';
    final customerPhone = customer?.phone.trim() ?? '';
    final String paymentLabel;
    final IconData paymentIcon;
    switch (state.paymentMethod) {
      case PaymentMethod.upi:
        paymentLabel = 'UPI / QR';
        paymentIcon = Icons.qr_code_rounded;
        break;
      case PaymentMethod.card:
        paymentLabel = 'Card';
        paymentIcon = Icons.credit_card_rounded;
        break;
      case PaymentMethod.cash:
        paymentLabel = 'Cash';
        paymentIcon = Icons.currency_rupee_rounded;
        break;
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(color: p.divider, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              alignment: Alignment.center,
              child: const Icon(Icons.verified_user_rounded, size: 24, color: AppColors.success),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(999)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 5, height: 5, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(
                    'ALL BARCODES VERIFIED',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.success, letterSpacing: 0.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text('Final Verification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.textPrimary)),
            const SizedBox(height: 4),
            Text(
              'Review ${state.itemCount} unit barcode${state.itemCount == 1 ? '' : 's'} before billing',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: p.textSecondary),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: p.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.border)),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(color: AppColors.iconTint, shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Icon(Icons.person_outline_rounded, size: 17, color: AppColors.accent),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(customerName, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.textPrimary)),
                                if (customerPhone.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(customerPhone, style: TextStyle(fontSize: 11.5, color: p.textSecondary)),
                                ],
                              ],
                            ),
                          ),
                          _AuditBadge(
                            label: customer != null ? 'Selected' : 'Walk-in',
                            color: customer != null ? AppColors.success : AppColors.neutralText,
                            bg: customer != null ? AppColors.successBg : AppColors.neutralBg,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'PAYMENT METHOD',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: p.textSecondary, letterSpacing: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(color: p.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.border)),
                      child: Row(
                        children: [
                          Icon(paymentIcon, size: 16, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Text(paymentLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.textPrimary)),
                          const SizedBox(width: 6),
                          Text('(Pre-selected)', style: TextStyle(fontSize: 11, color: p.textSecondary)),
                          const Spacer(),
                          const _AuditBadge(label: 'Ready', color: AppColors.success, bg: AppColors.successBg),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'ITEMIZED AUDIT • ${state.cartItems.length} PRODUCT${state.cartItems.length == 1 ? '' : 'S'} (${state.itemCount} UNIT${state.itemCount == 1 ? '' : 'S'})',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: p.textSecondary, letterSpacing: 0.4),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 13, color: AppColors.success),
                            const SizedBox(width: 3),
                            Text('100% Match', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final item in state.cartItems) ...[
                      _AuditItemCard(item: item, palette: p),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: p.background, borderRadius: BorderRadius.circular(14)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('PAYABLE TOTAL', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: p.textSecondary, letterSpacing: 0.5)),
                            const SizedBox(width: 8),
                            Text('Inc. ${_priceFormat.format(state.tax)} GST', style: TextStyle(fontSize: 10.5, color: p.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(_priceFormat.format(state.total), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: p.textPrimary)),
                            const SizedBox(width: 6),
                            Text(
                              'for ${state.itemCount} item${state.itemCount == 1 ? '' : 's'}',
                              style: TextStyle(fontSize: 11.5, color: p.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Icon(Icons.bolt_rounded, size: 15, color: AppColors.success),
                      const SizedBox(height: 2),
                      Text(
                        'Instant Receipt\nReady',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.success, height: 1.25),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(true),
              child: Container(
                width: double.infinity,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.accent, AppColors.purple]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 17, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text('Confirm Sale', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.white)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(false),
              child: Text(
                'Edit Barcodes / Cart',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small pill used across the Complete Sale review sheet -- "Selected"
/// / "Walk-in" on the customer row, "Ready" on the payment row.
class _AuditBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _AuditBadge({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// One product's audit row inside the Complete Sale review sheet --
/// name, a quantity badge, the line total/unit price, and a wrap of
/// barcode chips underneath. A unique-tracked item (CartItem
/// .tracksUniqueUnits == true) shows one chip per physical unit, each
/// carrying its own distinct confirmed code; a bulk item (every unit
/// on the line shares one printed barcode, e.g. a stack of the same
/// book) shows a SINGLE chip with a "xN" suffix instead of N identical
/// chips -- mirrors exactly how the ITEM BARCODES checklist above
/// already collapses a bulk line to one row.
class _AuditItemCard extends StatelessWidget {
  final CartItem item;
  final AppPalette palette;

  const _AuditItemCard({required this.item, required this.palette});

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final codes = item.unitBarcodes;
    final chips = <Widget>[];
    if (item.tracksUniqueUnits) {
      for (var i = 0; i < codes.length; i++) {
        chips.add(_BarcodeChip(label: '${codes[i]} #${i + 1}'));
      }
    } else if (codes.isNotEmpty) {
      chips.add(_BarcodeChip(label: '${codes.first} ×${item.qty}'));
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.purpleBg, borderRadius: BorderRadius.circular(999)),
                      child: Text('${item.qty}×', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.purple)),
                    ),
                  ],
                ),
              ),
              Text(_priceFormat.format(item.lineTotal), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: p.textPrimary)),
              const SizedBox(width: 4),
              Text('(${_priceFormat.format(item.price)} ea)', style: TextStyle(fontSize: 10.5, color: p.textSecondary)),
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: chips),
          ],
        ],
      ),
    );
  }
}

/// One confirmed-barcode pill inside an _AuditItemCard.
class _BarcodeChip extends StatelessWidget {
  final String label;

  const _BarcodeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 11, color: AppColors.success),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.success)),
        ],
      ),
    );
  }
}

/// Shows the brief post-sale success overlay and resolves once it has
/// closed itself (see _SaleSuccessOverlayState.initState) -- the
/// caller awaits this and only then navigates to the dashboard, so
/// the cashier actually sees "it worked" register before the screen
/// changes under them.
Future<void> _showSaleSuccessOverlay(BuildContext context, double total) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, __) => _SaleSuccessOverlay(total: total),
    transitionBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
  );
}

/// A brief full-screen "it worked" moment -- a checkmark that pops in
/// with a slight overshoot, held for a beat, then closes itself.
/// Replaces what used to be an instant SnackBar + immediate navigate,
/// which gave Complete Sale no visible moment of its own.
class _SaleSuccessOverlay extends StatefulWidget {
  final double total;
  const _SaleSuccessOverlay({required this.total});

  @override
  State<_SaleSuccessOverlay> createState() => _SaleSuccessOverlayState();
}

class _SaleSuccessOverlayState extends State<_SaleSuccessOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Icon(Icons.check_rounded, size: 34, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Text('Sale Completed', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: p.textPrimary)),
              const SizedBox(height: 4),
              Text(_priceFormat.format(widget.total), style: TextStyle(fontSize: 13.5, color: p.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}


