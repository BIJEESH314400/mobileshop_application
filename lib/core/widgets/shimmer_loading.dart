import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

/// Shared shimmer "skeleton" loading primitives -- used on the
/// screens that wait on a live Firestore snapshot for a *list or
/// grid* of content (Products, Customers, Sales History, Dashboard
/// stat tiles, Reports): a greyed-out shape of what's coming, with a
/// soft light sweep across it, instead of a bare spinner. Deliberately
/// NOT used for one-off actions (login, Complete Sale, a save) -- a
/// fake skeleton for something that resolves in under a second just
/// reads as flicker, so those keep their plain spinner.
///
/// Colors come from AppPalette so the sweep looks right in both light
/// and dark theme, same as everywhere else in the app.

/// One flat placeholder rectangle -- the basic building block every
/// skeleton shape below is made of.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: Colors.white, borderRadius: borderRadius),
    );
  }
}

/// Wraps any skeleton shape in the actual shimmer sweep animation.
/// Every skeleton widget below already includes this -- only needed
/// directly when composing a custom skeleton layout (see Reports'
/// loading branch for an example).
class ShimmerWrap extends StatelessWidget {
  final Widget child;
  const ShimmerWrap({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Shimmer.fromColors(
      baseColor: p.isDark ? AppColors.darkBorder : AppColors.border,
      highlightColor: p.isDark ? AppColors.darkCard : Colors.white,
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// One skeleton row matching this app's common list-card shape --
/// leading icon square, two text bars, a trailing badge bar. Stands
/// in for Products' _ProductCard, Customers' _CustomerRow, and Sales
/// History's _SaleGroupCard while their first snapshot loads.
class ShimmerListRow extends StatelessWidget {
  const ShimmerListRow({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          const ShimmerBox(width: 44, height: 44, borderRadius: BorderRadius.all(Radius.circular(12))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: double.infinity, height: 13),
                SizedBox(height: 8),
                ShimmerBox(width: 120, height: 11),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const ShimmerBox(width: 54, height: 22, borderRadius: BorderRadius.all(Radius.circular(999))),
        ],
      ),
    );
  }
}

/// A full list-screen skeleton -- N ShimmerListRows with the same
/// outer padding/spacing as the real ListView.separated it stands in
/// for, all swept by one shared shimmer animation.
class ShimmerListSkeleton extends StatelessWidget {
  final int count;
  final EdgeInsetsGeometry padding;

  const ShimmerListSkeleton({
    super.key,
    this.count = 6,
    this.padding = const EdgeInsets.fromLTRB(20, 6, 20, 100),
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => const ShimmerListRow(),
      ),
    );
  }
}

/// A single skeleton stat tile -- matches the rough proportions every
/// stat card/tile in this app shares (a label bar, a big value bar,
/// a trend/footer bar).
class ShimmerStatTile extends StatelessWidget {
  final double height;
  const ShimmerStatTile({super.key, this.height = 92});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          ShimmerBox(width: 70, height: 11),
          ShimmerBox(width: 90, height: 19),
          ShimmerBox(width: 110, height: 10),
        ],
      ),
    );
  }
}

/// 2x2 stat grid skeleton -- Dashboard's 4 _StatCards while any of
/// the blocs feeding them (sales/service/products) is still on its
/// first snapshot.
class ShimmerStatGrid extends StatelessWidget {
  const ShimmerStatGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: const [ShimmerStatTile(), ShimmerStatTile(), ShimmerStatTile(), ShimmerStatTile()],
      ),
    );
  }
}

/// A row of N skeleton tiles -- Reports' _StatRow (Revenue / Orders /
/// Avg Order) while its first snapshot loads.
class ShimmerStatRow extends StatelessWidget {
  final int count;
  const ShimmerStatRow({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            const Expanded(child: ShimmerStatTile(height: 76)),
          ],
        ],
      ),
    );
  }
}
