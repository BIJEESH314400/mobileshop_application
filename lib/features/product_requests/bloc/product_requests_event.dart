import 'package:equatable/equatable.dart';

sealed class ProductRequestsEvent extends Equatable {
  const ProductRequestsEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when this list is first needed -- starts a live
/// subscription to this shop's still-waiting product requests.
class ProductRequestsSubscriptionRequested extends ProductRequestsEvent {
  const ProductRequestsSubscriptionRequested();
}

/// Staff tapped "Mark Fulfilled" on a request -- after they've
/// restocked the product and handed it to the customer (or called
/// them, however it actually played out).
class ProductRequestFulfilled extends ProductRequestsEvent {
  final String requestId;
  const ProductRequestFulfilled(this.requestId);

  @override
  List<Object?> get props => [requestId];
}
