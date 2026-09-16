import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_bottom_nav.dart';

/// Products — matches the design canvas exactly: search bar (visual only),
/// All / Smartphones / Accessories category pills, product cards with a
/// stock badge, and a floating "+" that opens Add Product. Static reference
/// data; category filter is local widget state, no ProductsBloc yet.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

enum _ProductCat { phone, accessory }

class _ProductsScreenState extends State<ProductsScreen> {
  String _cat = 'all'; // 'all' | 'phone' | 'accessory'

  static const List<_ProductData> _products = [
    _ProductData(
      name: 'iPhone 14',
      spec: '128GB · Midnight',
      price: '₹68,999',
      stockLabel: 'In Stock',
      cat: _ProductCat.phone,
    ),
    _ProductData(
      name: 'Galaxy A54',
      spec: '256GB · Awesome Lime',
      price: '₹31,499',
      stockLabel: 'Low Stock',
      cat: _ProductCat.phone,
    ),
    _ProductData(
      name: 'Tempered Glass Pro',
      spec: 'Universal · Clear',
      price: '₹399',
      stockLabel: 'In Stock',
      cat: _ProductCat.accessory,
    ),
    _ProductData(
      name: 'OnePlus Nord CE4',
      spec: '128GB · Dark Chrome',
      price: '₹24,999',
      stockLabel: 'Out of Stock',
      cat: _ProductCat.phone,
    ),
    _ProductData(
      name: '20W Fast Charger',
      spec: 'Type-C · White',
      price: '₹1,199',
      stockLabel: 'In Stock',
      cat: _ProductCat.accessory,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final products = _cat == 'all'
        ? _products
        : _products.where((x) => x.cat.name == _cat).toList();

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Products',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: p.textPrimary,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _comingSoon(context, 'Filters'),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: p.card,
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(color: p.border),
                              ),
                              child: Icon(Icons.filter_list_rounded, size: 18, color: p.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: p.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded, size: 18, color: p.textSecondary),
                            const SizedBox(width: 9),
                            Text(
                              'Search products, SKU or brand',
                              style: TextStyle(fontSize: 13.5, color: p.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 34,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _FilterPill(
                              palette: p,
                              label: 'All',
                              selected: _cat == 'all',
                              onTap: () => setState(() => _cat = 'all'),
                            ),
                            const SizedBox(width: 8),
                            _FilterPill(
                              palette: p,
                              label: 'Smartphones',
                              selected: _cat == 'phone',
                              onTap: () => setState(() => _cat = 'phone'),
                            ),
                            const SizedBox(width: 8),
                            _FilterPill(
                              palette: p,
                              label: 'Accessories',
                              selected: _cat == 'accessory',
                              onTap: () => setState(() => _cat = 'accessory'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: products.isEmpty
                      ? Center(
                          child: Text(
                            'No products in this category',
                            style: TextStyle(color: p.textSecondary, fontSize: 14),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 100),
                          itemCount: products.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => _ProductCard(palette: p, product: products[i]),
                        ),
                ),
              ],
            ),
            Positioned(
              right: 20,
              bottom: 20,
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.addProduct),
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.products),
    );
  }
}

void _comingSoon(BuildContext context, String label) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$label — coming soon')),
  );
}

class _ProductData {
  final String name;
  final String spec;
  final String price;
  final String stockLabel; // 'In Stock' | 'Low Stock' | 'Out of Stock'
  final _ProductCat cat;

  const _ProductData({
    required this.name,
    required this.spec,
    required this.price,
    required this.stockLabel,
    required this.cat,
  });
}

class _FilterPill extends StatelessWidget {
  final AppPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : palette.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.accent : palette.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : palette.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _StockStyle {
  final Color bg;
  final Color fg;
  const _StockStyle(this.bg, this.fg);
}

class _ProductCard extends StatelessWidget {
  final AppPalette palette;
  final _ProductData product;

  const _ProductCard({required this.palette, required this.product});

  _StockStyle get _stockStyle {
    switch (product.stockLabel) {
      case 'Low Stock':
        return _StockStyle(AppColors.warningBg, AppColors.warningText);
      case 'Out of Stock':
        return _StockStyle(AppColors.dangerBg, AppColors.danger);
      default: // In Stock
        return _StockStyle(AppColors.successBg, AppColors.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _stockStyle;
    return GestureDetector(
      onTap: () => _comingSoon(context, product.name),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.iconTint,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                product.cat == _ProductCat.phone
                    ? Icons.smartphone_rounded
                    : Icons.shopping_bag_outlined,
                size: 24,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    product.spec,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: palette.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.price,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: palette.textPrimary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    product.stockLabel,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: s.fg),
                  ),
                ),
                const SizedBox(height: 10),
                Icon(Icons.chevron_right_rounded, size: 18, color: palette.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
