import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/sale.dart';
import '../../../core/repositories/sale_repository.dart';
import 'sales_history_event.dart';
import 'sales_history_state.dart';

class SalesHistoryBloc extends Bloc<SalesHistoryEvent, SalesHistoryState> {
  final SaleRepository _saleRepository;

  SalesHistoryBloc({SaleRepository? saleRepository})
      : _saleRepository = saleRepository ?? SaleRepository(),
        super(const SalesHistoryState()) {
    on<SalesHistorySubscriptionRequested>(_onSubscriptionRequested);
  }

  Future<void> _onSubscriptionRequested(
    SalesHistorySubscriptionRequested event,
    Emitter<SalesHistoryState> emit,
  ) {
    emit(state.copyWith(isLoading: true, clearError: true));

    return emit.forEach<List<Sale>>(
      _saleRepository.watchSales(shopId: currentShopId),
      onData: (sales) => state.copyWith(isLoading: false, sales: sales, clearError: true),
      onError: (error, stackTrace) => state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load past sales. Please check your connection and try again.',
      ),
    );
  }
}
