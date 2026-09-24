import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/sale.dart';
import '../../../core/repositories/sale_repository.dart';
import 'reports_event.dart';
import 'reports_state.dart';

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final SaleRepository _saleRepository;

  ReportsBloc({SaleRepository? saleRepository})
      : _saleRepository = saleRepository ?? SaleRepository(),
        super(const ReportsState()) {
    on<ReportsSubscriptionRequested>(_onSubscriptionRequested);
  }

  Future<void> _onSubscriptionRequested(ReportsSubscriptionRequested event, Emitter<ReportsState> emit) {
    emit(state.copyWith(isLoading: true, clearError: true));

    return emit.forEach<List<Sale>>(
      _saleRepository.watchSales(shopId: currentShopId),
      onData: (sales) => state.copyWith(isLoading: false, sales: sales, clearError: true),
      onError: (error, stackTrace) => state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load report data. Please check your connection and try again.',
      ),
    );
  }
}
