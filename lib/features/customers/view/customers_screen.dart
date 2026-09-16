import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';

/// Placeholder — customer list with search.
class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(title: const Text('Customers')),
      body: Center(
        child: Text(
          'Customers list\n(build next)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.textPrimary),
        ),
      ),
    );
  }
}
