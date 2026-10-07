import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/models/service_job.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../customers/view/add_customer_screen.dart';
import '../../products/view/add_product_screen.dart';
import '../../service/view/service_job_detail_sheet.dart';
import '../bloc/search_bloc.dart';
import '../bloc/search_event.dart';
import '../bloc/search_state.dart';

/// Opened from the Home screen's search icon (added 2026-10-06) --
/// searches Products, Customers and Service Jobs together from one box,
/// rather than having to know which screen to go search in first.
class GlobalSearchScreen extends StatelessWidget {
  const GlobalSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SearchBloc()
        ..add(const SearchProductsSubscriptionRequested())
        ..add(const SearchCustomersSubscriptionRequested())
        ..add(const SearchJobsSubscriptionRequested()),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 20, 14),
              decoration: BoxDecoration(color: p.background, border: Border(bottom: BorderSide(color: p.border))),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      child: Icon(Icons.arrow_back_rounded, size: 20, color: p.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: p.border)),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, size: 18, color: p.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              style: TextStyle(fontSize: 14, color: p.textPrimary),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                hintText: 'Search products, customers, jobs…',
                                hintStyle: TextStyle(fontSize: 14, color: p.textSecondary),
                              ),
                              onChanged: (value) => context.read<SearchBloc>().add(SearchQueryChanged(value)),
                            ),
                          ),
                          if (_controller.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _controller.clear();
                                context.read<SearchBloc>().add(const SearchQueryChanged(''));
                                setState(() {});
                              },
                              child: Icon(Icons.close_rounded, size: 18, color: p.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<SearchBloc, SearchState>(
                builder: (context, state) {
                  if (state.query.trim().isEmpty) {
                    return _EmptyHint(palette: p);
                  }
                  if (state.isLoading && !state.hasAnyMatches) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!state.hasAnyMatches) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No results for "${state.query.trim()}"',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13.5, color: p.textSecondary),
                        ),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      if (state.matchingProducts.isNotEmpty) ...[
                        _SectionLabel(palette: p, label: 'PRODUCTS (${state.matchingProducts.length})'),
                        const SizedBox(height: 8),
                        for (final product in state.matchingProducts)
                          _ResultRow(
                            palette: p,
                            icon: Icons.shopping_bag_outlined,
                            title: product.name,
                            subtitle: '${product.brand} · ${product.category} · ₹${product.price.toStringAsFixed(0)}',
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddProductScreen(product: product))),
                          ),
                        const SizedBox(height: 18),
                      ],
                      if (state.matchingCustomers.isNotEmpty) ...[
                        _SectionLabel(palette: p, label: 'CUSTOMERS (${state.matchingCustomers.length})'),
                        const SizedBox(height: 8),
                        for (final customer in state.matchingCustomers)
                          _ResultRow(
                            palette: p,
                            icon: Icons.person_outline_rounded,
                            title: customer.name,
                            subtitle: customer.phone.isEmpty ? 'No phone on file' : customer.phone,
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddCustomerScreen(customer: customer))),
                          ),
                        const SizedBox(height: 18),
                      ],
                      if (state.matchingJobs.isNotEmpty) ...[
                        _SectionLabel(palette: p, label: 'SERVICE JOBS (${state.matchingJobs.length})'),
                        const SizedBox(height: 8),
                        for (final job in state.matchingJobs)
                          _ResultRow(
                            palette: p,
                            icon: Icons.build_outlined,
                            title: job.title,
                            subtitle: job.customerName.isEmpty ? job.deviceModel : '${job.deviceModel} · ${job.customerName}',
                            onTap: () => showServiceJobDetailSheet(context, job),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final AppPalette palette;
  const _EmptyHint({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 34, color: palette.textSecondary),
            const SizedBox(height: 10),
            Text(
              'Search across your shop',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: palette.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Find a product, customer or repair job by name, device or phone number.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: palette.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final AppPalette palette;
  final String label;
  const _SectionLabel({required this.palette, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: palette.textSecondary, letterSpacing: 0.5));
  }
}

class _ResultRow extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ResultRow({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(color: AppColors.iconTint, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12.5, color: palette.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }
}
