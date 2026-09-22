import 'package:equatable/equatable.dart';

import '../../../core/models/sale.dart';

class SalesHistoryState extends Equatable {
  final bool isLoading;
  final List<Sale> sales;
  final String? errorMessage;

  const SalesHistoryState({
    this.isLoading = true,
    this.sales = const [],
    this.errorMessage,
  });

  double get totalRevenue => sales.fold(0.0, (sum, sale) => sum + sale.total);

  SalesHistoryState copyWith({
    bool? isLoading,
    List<Sale>? sales,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SalesHistoryState(
      isLoading: isLoading ?? this.isLoading,
      sales: sales ?? this.sales,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isLoading, sales, errorMessage];
}
