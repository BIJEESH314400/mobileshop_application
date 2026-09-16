import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';

/// Placeholder — sales trend chart, top products, payment breakdown.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(title: const Text('Reports')),
      body: Center(
        child: Text(
          'Reports\n(build next)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.textPrimary),
        ),
      ),
    );
  }
}
