import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

/// The 5-tab bottom bar shared by Dashboard, Sales, Service, Products
/// and Profile (matches the CellPoint design — flat icon+label tabs
/// with a raised, floating Home button in the center).
///
/// Drop this into any of those screens' Scaffold as
/// `bottomNavigationBar: AppBottomNav(current: AppTab.dashboard)`.
///
/// Theme: reads `Theme.of(context).brightness` and switches its own
/// palette between AppColors' light/dark constants. The app itself
/// only has a light ThemeData today (see app_theme.dart) — adding a
/// real `darkTheme:` + `themeMode:` to MobileShopApp is separate,
/// still-pending work ("2 themes" in the project's TODO list). Until
/// that lands this bar will always render in light mode; the dark
/// branch below is ready and waiting for it.
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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 72,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: borderColor)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.5 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.bolt_rounded,
                label: 'Service',
                isActive: current == AppTab.service,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => _go(context, AppRoutes.service),
              ),
              _NavItem(
                icon: Icons.trending_up_rounded,
                label: 'Sales',
                isActive: current == AppTab.sales,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                badgeCount: salesBadgeCount,
                onTap: () => _go(context, AppRoutes.sales),
              ),
              // Reserved gap the floating Home button sits above —
              // "HOME" label lives here so it lines up with the row.
              const SizedBox(width: 30, child: _HomeLabel()),
              _NavItem(
                icon: Icons.inventory_2_outlined,
                label: 'Products',
                isActive: current == AppTab.products,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => _go(context, AppRoutes.products),
              ),
              _NavItem(
                icon: Icons.person_outline,
                label: 'Profile',
                isActive: current == AppTab.profile,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => _go(context, AppRoutes.profile),
              ),
            ],
          ),
        ),
        Positioned(
          top: -22,
          left: 0,
          right: 0,
          child: Center(
            child: _HomeButton(
              isDark: isDark,
              onTap: () => _go(context, AppRoutes.dashboard),
            ),
          ),
        ),
      ],
    );
  }

  void _go(BuildContext context, String route) {
    if (ModalRoute.of(context)?.settings.name == route) return;
    Navigator.of(context).pushReplacementNamed(route);
  }
}

/// The raised circular Home button — deliberately always styled as
/// "on" (solid accent + shadow/glow) rather than toggling with
/// `current`, same as the reference design: it reads as a permanent
/// shortcut back to Dashboard, not just another tab.
class _HomeButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _HomeButton({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? AppColors.darkCard : AppColors.card,
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? AppColors.accentGlow : AppColors.accent).withOpacity(isDark ? 0.55 : 0.35),
              blurRadius: isDark ? 24 : 14,
              spreadRadius: isDark ? 2 : 0,
            ),
          ],
        ),
        child: const Icon(Icons.home_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}

/// "HOME" text under the floating button, kept as its own tiny widget
/// so it can sit in the Row at the same baseline as the other labels.
class _HomeLabel extends StatelessWidget {
  const _HomeLabel();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Text(
        'HOME',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: isDark ? Colors.white : AppColors.accent,
        ),
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
  final VoidCallback onTap;
  final int? badgeCount;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : inactiveColor;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 22, color: color),
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
            if (isActive) ...[
              const SizedBox(height: 3),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(color: activeColor, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
