import 'package:equatable/equatable.dart';

import '../../../core/models/sale.dart';

class SalesHistoryState extends Equatable {
  final bool isLoading;
  final List<Sale> sales;
  final String? errorMessage;

  /// When the live stream last delivered a snapshot (a fresh sale
  /// coming in, or just the very first load) -- powers the "Updated X
  /// mins ago" line next to the LIVE badge. Local device time, not a
  /// server timestamp -- it only needs to answer "how stale is what's
  /// on screen right now", not be precise across devices.
  final DateTime? lastUpdatedAt;

  const SalesHistoryState({
    this.isLoading = true,
    this.sales = const [],
    this.errorMessage,
    this.lastUpdatedAt,
  });

  double get totalRevenue => sales.fold(0.0, (sum, sale) => sum + sale.total);

  SalesHistoryState copyWith({
    bool? isLoading,
    List<Sale>? sales,
    String? errorMessage,
    bool clearError = false,
    DateTime? lastUpdatedAt,
  }) {
    return SalesHistoryState(
      isLoading: isLoading ?? this.isLoading,
      sales: sales ?? this.sales,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  @override
  List<Object?> get props => [isLoading, sales, errorMessage, lastUpdatedAt];
}
