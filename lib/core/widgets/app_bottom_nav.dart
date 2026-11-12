import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

/// The 5-tab bottom bar shared by Dashboard, Sales, Service, Products
/// and Profile — a floating rounded pill with 4 flat tabs (Service,
/// Sales, Products, Profile) plus a raised circular Home button
/// poking up out of the middle, matching the client's reference
/// mockups. Whichever flat tab is active gets a soft rounded-chip
/// highlight; Home instead glows brighter while active, since it's
/// always filled solid rather than flat.
///
/// Drop this into any of those screens' Scaffold as
/// `bottomNavigationBar: AppBottomNav(current: AppTab.dashboard)`.
///
/// Tap feedback: intentionally NONE on the flat tabs — see the git
/// history on this file for why (Material's default ripple and an
/// AnimatedScale press both read as an unwanted "vibrate"). Tapping a
/// tab just changes screens; the only visual feedback is the
/// resulting active-chip (or, for Home, brighter glow) appearing.
///
/// Theme: reads `Theme.of(context).brightness` and switches its own
/// palette between AppColors' light/dark constants — this already
/// works today, since dark mode is wired app-wide via ThemeBloc
/// (see app.dart / app_theme.dart).
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
    // The Home button + active-tab highlight both use the user's
    // selected accent color in light AND dark mode (2026-10-29) --
    // this used to fall back to a fixed cyan in dark mode
    // (AppColors.activeDark), which silently ignored whichever of the
    // 6 themes was picked in Profile > App Theme. The rest of the
    // app's dark theme (app_theme.dart's buildAppDarkTheme) already
    // seeds its ColorScheme from AppColors.accent, so this brings the
    // bottom bar in line with that.
    final activeColor = AppColors.accent;
    final activeBg = isDark ? AppColors.accent.withOpacity(0.16) : AppColors.iconTint;

    // Android 15 (targeting SDK 35) stopped automatically reserving
    // space for the gesture-navigation bar/pill -- content now draws
    // edge-to-edge by default, so a fixed 12px bottom margin that used
    // to clear the system bar on older Android now sits the bar (and
    // this nav) right on top of the gesture pill. Adding the device's
    // own reported bottom inset keeps this floating above it on every
    // Android version, old 3-button nav bars included (inset is 0
    // there, so this is a no-op on those devices).
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
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
                // Home used to be a flat _NavItem here; it's now the
                // raised circular button floating above the bar (built
                // below), so this slot is just an empty spacer that
                // keeps the other 4 tabs evenly spaced either side of it.
                const Expanded(child: SizedBox.shrink()),
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
          Positioned(
            top: -14,
            child: _HomeButton(
              isActive: current == AppTab.dashboard,
              activeColor: activeColor,
              onTap: () => _go(context, AppRoutes.dashboard),
            ),
          ),
        ],
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

class _HomeButton extends StatelessWidget {
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _HomeButton({
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // No halo ring around this one (2026-10-29) -- an earlier version
    // wrapped it in a page-background-colored ring, which read as a
    // fully detached floating button with a visible gap under it.
    // The client's reference has Home sitting almost flush with the
    // bar, just bumping up out of it slightly -- achieved here with a
    // smaller circle (52px, was 60px) and a shallower poke (the
    // Positioned top offset above was taken from -22 to -14), so most
    // of the circle overlaps the bar itself instead of floating clear
    // above it.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: activeColor,
          boxShadow: [
            BoxShadow(
              color: activeColor.withOpacity(isActive ? 0.5 : 0.3),
              blurRadius: isActive ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.home_rounded, color: Colors.white, size: 24),
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
