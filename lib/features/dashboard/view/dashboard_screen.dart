import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_bottom_nav.dart';

/// Dashboard — matches the CellPoint design canvas (stat grid, quick
/// actions, recent sales, service queue). Purely visual for now: all
/// the numbers below are the same static reference data the design
/// itself uses. Wiring this to real data is a DashboardBloc/Repository
/// job for later — see the "Async data flow in Bloc" R&D topic.
///
/// Theme-aware via [AppPalette] (background/card/border/text colors
/// swap with light/dark). The accent-colored "Today's Sales" card and
/// the amber/green status badges (Low Stock, service-queue pills) stay
/// the same solid colors in both themes on purpose — that's a
/// deliberate simplification, not an oversight.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(palette: p),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatGrid(palette: p),
                    const SizedBox(height: 22),
                    _QuickActions(palette: p),
                    const SizedBox(height: 22),
                    _SectionList(
                      palette: p,
                      title: 'Recent sales',
                      viewAllRoute: AppRoutes.sales,
                      rows: const [
                        _ListRowData(
                          icon: Icons.smartphone_rounded,
                          iconBg: Color(0xFFF4F4FE),
                          iconColor: AppColors.accent,
                          title: 'iPhone 14 · 128GB',
                          subtitle: 'Rohan Kapoor · 10:24 AM',
                          trailing: '₹68,999',
                        ),
                        _ListRowData(
                          icon: Icons.shopping_bag_outlined,
                          iconBg: Color(0xFFF4F4FE),
                          iconColor: AppColors.accent,
                          title: 'Silicone Case + Glass',
                          subtitle: 'Neha Sharma · 9:52 AM',
                          trailing: '₹899',
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _SectionList(
                      palette: p,
                      title: 'Service queue',
                      viewAllRoute: AppRoutes.service,
                      rows: const [
                        _ListRowData(
                          icon: Icons.bolt_rounded,
                          iconBg: AppColors.warningBg,
                          iconColor: AppColors.warningText,
                          title: 'Screen replacement',
                          subtitle: 'OnePlus Nord · Priya M.',
                          badgeLabel: 'In Progress',
                          badgeColor: AppColors.warningText,
                          badgeBg: AppColors.warningBg,
                        ),
                        _ListRowData(
                          icon: Icons.bolt_rounded,
                          iconBg: AppColors.successBg,
                          iconColor: AppColors.success,
                          title: 'Battery replacement',
                          subtitle: 'iPhone 12 · Aman G.',
                          badgeLabel: 'Ready',
                          badgeColor: AppColors.success,
                          badgeBg: AppColors.successBg,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.dashboard),
    );
  }
}

class _Header extends StatelessWidget {
  final AppPalette palette;

  const _Header({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good morning, Arjun',
                style: TextStyle(fontSize: 13, color: palette.textSecondary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              Text(
                '4B Mobiles',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: palette.textPrimary),
              ),
            ],
          ),
          Row(
            children: [
              _IconButton(palette: palette, icon: Icons.search_rounded, onTap: () {}),
              const SizedBox(width: 10),
              _IconButton(palette: palette, icon: Icons.notifications_outlined, onTap: () {}, showDot: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  const _IconButton({required this.palette, required this.icon, required this.onTap, this.showDot = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Icon(icon, size: 18, color: palette.textPrimary),
          ),
          if (showDot)
            Positioned(
              top: 8,
              right: 9,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.card, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final AppPalette palette;

  const _StatGrid({required this.palette});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        const _StatCard(
          label: "Today's Sales",
          value: '₹42,500',
          labelColor: Colors.white70,
          valueColor: Colors.white,
          background: AppColors.accent,
          trend: '12% vs yesterday',
          trendColor: Color(0xFFB9F5CE),
          showTrendIcon: true,
        ),
        _StatCard(
          label: 'Orders Today',
          value: '18',
          labelColor: palette.textSecondary,
          valueColor: palette.textPrimary,
          background: palette.card,
          border: palette.border,
          trend: '4 pending pickup',
          trendColor: palette.textSecondary,
        ),
        _StatCard(
          label: 'Repairs Active',
          value: '5',
          labelColor: palette.textSecondary,
          valueColor: palette.textPrimary,
          background: palette.card,
          border: palette.border,
          trend: '2 ready for pickup',
          trendColor: palette.textSecondary,
        ),
        const _StatCard(
          label: 'Low Stock',
          value: '3 items',
          labelColor: AppColors.warningText,
          valueColor: AppColors.warningText,
          background: AppColors.warningBg,
          trend: 'Needs reorder',
          trendColor: AppColors.warningText,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;
  final Color background;
  final Color? border;
  final String trend;
  final Color trendColor;
  final bool showTrendIcon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
    required this.background,
    this.border,
    required this.trend,
    required this.trendColor,
    this.showTrendIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
          Text(value, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: valueColor)),
          Row(
            children: [
              if (showTrendIcon) ...[
                Icon(Icons.trending_up_rounded, size: 13, color: trendColor),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  trend,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: trendColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final AppPalette palette;

  const _QuickActions({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick actions', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: palette.textPrimary)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _QuickAction(
              palette: palette,
              icon: Icons.shopping_bag_outlined,
              label: 'New Sale',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.sales),
            ),
            _QuickAction(
              palette: palette,
              icon: Icons.inventory_2_outlined,
              label: 'Add Product',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.addProduct),
            ),
            _QuickAction(
              palette: palette,
              icon: Icons.bolt_rounded,
              label: 'New Repair',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.service),
            ),
            _QuickAction(
              palette: palette,
              icon: Icons.people_outline,
              label: 'Customers',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.customers),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.palette, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF0FE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 21, color: AppColors.accent),
          ),
          const SizedBox(height: 7),
          SizedBox(
            width: 68,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: palette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListRowData {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? trailing;
  final String? badgeLabel;
  final Color? badgeColor;
  final Color? badgeBg;

  const _ListRowData({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.badgeLabel,
    this.badgeColor,
    this.badgeBg,
  });
}

class _SectionList extends StatelessWidget {
  final AppPalette palette;
  final String title;
  final String viewAllRoute;
  final List<_ListRowData> rows;

  const _SectionList({required this.palette, required this.title, required this.viewAllRoute, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: palette.textPrimary)),
            GestureDetector(
              onTap: () => Navigator.of(context).pushNamed(viewAllRoute),
              child: const Text(
                'View all',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    border: i == rows.length - 1
                        ? null
                        : Border(bottom: BorderSide(color: palette.divider)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: rows[i].iconBg, borderRadius: BorderRadius.circular(11)),
                        child: Icon(rows[i].icon, size: 17, color: rows[i].iconColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rows[i].title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                            const SizedBox(height: 2),
                            Text(
                              rows[i].subtitle,
                              style: TextStyle(fontSize: 12, color: palette.textSecondary, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      if (rows[i].trailing != null)
                        Text(rows[i].trailing!, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                      if (rows[i].badgeLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(color: rows[i].badgeBg, borderRadius: BorderRadius.circular(999)),
                          child: Text(
                            rows[i].badgeLabel!,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: rows[i].badgeColor),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
