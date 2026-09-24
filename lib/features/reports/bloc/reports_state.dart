import 'package:equatable/equatable.dart';

import '../../../core/models/sale.dart';

/// Just the raw live sales list + loading/error flags -- the same
/// shape as SalesHistoryState. Period filtering (Today/Week/Month/All)
/// and every aggregation (revenue, top products, payment breakdown,
/// the 7-day chart) are computed in the View from this raw list, same
/// pattern Dashboard's _StatGrid already uses on SalesHistoryBloc's
/// data -- no need to duplicate that logic into the Bloc/State.
class ReportsState extends Equatable {
  final bool isLoading;
  final List<Sale> sales;
  final String? errorMessage;

  const ReportsState({
    this.isLoading = true,
    this.sales = const [],
    this.errorMessage,
  });

  ReportsState copyWith({
    bool? isLoading,
    List<Sale>? sales,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ReportsState(
      isLoading: isLoading ?? this.isLoading,
      sales: sales ?? this.sales,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isLoading, sales, errorMessage];
}
