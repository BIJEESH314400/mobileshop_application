import 'package:equatable/equatable.dart';

sealed class ProductsEvent extends Equatable {
  const ProductsEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the Products screen opens — starts a live
/// subscription to this shop's products in Firestore that keeps the
/// list updated for as long as the screen stays open, and can be fired
/// again (e.g. from a "Retry" button) if the subscription errored out.
class ProductsSubscriptionRequested extends ProductsEvent {
  const ProductsSubscriptionRequested();
}
