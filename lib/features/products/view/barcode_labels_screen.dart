import 'package:flutter/material.dart';
import '../../../core/constants/shop_constants.dart';
import '../../../core/models/product.dart';
import '../../../core/repositories/product_repository.dart';
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

  // productId -> how many labels for it. Products at 0 (the default)
  // just aren't in this map -- keeps "nothing selected yet" simple to
  // check and keeps the map from growing with a bunch of zero entries
  // as the owner taps + and - while deciding.
  final Map<String, int> _quantities = {};

  bool _generating = false;

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
    final requests = products
        .where((product) => (_quantities[product.id] ?? 0) > 0)
        .map((product) => LabelRequest(product: product, quantity: _quantities[product.id]!))
        .toList();
    if (requests.isEmpty) return;

    setState(() => _generating = true);
    try {
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
        final products = snapshot.data ?? const <Product>[];
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
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
                      : products.isEmpty
                          ? Center(
                              child: Text('No products yet', style: TextStyle(color: p.textSecondary, fontSize: 14)),
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
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      if (hasBarcode)
                                        _QtyStepper(
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
  final int qty;
  final ValueChanged<int> onChanged;

  const _QtyStepper({required this.qty, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(icon: Icons.remove_rounded, onTap: qty > 0 ? () => onChanged(qty - 1) : null),
        SizedBox(
          width: 28,
          child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        _StepButton(icon: Icons.add_rounded, onTap: () => onChanged(qty + 1)),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onTap == null ? AppColors.iconTint.withOpacity(0.5) : AppColors.iconTint,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: onTap == null ? AppColors.accent.withOpacity(0.4) : AppColors.accent),
      ),
    );
  }
}
