import 'package:equatable/equatable.dart';

import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/models/service_job.dart';

class SearchState extends Equatable {
  final List<Product> products;
  final List<Customer> customers;
  final List<ServiceJob> jobs;
  final bool productsLoading;
  final bool customersLoading;
  final bool jobsLoading;
  final String query;

  const SearchState({
    this.products = const [],
    this.customers = const [],
    this.jobs = const [],
    this.productsLoading = true,
    this.customersLoading = true,
    this.jobsLoading = true,
    this.query = '',
  });

  bool get isLoading => productsLoading || customersLoading || jobsLoading;

  String get _q => query.trim().toLowerCase();

  // Each list is empty whenever there's no query yet -- the screen's
  // own empty-query state (a plain "search across your shop" hint)
  // handles that, rather than dumping every product/customer/job on
  // screen the moment it opens.
  List<Product> get matchingProducts {
    if (_q.isEmpty) return const [];
    return products
        .where((p) => p.name.toLowerCase().contains(_q) || p.sku.toLowerCase().contains(_q) || p.brand.toLowerCase().contains(_q))
        .toList();
  }

  List<Customer> get matchingCustomers {
    if (_q.isEmpty) return const [];
    return customers
        .where((c) =>
            c.name.toLowerCase().contains(_q) ||
            c.phone.contains(_q) ||
            c.altPhone.contains(_q) ||
            c.email.toLowerCase().contains(_q))
        .toList();
  }

  List<ServiceJob> get matchingJobs {
    if (_q.isEmpty) return const [];
    return jobs
        .where((j) =>
            j.title.toLowerCase().contains(_q) ||
            j.deviceModel.toLowerCase().contains(_q) ||
            j.customerName.toLowerCase().contains(_q))
        .toList();
  }

  bool get hasAnyMatches => matchingProducts.isNotEmpty || matchingCustomers.isNotEmpty || matchingJobs.isNotEmpty;

  SearchState copyWith({
    List<Product>? products,
    List<Customer>? customers,
    List<ServiceJob>? jobs,
    bool? productsLoading,
    bool? customersLoading,
    bool? jobsLoading,
    String? query,
  }) {
    return SearchState(
      products: products ?? this.products,
      customers: customers ?? this.customers,
      jobs: jobs ?? this.jobs,
      productsLoading: productsLoading ?? this.productsLoading,
      customersLoading: customersLoading ?? this.customersLoading,
      jobsLoading: jobsLoading ?? this.jobsLoading,
      query: query ?? this.query,
    );
  }

  @override
  List<Object?> get props => [products, customers, jobs, productsLoading, customersLoading, jobsLoading, query];
}
