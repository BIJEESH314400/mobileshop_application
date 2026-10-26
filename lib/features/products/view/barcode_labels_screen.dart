import 'package:flutter/material.dart';
import '../../../core/constants/shop_constants.dart';
import '../../../core/models/product.dart';
import '../../../core/repositories/product_repository.dart';
import '../../../core/repositories/product_unit_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../utils/barcode_label_pdf.dart';
import 'barcode_labels_preview_screen.dart';

/// Pick how many barcode stickers to print for each product, then
/// generate one combined PDF (a grid of labels, ready to cut) and open
/// it in an in-app preview (`BarcodeLabelsPreviewScreen`) before
/// printing or sharing -- unlike Sales History/Reports exports, which
/// go straight to the OS share sheet, the client's requirements doc
/// specifically asked for a look-before-you-print step here.
///
/// Products saved before this feature existed -- and not re-opened
/// since -- don't have a barcode yet, so they can't be printed from
/// here. Opening that product and tapping Save once generates one for
/// it automatically, even without touching the Barcode field.
class BarcodeLabelsScreen extends StatefulWidget {
  const BarcodeLabelsScreen({super.key});

  @override
  State<BarcodeLabelsScreen> createState() => _BarcodeLabelsScreenState();
}

class _BarcodeLabelsScreenState extends State<BarcodeLabelsScreen> {
  final _repository = ProductRepository();
  final _unitRepository = ProductUnitRepository();

  // productId -> how many labels for it. Products at 0 (the default)
  // just aren't in this map -- keeps "nothing selected yet" simple to
  // check and keeps the map from growing with a bunch of zero entries
  // as the owner taps + and - while deciding.
  final Map<String, int> _quantities = {};

  // productId -> whether this product's print run should mint one
  // individually-unique ProductUnit code per sticker instead of
  // printing the same product barcode on every copy. On by default for
  // a product that's never been touched here before -- most of what
  // gets printed here (phones) benefits from knowing exactly which
  // physical unit was sold, so the owner has to opt a product *out*
  // (toggle off) rather than remembering to opt every one in. A key
  // absent from this map just means "hasn't been tapped THIS time the
  // screen is open" -- every read below falls back to
  // `product.tracksUniqueUnits`, the product's own remembered setting
  // from the last time it was actually printed (defaulting to true for
  // a product that's never been printed with this toggle at all).
  final Map<String, bool> _uniquePerUnit = {};

  bool _generating = false;

  void _toggleUnique(Product product) {
    setState(() {
      _uniquePerUnit[product.id] = !(_uniquePerUnit[product.id] ?? product.tracksUniqueUnits);
    });
  }

  int get _totalLabels => _quantities.values.fold(0, (sum, q) => sum + q);

  void _setQty(String productId, int qty) {
    setState(() {
      if (qty <= 0) {
        _quantities.remove(productId);
      } else {
        _quantities[productId] = qty;
      }
    });
  }

  Future<void> _generate(List<Product> products) async {
    final selected = products.where((product) => (_quantities[product.id] ?? 0) > 0).toList();
    if (selected.isEmpty) return;

    setState(() => _generating = true);
    try {
      // Built with a plain for-loop rather than .map() because minting
      // unique unit codes for a toggled-on product is async (each one
      // is its own Firestore transaction -- see
      // ProductUnitRepository.generateUnits) and needs to finish before
      // the PDF below can know what each of that product's stickers
      // should show.
      final requests = <LabelRequest>[];
      for (final product in selected) {
        final qty = _quantities[product.id]!;
        final isUnique = _uniquePerUnit[product.id] ?? product.tracksUniqueUnits;

        // Remember this product's current toggle state for next time
        // this screen opens, regardless of which way it's set -- see
        // Product.tracksUniqueUnits' own doc comment for why this is
        // the one and only place that writes it.
        await _repository.setTracksUniqueUnits(product.id, isUnique);

        if (isUnique) {
          final units = await _unitRepository.generateUnits(
            shopId: currentShopId,
            productId: product.id,
            productName: product.name,
            category: product.category,
            brand: product.brand,
            count: qty,
          );
          requests.add(LabelRequest(
            product: product,
            quantity: qty,
            uniqueCodes: units.map((unit) => unit.code).toList(),
          ));
        } else {
          requests.add(LabelRequest(product: product, quantity: qty));
        }
      }

      final bytes = await buildBarcodeLabelsPdf(requests);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BarcodeLabelsPreviewScreen(bytes: bytes)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text("Couldn't generate the PDF. Please try again."),
            backgroundColor: AppColors.danger,
          ));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    // One subscription shared by the list and the bottom "Generate"
    // button, instead of each listening to its own copy of the same
    // stream.
    return StreamBuilder<List<Product>>(
      stream: _repository.watchProducts(shopId: currentShopId),
      builder: (context, snapshot) {
        final allProducts = snapshot.data ?? const <Product>[];
        // Out of stock means there's nothing to stick a label onto --
        // the qty dialog already caps at stockQty (so it would block
        // at 0 anyway), so just leave these off the list instead of
        // showing a product that can only ever error out when tapped.
        final products = allProducts.where((product) => product.stockQty > 0).toList();
        final outOfStockCount = allProducts.length - products.length;
        final loading = !snapshot.hasData;
        final total = _totalLabels;

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
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_back_rounded, size: 20, color: p.textPrimary),
                        const SizedBox(width: 14),
                        Text(
                          'Print Barcode Labels',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Text(
                    'Choose how many stickers to print for each product.',
                    style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                  ),
                ),
                if (!loading && outOfStockCount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                    child: Text(
                      '$outOfStockCount out of stock — hidden from this list',
                      style: TextStyle(fontSize: 11.5, color: p.textSecondary),
                    ),
                  ),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
                      : products.isEmpty
                          ? Center(
                              child: Text(
                                allProducts.isEmpty ? 'No products yet' : 'All products are out of stock',
                                style: TextStyle(color: p.textSecondary, fontSize: 14),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                              itemCount: products.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final product = products[i];
                                final hasBarcode = product.barcode.trim().isNotEmpty;
                                final qty = _quantities[product.id] ?? 0;
                                return Container(
                                  padding: const EdgeInsets.all(12),
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
                                              product.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.textPrimary),
                                            ),
                                            if (product.category.trim().isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                product.category,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.textSecondary),
                                              ),
                                            ],
                                            const SizedBox(height: 3),
                                            Text(
                                              hasBarcode ? product.barcode : 'No barcode yet — open & Save this product once',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: hasBarcode ? p.textSecondary : AppColors.danger,
                                              ),
                                            ),
                                            if (hasBarcode) ...[
                                              const SizedBox(height: 4),
                                              GestureDetector(
                                                onTap: () => _toggleUnique(product),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Transform.scale(
                                                      scale: 0.7,
                                                      child: Switch(
                                                        value: _uniquePerUnit[product.id] ?? product.tracksUniqueUnits,
                                                        onChanged: (_) => _toggleUnique(product),
                                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      ),
                                                    ),
                                                    Flexible(
                                                      child: Text(
                                                        'Unique code per sticker',
                                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.textSecondary),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      if (hasBarcode)
                                        _QtyStepper(
                                          productName: product.name,
                                          stockQty: product.stockQty,
                                          qty: qty,
                                          onChanged: (newQty) => _setQty(product.id, newQty),
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
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: GestureDetector(
              onTap: (_generating || total == 0) ? null : () => _generate(products),
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: total == 0 ? AppColors.accent.withOpacity(0.4) : AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _generating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                      )
                    : Text(
                        total == 0 ? 'Select quantities to print' : 'Generate PDF — $total label${total == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final String productName;
  final int stockQty;
  final int qty;
  final ValueChanged<int> onChanged;

  const _QtyStepper({required this.productName, required this.stockQty, required this.qty, required this.onChanged});

  /// Lets the owner type a count directly instead of tapping +/- one at
  /// a time -- handy for a big run (e.g. 50 stickers for a bulk
  /// shipment) where nudging would take forever. Same dialog look as
  /// Service Jobs' pickup-price confirm dialog.
  ///
  /// The TextEditingController lives inside `_QtyDialog` (a real
  /// StatefulWidget) instead of a local variable here. Disposing it
  /// manually right after `showDialog` returned used to race the
  /// dialog's own closing animation -- the TextField was still being
  /// rebuilt mid-transition against an already-disposed controller,
  /// which is what threw "TextEditingController used after being
  /// disposed" and then the "_dependents.isEmpty" crash on tapping Set
  /// Quantity. Letting State.dispose() free it, at the point the
  /// dialog element is actually removed, fixes that properly instead
  /// of just delaying the dispose call.
  Future<void> _editQty(BuildContext context) async {
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => _QtyDialog(productName: productName, stockQty: stockQty, initialQty: qty),
    );
    if (result != null) onChanged(result);
  }

  // No more +/- step buttons -- the user asked for a plain "QTY [box]"
  // look instead (reference screenshot), with the whole row tappable to
  // open the manual-entry dialog above. Quicker to scan down a long
  // product list, and typing is the only way to change a count now.
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return GestureDetector(
      onTap: () => _editQty(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'QTY',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.textSecondary, letterSpacing: 0.4),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 40),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.iconTint,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog content for `_QtyStepper._editQty`, split out into its own
/// StatefulWidget so its TextEditingController is created in
/// `initState` and freed in `dispose` -- tied to the dialog element's
/// real lifecycle instead of a manually-disposed local variable (see
/// the note on `_editQty` above).
class _QtyDialog extends StatefulWidget {
  final String productName;
  final int stockQty;
  final int initialQty;

  const _QtyDialog({required this.productName, required this.stockQty, required this.initialQty});

  @override
  State<_QtyDialog> createState() => _QtyDialogState();
}

class _QtyDialogState extends State<_QtyDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQty == 0 ? '' : '${widget.initialQty}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    final value = text.isEmpty ? 0 : int.tryParse(text);
    if (value == null || value < 0) {
      setState(() => _error = 'Enter a valid number');
      return;
    }
    if (value > widget.stockQty) {
      setState(() => _error = 'Only ${widget.stockQty} in stock — can\'t print more than that');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Dialog(
      backgroundColor: p.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How many stickers?', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: p.textPrimary)),
            const SizedBox(height: 6),
            Text(
              widget.productName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: p.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'In stock: ${widget.stockQty}',
              style: TextStyle(fontSize: 11.5, color: p.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: p.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _error != null ? AppColors.danger : p.border),
              ),
              child: TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary),
                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 12)),
                onSubmitted: (_) => _submit(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: p.border)),
                      child: Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.textPrimary)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _submit,
                    child: Container(
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                      child: const Text('Set Quantity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
