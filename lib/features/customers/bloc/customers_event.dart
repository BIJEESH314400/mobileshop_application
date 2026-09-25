import 'package:equatable/equatable.dart';

sealed class CustomersEvent extends Equatable {
  const CustomersEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the Customers screen opens — starts a live
/// subscription to this shop's customer directory.
class CustomersSubscriptionRequested extends CustomersEvent {
  const CustomersSubscriptionRequested();
}

/// Fired alongside CustomersSubscriptionRequested — a SEPARATE,
/// concurrent subscription to this shop's sales, used only to compute
/// each customer's order count / total spent / VIP status (see
/// CustomersState). Same two-concurrent-streams pattern SalesBloc uses
/// for its own customer stream, borrowed from ConversationBloc's
/// typing indicator.
class CustomersSalesSubscriptionRequested extends CustomersEvent {
  const CustomersSalesSubscriptionRequested();
}

/// Raw text typed into the search bar.
class CustomersSearchChanged extends CustomersEvent {
  final String query;
  const CustomersSearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}
