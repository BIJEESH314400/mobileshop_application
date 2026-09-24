import 'package:equatable/equatable.dart';

sealed class ReportsEvent extends Equatable {
  const ReportsEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the Reports screen opens -- starts a live
/// subscription to every completed sale for this shop. Same data
/// source as Sales History (SaleRepository.watchSales()), kept as its
/// own Bloc instance rather than reusing SalesHistoryBloc directly, so
/// Reports stays free to add report-specific state later without
/// touching the Sales History screen.
class ReportsSubscriptionRequested extends ReportsEvent {
  const ReportsSubscriptionRequested();
}
