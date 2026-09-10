import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Placeholder — the Add Product form (name, category, price, stock,
/// SKU/IMEI, condition, description).
class AddProductScreen extends StatelessWidget {
  const AddProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Product')),
      body: const Center(
        child: Text(
          'Add Product form\n(build next)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
