import 'package:equatable/equatable.dart';

sealed class StaffEvent extends Equatable {
  const StaffEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the Staff Management screen opens — starts a live
/// subscription to this shop's employees, same pattern as
/// ProductsSubscriptionRequested.
class StaffSubscriptionRequested extends StaffEvent {
  const StaffSubscriptionRequested();
}
