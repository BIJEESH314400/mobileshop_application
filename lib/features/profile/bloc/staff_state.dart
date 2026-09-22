import 'package:equatable/equatable.dart';

import '../../../core/models/employee.dart';

class StaffState extends Equatable {
  final bool isLoading;
  final List<Employee> employees;
  final String? errorMessage;

  const StaffState({
    this.isLoading = true,
    this.employees = const [],
    this.errorMessage,
  });

  StaffState copyWith({
    bool? isLoading,
    List<Employee>? employees,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StaffState(
      isLoading: isLoading ?? this.isLoading,
      employees: employees ?? this.employees,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isLoading, employees, errorMessage];
}
