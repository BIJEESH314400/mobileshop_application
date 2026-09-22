import 'package:equatable/equatable.dart';

sealed class SalesHistoryEvent extends Equatable {
  const SalesHistoryEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the Sales History screen opens — starts a live
/// subscription to every completed sale for this shop, same pattern as
/// SalesSubscriptionRequested does for the product picker.
class SalesHistorySubscriptionRequested extends SalesHistoryEvent {
  const SalesHistorySubscriptionRequested();
}
