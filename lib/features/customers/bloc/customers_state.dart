import 'package:equatable/equatable.dart';

import '../../../core/models/customer.dart';
import '../../../core/models/sale.dart';

class CustomersState extends Equatable {
  /// A customer with this many completed orders (or more) shows the
  /// VIP badge. A simple, fixed threshold rather than a spend amount —
  /// easy to explain, and doesn't need a currency-specific number
  /// guessed on the shop's behalf. Adjust here if 5 turns out wrong in
  /// practice.
  static const int vipOrderThreshold = 5;

  final bool isLoading;
  final List<Customer> customers;
  final List<Sale> sales;
  final String searchQuery;
  final String? errorMessage;

  const CustomersState({
    this.isLoading = true,
    this.customers = const [],
    this.sales = const [],
    this.searchQuery = '',
    this.errorMessage,
  });

  /// `customers`, filtered by `searchQuery` against name/phone — same
  /// "math/filtering lives in State, not pushed into the Bloc" approach
  /// Reports and SalesState already use.
  List<Customer> get filteredCustomers {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return customers;
    return customers.where((c) => c.name.toLowerCase().contains(query) || c.phone.contains(query)).toList();
  }

  /// Every sale linked to this customer (Sale.customerId), for the
  /// order-count/spend/VIP computations below and the per-customer
  /// order-history sheet.
  List<Sale> salesFor(String customerId) =>
      sales.where((s) => s.customerId == customerId).toList()
        ..sort((a, b) {
          final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime); // newest first
        });

  int orderCountFor(String customerId) => sales.where((s) => s.customerId == customerId).length;

  double totalSpentFor(String customerId) =>
      sales.where((s) => s.customerId == customerId).fold(0.0, (sum, s) => sum + s.total);

  bool isVip(String customerId) => orderCountFor(customerId) >= vipOrderThreshold;

  CustomersState copyWith({
    bool? isLoading,
    List<Customer>? customers,
    List<Sale>? sales,
    String? searchQuery,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CustomersState(
      isLoading: isLoading ?? this.isLoading,
      customers: customers ?? this.customers,
      sales: sales ?? this.sales,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isLoading, customers, sales, searchQuery, errorMessage];
}
