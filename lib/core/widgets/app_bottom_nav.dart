import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

/// The 5-tab bottom bar shared by Dashboard, Sales, Service, Products
/// and Profile — a floating rounded pill with 5 equal-weight tabs.
/// Home used to be a separate raised circular button above the bar;
/// redesigned so all 5 tabs sit flat in one row, and whichever one is
/// active gets a soft rounded-chip highlight instead.
///
/// Drop this into any of those screens' Scaffold as
/// `bottomNavigationBar: AppBottomNav(current: AppTab.dashboard)`.
///
/// Tap feedback: intentionally NONE — see the git history on this file
/// for why (Material's default ripple and an AnimatedScale press both
/// read as an unwanted "vibrate"). Tapping a tab just changes screens;
/// the only visual feedback is the resulting active-chip appearing.
///
/// Theme: reads `Theme.of(context).brightness` and switches its own
/// palette between AppColors' light/dark constants. The app itself
/// only has a light ThemeData today — the dark branch is ready and
/// waiting for the app-wide dark theme to land.
enum AppTab { dashboard, sales, service, products, profile }

class AppBottomNav extends StatelessWidget {
  final AppTab current;

  /// Small red counter badge on the Sales icon (e.g. items in an open
  /// cart). Null/0 hides it. No screen wires this yet — sales_screen
  /// is still a placeholder — so it's left null everywhere for now.
  final int? salesBadgeCount;

  const AppBottomNav({super.key, required this.current, this.salesBadgeCount});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final barColor = isDark ? AppColors.darkCard : AppColors.card;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final inactiveColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final activeColor = isDark ? AppColors.activeDark : AppColors.accent;
    final activeBg = isDark ? AppColors.activeDark.withOpacity(0.16) : AppColors.iconTint;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: barColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.5 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            _NavItem(
              icon: Icons.handyman_rounded,
              label: 'Service',
              isActive: current == AppTab.service,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
              activeBg: activeBg,
              onTap: () => _go(context, AppRoutes.service),
            ),
            _NavItem(
              icon: Icons.trending_up_rounded,
              label: 'Sales',
              isActive: current == AppTab.sales,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
              activeBg: activeBg,
              badgeCount: salesBadgeCount,
              onTap: () => _go(context, AppRoutes.sales),
            ),
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              isActive: current == AppTab.dashboard,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
              activeBg: activeBg,
              onTap: () => _go(context, AppRoutes.dashboard),
            ),
            _NavItem(
              icon: Icons.inventory_2_outlined,
              label: 'Products',
              isActive: current == AppTab.products,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
              activeBg: activeBg,
              onTap: () => _go(context, AppRoutes.products),
            ),
            _NavItem(
              icon: Icons.manage_accounts_rounded,
              label: 'Profile',
              isActive: current == AppTab.profile,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
              activeBg: activeBg,
              onTap: () => _go(context, AppRoutes.profile),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, String route) {
    if (ModalRoute.of(context)?.settings.name == route) return;
    final builder = AppRoutes.routes[route];
    if (builder == null) return;
    // Not pushReplacementNamed: that builds a default MaterialPageRoute,
    // whose platform slide-transition animates the WHOLE new screen in
    // from the right — bottom bar included, since the bar lives inside
    // each screen's Scaffold. That's the "bar moves right to left" the
    // client flagged. A zero-duration PageRouteBuilder swaps instantly
    // instead — no slide, so the bar doesn't visibly move at all.
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        settings: RouteSettings(name: route),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final Color activeBg;
  final VoidCallback onTap;
  final int? badgeCount;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.activeBg,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : inactiveColor;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 21, color: color),
                  if (badgeCount != null && badgeCount! > 0)
                    Positioned(
                      top: -6,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        child: Text(
                          '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: color,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
