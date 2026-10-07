import 'package:equatable/equatable.dart';

sealed class ServiceEvent extends Equatable {
  const ServiceEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the Service screen opens -- starts a live
/// subscription to this shop's repair jobs. Status-tab filtering stays
/// local View state (unchanged from the original static-data version)
/// rather than a Bloc event, same as every other client-side filter in
/// this app (Customers' search, Reports' period pills).
class ServiceSubscriptionRequested extends ServiceEvent {
  const ServiceSubscriptionRequested();
}
