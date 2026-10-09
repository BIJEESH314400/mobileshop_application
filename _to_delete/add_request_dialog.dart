import 'package:flutter/material.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/repositories/product_request_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/app_logger.dart';

/// The one shared "Add Request" dialog -- same design everywhere a
/// request gets logged, so it doesn't matter which door someone comes
/// in through. Unified 2026-10-07 (previously the Sales out-of-stock
/// picker and the Waiting Customers screen each had their own,
/// slightly different dialog) after the owner pointed out there's no
/// reason for two different designs to do the same thing.
///
/// All fields stay editable regardless of entry point -- `productId`/
/// `initialItemName`/`initialCustomerName`/`initialCustomerPhone` are
/// just a head start when the caller already knows them (e.g. Sales
/// already knows which product and, maybe, which customer), not a
/// locked-in choice.
Future<void> showAddRequestDialog(
  BuildContext context, {
  String? productId,
  String initialItemName = '',
  String initialCustomerName = '',
  String initialCustomerPhone = '',
}) async {
  final p = AppPalette.of(context);
  final itemController = TextEditingController(text: initialItemName);
  final qtyController = TextEditingController(text: '1');
  final nameController = TextEditingController(text: initialCustomerName);
  final phoneController = TextEditingController(text: initialCustomerPhone);
  final noteController = TextEditingController();
  String? error;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Widget field(TextEditingController controller, String hint, {TextInputType? keyboardType, bool invalid = false}) {
            return TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: TextStyle(fontSize: 14, color: p.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: p.background,
                hintText: hint,
                hintStyle: TextStyle(fontSize: 13.5, color: p.textSecondary),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: invalid ? AppColors.danger : p.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: invalid ? AppColors.danger : p.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent)),
              ),
            );
          }

          return Dialog(
            backgroundColor: p.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add Request', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: p.textPrimary)),
                    const SizedBox(height: 6),
                    Text(
                      "What's the customer waiting for? No need to add it as a Product first.",
                      style: TextStyle(fontSize: 13, color: p.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    field(itemController, 'Item name (e.g. Titan Watch)', invalid: error != null),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 72, child: field(qtyController, 'Qty', keyboardType: TextInputType.number)),
                        const SizedBox(width: 10),
                        Expanded(child: field(nameController, 'Customer name', invalid: error != null)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    field(phoneController, 'Phone number (optional)', keyboardType: TextInputType.phone),
                    const SizedBox(height: 10),
                    field(noteController, 'Note (e.g. will check back in 3 days)'),
                    if (error != null) ...[
                      const SizedBox(height: 6),
                      Text(error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.of(dialogContext).pop(false),
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
                            onTap: () {
                              if (itemController.text.trim().isEmpty || nameController.text.trim().isEmpty) {
                                setDialogState(() => error = 'Enter the item and the customer\'s name');
                                return;
                              }
                              Navigator.of(dialogContext).pop(true);
                            },
                            child: Container(
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                              child: const Text('Save', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  if (confirmed != true || !context.mounted) return;

  final quantity = int.tryParse(qtyController.text.trim()) ?? 1;
  try {
    await ProductRequestRepository().addRequest(
      shopId: currentShopId,
      productId: productId,
      productName: itemController.text.trim(),
      quantity: quantity < 1 ? 1 : quantity,
      customerName: nameController.text.trim(),
      customerPhone: phoneController.text.trim(),
      note: noteController.text.trim(),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Request saved')));
  } catch (e, st) {
    AppLogger.error('showAddRequestDialog', e, st);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text("Couldn't save the request -- check your connection and try again")));
  }
}
