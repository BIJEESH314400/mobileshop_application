import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/models/product.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import 'add_product_screen.dart';
import '../bloc/products_bloc.dart';
import '../bloc/products_event.dart';
import '../bloc/products_state.dart';

/// A product with 5 or fewer left is flagged "Low Stock" rather than
/// waiting until it's completely out — gives the owner a heads-up to
/// reorder before a customer asks for something that's sold out.
const int _lowStockThreshold = 5;

final _priceFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// Products — search bar (visual only) and category pills stay as in
/// the design canvas, but the list and the category pills themselves
/// now come from Firestore via ProductsBloc, live-updating whenever a
/// product is added/changed anywhere.
class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProductsBloc()..add(const ProductsSubscriptionRequested()),
      child: const _ProductsView(),
    );
  }
}

class _ProductsView extends StatefulWidget {
  const _ProductsView();

  @override
  State<_ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<_ProductsView> {
  // null = "All". Category pills are built from whatever categories
  // are actually present in the loaded products, so this list grows
  // on its own as new categories get used — no separate config needed.
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return BlocBuilder<ProductsBloc, ProductsState>(
      builder: (context, state) {
        final categories = state.products.map((product) => product.category).toSet().toList()..sort();
        final products = _selectedCategory == null
            ? state.products
            : state.products.where((product) => product.category == _selectedCategory).toList();

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
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.textPrimary),
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
                          if (categories.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 34,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _FilterPill(
                                    palette: p,
                                    label: 'All',
                                    selected: _selectedCategory == null,
                                    onTap: () => setState(() => _selectedCategory = null),
                                  ),
                                  for (final category in categories) ...[
                                    const SizedBox(width: 8),
                                    _FilterPill(
                                      palette: p,
                                      label: category,
                                      selected: _selectedCategory == category,
                                      onTap: () => setState(() => _selectedCategory = category),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(child: _buildBody(context, p, state, products)),
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
                          BoxShadow(color: AppColors.accent.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8)),
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
      },
    );
  }

  Widget _buildBody(BuildContext context, AppPalette p, ProductsState state, List<Product> products) {
    if (state.isLoading && state.products.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }

    if (state.errorMessage != null && state.products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: p.textSecondary, fontSize: 14)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.read<ProductsBloc>().add(const ProductsSubscriptionRequested()),
                child: const Text('Retry', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }

    if (products.isEmpty) {
      return Center(
        child: Text(
          state.products.isEmpty ? 'No products yet — tap + to add one' : 'No products in this category',
          style: TextStyle(color: p.textSecondary, fontSize: 14),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 100),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _ProductCard(palette: p, product: products[i]),
    );
  }
}

void _comingSoon(BuildContext context, String label) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$label — coming soon')),
  );
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
  final String label;
  const _StockStyle(this.bg, this.fg, this.label);
}

class _ProductCard extends StatelessWidget {
  final AppPalette palette;
  final Product product;

  const _ProductCard({required this.palette, required this.product});

  _StockStyle get _stockStyle {
    if (product.stockQty <= 0) {
      return const _StockStyle(AppColors.dangerBg, AppColors.danger, 'Out of Stock');
    }
    if (product.stockQty <= _lowStockThreshold) {
      return const _StockStyle(AppColors.warningBg, AppColors.warningText, 'Low Stock');
    }
    return const _StockStyle(AppColors.successBg, AppColors.success, 'In Stock');
  }

  @override
  Widget build(BuildContext context) {
    final s = _stockStyle;
    final spec = [product.brand, product.condition].where((part) => part.isNotEmpty).join(' · ');

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AddProductScreen(product: product)),
      ),
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
              // A single generic icon for every product — categories are
              // open-ended now (owner-managed via the picker), so there's
              // no fixed list to map onto specific icons.
              child: const Icon(Icons.inventory_2_outlined, size: 24, color: AppColors.accent),
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
                  if (spec.isNotEmpty) ...[
                    Text(
                      spec,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: palette.textSecondary),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    _priceFormat.format(product.price),
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
                    s.label,
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
