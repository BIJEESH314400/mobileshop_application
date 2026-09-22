import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/models/employee.dart';
import '../../../core/repositories/employee_repository.dart';
import 'staff_event.dart';
import 'staff_state.dart';

class StaffBloc extends Bloc<StaffEvent, StaffState> {
  final EmployeeRepository _repository;

  StaffBloc({EmployeeRepository? repository})
      : _repository = repository ?? EmployeeRepository(),
        super(const StaffState()) {
    on<StaffSubscriptionRequested>(_onSubscriptionRequested);
  }

  Future<void> _onSubscriptionRequested(StaffSubscriptionRequested event, Emitter<StaffState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    await emit.forEach<List<Employee>>(
      _repository.watchEmployees(shopId: currentShopId),
      onData: (employees) => state.copyWith(isLoading: false, employees: employees, clearError: true),
      onError: (error, stackTrace) => state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load staff. Please check your connection and try again.',
      ),
    );
  }
}
