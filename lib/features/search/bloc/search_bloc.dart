import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/models/service_job.dart';
import '../../../core/repositories/customer_repository.dart';
import '../../../core/repositories/product_repository.dart';
import '../../../core/repositories/service_job_repository.dart';
import 'search_event.dart';
import 'search_state.dart';

/// Backs the Home screen's search icon (added 2026-10-06) -- a single
/// screen searching Products, Customers and Service Jobs together.
/// Subscribes to all 3 live streams concurrently so a hiccup loading
/// one source doesn't block the other two from showing results.
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final ProductRepository _productRepository;
  final CustomerRepository _customerRepository;
  final ServiceJobRepository _jobRepository;

  SearchBloc({
    ProductRepository? productRepository,
    CustomerRepository? customerRepository,
    ServiceJobRepository? jobRepository,
  })  : _productRepository = productRepository ?? ProductRepository(),
        _customerRepository = customerRepository ?? CustomerRepository(),
        _jobRepository = jobRepository ?? ServiceJobRepository(),
        super(const SearchState()) {
    on<SearchProductsSubscriptionRequested>(_onProducts);
    on<SearchCustomersSubscriptionRequested>(_onCustomers);
    on<SearchJobsSubscriptionRequested>(_onJobs);
    on<SearchQueryChanged>(_onQueryChanged);
  }

  Future<void> _onProducts(SearchProductsSubscriptionRequested event, Emitter<SearchState> emit) async {
    await emit.forEach<List<Product>>(
      _productRepository.watchProducts(shopId: currentShopId),
      onData: (products) => state.copyWith(products: products, productsLoading: false),
      onError: (error, stackTrace) => state.copyWith(productsLoading: false),
    );
  }

  Future<void> _onCustomers(SearchCustomersSubscriptionRequested event, Emitter<SearchState> emit) async {
    await emit.forEach<List<Customer>>(
      _customerRepository.watchCustomers(shopId: currentShopId),
      onData: (customers) => state.copyWith(customers: customers, customersLoading: false),
      onError: (error, stackTrace) => state.copyWith(customersLoading: false),
    );
  }

  Future<void> _onJobs(SearchJobsSubscriptionRequested event, Emitter<SearchState> emit) async {
    await emit.forEach<List<ServiceJob>>(
      _jobRepository.watchJobs(shopId: currentShopId),
      onData: (jobs) => state.copyWith(jobs: jobs, jobsLoading: false),
      onError: (error, stackTrace) => state.copyWith(jobsLoading: false),
    );
  }

  void _onQueryChanged(SearchQueryChanged event, Emitter<SearchState> emit) {
    emit(state.copyWith(query: event.query));
  }
}
