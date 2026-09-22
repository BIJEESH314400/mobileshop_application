import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/shop_constants.dart';
import '../../../core/repositories/employee_repository.dart';
import 'add_employee_event.dart';
import 'add_employee_state.dart';

class AddEmployeeBloc extends Bloc<AddEmployeeEvent, AddEmployeeState> {
  final EmployeeRepository _repository;

  AddEmployeeBloc({EmployeeRepository? repository})
      : _repository = repository ?? EmployeeRepository(),
        super(const AddEmployeeState()) {
    on<AddEmployeeSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(AddEmployeeSubmitted event, Emitter<AddEmployeeState> emit) async {
    final validationError = _validate(event);
    if (validationError != null) {
      emit(state.copyWith(errorMessage: validationError, isSuccess: false));
      return;
    }

    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      await _repository.addEmployee(
        name: event.name,
        username: event.username,
        password: event.password,
        shopId: currentShopId,
      );
      emit(state.copyWith(isSubmitting: false, isSuccess: true));
    } on FirebaseAuthException catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: _messageFor(e), isSuccess: false));
    } catch (_) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: 'Could not create employee login. Please check your connection and try again.',
        isSuccess: false,
      ));
    }
  }

  String? _validate(AddEmployeeSubmitted event) {
    if (event.name.trim().isEmpty) return 'Employee name is required';

    final username = event.username.trim().toLowerCase();
    if (username.isEmpty) return 'Username is required';
    if (username.length < 3) return 'Username must be at least 3 characters';
    if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(username)) {
      return 'Username can only have letters, numbers, dot or underscore';
    }

    if (event.password.length < 6) return 'Password must be at least 6 characters';

    return null;
  }

  /// Turns Firebase's error codes into messages a shop owner will
  /// actually understand, same idea as LoginBloc._messageFor.
  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'That username is already taken. Please choose another';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters';
      case 'network-request-failed':
        return 'No internet connection. Please check your network';
      default:
        return 'Could not create employee login. Please try again';
    }
  }
}
