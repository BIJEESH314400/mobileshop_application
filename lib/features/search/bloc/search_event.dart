import 'package:equatable/equatable.dart';

sealed class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

/// Three separate subscription events -- one per source -- fired
/// together when the search screen opens, same "each on its own
/// concurrent emit.forEach, so one source failing doesn't block the
/// others" pattern CustomersBloc already uses for customers+sales.
class SearchProductsSubscriptionRequested extends SearchEvent {
  const SearchProductsSubscriptionRequested();
}

class SearchCustomersSubscriptionRequested extends SearchEvent {
  const SearchCustomersSubscriptionRequested();
}

class SearchJobsSubscriptionRequested extends SearchEvent {
  const SearchJobsSubscriptionRequested();
}

/// Fired on every keystroke in the search box. Filtering itself happens
/// in SearchState's getters, not here -- same "Bloc holds the raw live
/// lists, filtering is computed off them" approach Reports/Dashboard's
/// own stat cards already use.
class SearchQueryChanged extends SearchEvent {
  final String query;

  const SearchQueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}
