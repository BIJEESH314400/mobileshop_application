import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/product_request.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/app_logger.dart';
import '../bloc/product_requests_bloc.dart';
import '../bloc/product_requests_event.dart';
import '../bloc/product_requests_state.dart';
import 'add_request_screen.dart';

final _dateFormat = DateFormat('d MMM, h:mm a');

/// "Waiting Customers" -- every "customer is waiting for this item"
/// request, newest first. Two ways a request gets here: this screen's
/// own "+ Add Request" button (free-text item name, no Products
/// catalog entry needed -- the normal path, added 2026-10-07 once the
/// owner pointed out that requiring a catalog entry first was backwards
/// for an item the shop doesn't carry at all), or the Sales screen's
/// product picker, for a catalog item genuinely at zero stock. A
/// request drops off this list on its own the moment it's marked
/// fulfilled -- the live subscription only ever asks for
/// `fulfilled == false`.
class ProductRequestsScreen extends StatelessWidget {
  const ProductRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProductRequestsBloc()..add(const ProductRequestsSubscriptionRequested()),
      child: const _ProductRequestsView(),
    );
  }
}

class _ProductRequestsView extends StatelessWidget {
  const _ProductRequestsView();

  Future<void> _call(BuildContext context, String phone) async {
    try {
      final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
      if (!launched) throw Exception('launchUrl returned false for tel:$phone');
    } catch (e, st) {
      AppLogger.error('ProductRequestsScreen._call', e, st);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Couldn't open the dialer")));
    }
  }

  void _markFulfilled(BuildContext context, ProductRequest request) {
    context.read<ProductRequestsBloc>().add(ProductRequestFulfilled(request.id));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Marked fulfilled — ${request.customerName}')));
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              decoration: BoxDecoration(
                color: p.background,
                border: Border(bottom: BorderSide(color: p.border)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_back_rounded, size: 20, color: p.textPrimary),
                        const SizedBox(width: 14),
                        Text('Waiting Customers', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<ProductRequestsBloc, ProductRequestsState>(
                builder: (context, state) {
                  if (state.isLoading && state.requests.isEmpty) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
                  }
                  if (state.errorMessage != null && state.requests.isEmpty) {
                    return Center(child: Text(state.errorMessage!, style: TextStyle(color: p.textSecondary)));
                  }
                  if (state.requests.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          "No one's waiting on anything right now.\nTap \"+ Add Request\" below when a customer\nasks for something you don't have on hand.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13.5, color: p.textSecondary, height: 1.5),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    itemCount: state.requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final request = state.requests[index];
                      return _RequestCard(
                        palette: p,
                        request: request,
                        onCall: request.customerPhone.isEmpty ? null : () => _call(context, request.customerPhone),
                        onFulfilled: () => _markFulfilled(context, request),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.border))),
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddRequestScreen())),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Add Request', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final AppPalette palette;
  final ProductRequest request;
  final VoidCallback? onCall;
  final VoidCallback onFulfilled;

  const _RequestCard({
    required this.palette,
    required this.request,
    required this.onCall,
    required this.onFulfilled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.iconTint, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.quantity > 1 ? '${request.quantity}× ${request.productName}' : request.productName,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.createdAt == null ? 'Waiting' : 'Waiting since ${_dateFormat.format(request.createdAt!)}',
                      style: TextStyle(fontSize: 11.5, color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: palette.border),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 16, color: palette.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request.customerPhone.isEmpty ? request.customerName : '${request.customerName} · ${request.customerPhone}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onCall != null)
                GestureDetector(
                  onTap: onCall,
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.iconTint, shape: BoxShape.circle),
                    child: const Icon(Icons.call_outlined, size: 15, color: AppColors.accent),
                  ),
                ),
            ],
          ),
          if (request.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: palette.background, borderRadius: BorderRadius.circular(8)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sticky_note_2_outlined, size: 14, color: palette.textSecondary),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      request.note,
                      style: TextStyle(fontSize: 12, color: palette.textSecondary, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onFulfilled,
            child: Container(
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.success),
                  const SizedBox(width: 7),
                  const Text(
                    'Mark Fulfilled',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
