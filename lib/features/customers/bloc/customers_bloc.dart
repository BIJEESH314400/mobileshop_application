import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/sale.dart';
import '../../../core/repositories/customer_repository.dart';
import '../../../core/repositories/sale_repository.dart';
import 'customers_event.dart';
import 'customers_state.dart';

class CustomersBloc extends Bloc<CustomersEvent, CustomersState> {
  final CustomerRepository _customerRepository;
  final SaleRepository _saleRepository;

  CustomersBloc({
    CustomerRepository? customerRepository,
    SaleRepository? saleRepository,
  })  : _customerRepository = customerRepository ?? CustomerRepository(),
        _saleRepository = saleRepository ?? SaleRepository(),
        super(const CustomersState()) {
    on<CustomersSubscriptionRequested>(_onSubscriptionRequested);
    on<CustomersSalesSubscriptionRequested>(_onSalesSubscriptionRequested);
    on<CustomersSearchChanged>(_onSearchChanged);
  }

  Future<void> _onSubscriptionRequested(
    CustomersSubscriptionRequested event,
    Emitter<CustomersState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    await emit.forEach<List<Customer>>(
      _customerRepository.watchCustomers(shopId: currentShopId),
      onData: (customers) => state.copyWith(isLoading: false, customers: customers, clearError: true),
      onError: (error, stackTrace) => state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load customers. Please check your connection and try again.',
      ),
    );
  }

  // Concurrent with the subscription above -- only used to compute
  // order count/spend/VIP per customer (see CustomersState), so a
  // failed load here is swallowed rather than blocking the customer
  // list itself: an order count of 0 everywhere is a much smaller
  // problem than the whole screen refusing to show customers at all.
  Future<void> _onSalesSubscriptionRequested(
    CustomersSalesSubscriptionRequested event,
    Emitter<CustomersState> emit,
  ) async {
    await emit.forEach<List<Sale>>(
      _saleRepository.watchSales(shopId: currentShopId),
      onData: (sales) => state.copyWith(sales: sales),
      onError: (error, stackTrace) => state,
    );
  }

  void _onSearchChanged(CustomersSearchChanged event, Emitter<CustomersState> emit) {
    emit(state.copyWith(searchQuery: event.query));
  }
}
