import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bottom_nav.dart';

/// Placeholder — the real Dashboard (stats, quick actions, recent
/// sales, service queue) is the next feature to build. This just
/// keeps the app runnable end-to-end after Login.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const SafeArea(
        child: Center(
          child: Text(
            'Dashboard\n(build next)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.dashboard),
    );
  }
}
