import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Placeholder — customer list with search.
class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: const Center(
        child: Text(
          'Customers list\n(build next)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
