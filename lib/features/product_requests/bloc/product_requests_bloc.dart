import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/product_request.dart';
import '../../../core/repositories/product_request_repository.dart';
import 'product_requests_event.dart';
import 'product_requests_state.dart';

class ProductRequestsBloc extends Bloc<ProductRequestsEvent, ProductRequestsState> {
  final ProductRequestRepository _repository;

  ProductRequestsBloc({ProductRequestRepository? repository})
      : _repository = repository ?? ProductRequestRepository(),
        super(const ProductRequestsState()) {
    on<ProductRequestsSubscriptionRequested>(_onSubscriptionRequested);
    on<ProductRequestFulfilled>(_onFulfilled);
  }

  Future<void> _onSubscriptionRequested(
    ProductRequestsSubscriptionRequested event,
    Emitter<ProductRequestsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    await emit.forEach<List<ProductRequest>>(
      _repository.watchWaitingRequests(shopId: currentShopId),
      onData: (requests) => state.copyWith(isLoading: false, requests: requests, clearError: true),
      onError: (error, stackTrace) => state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load requests. Please check your connection and try again.',
      ),
    );
  }

  // Fire-and-forget on purpose, same as other simple status writes in
  // this app (e.g. EmployeeRepository.setDisabled from the UI) -- the
  // live subscription above picks up the change and drops the row off
  // the list on its own once Firestore confirms the write.
  Future<void> _onFulfilled(ProductRequestFulfilled event, Emitter<ProductRequestsState> emit) async {
    await _repository.markFulfilled(event.requestId);
  }
}
