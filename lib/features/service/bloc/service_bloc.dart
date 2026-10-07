import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/service_job.dart';
import '../../../core/repositories/service_job_repository.dart';
import 'service_event.dart';
import 'service_state.dart';

class ServiceBloc extends Bloc<ServiceEvent, ServiceState> {
  final ServiceJobRepository _repository;

  ServiceBloc({ServiceJobRepository? repository})
      : _repository = repository ?? ServiceJobRepository(),
        super(const ServiceState()) {
    on<ServiceSubscriptionRequested>(_onSubscriptionRequested);
  }

  Future<void> _onSubscriptionRequested(
    ServiceSubscriptionRequested event,
    Emitter<ServiceState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    await emit.forEach<List<ServiceJob>>(
      _repository.watchJobs(shopId: currentShopId),
      onData: (jobs) => state.copyWith(isLoading: false, jobs: jobs, clearError: true),
      onError: (error, stackTrace) => state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load service jobs. Please check your connection and try again.',
      ),
    );
  }
}
