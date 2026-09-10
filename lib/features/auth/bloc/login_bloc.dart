import 'package:flutter_bloc/flutter_bloc.dart';

import 'login_event.dart';
import 'login_state.dart';

/// Same logic as the old LoginCubit's `login()` method — but instead of
/// the View calling a method directly, it dispatches a LoginSubmitted
/// Event, and this Bloc's `on<LoginSubmitted>` handler does the work.
/// That indirection is the entire difference between Cubit and Bloc.
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc() : super(const LoginState()) {
    on<LoginSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(LoginSubmitted event, Emitter<LoginState> emit) async {
    final validationError = _validate(event.email, event.password);
    if (validationError != null) {
      emit(state.copyWith(errorMessage: validationError, isSuccess: false));
      return;
    }

    emit(state.copyWith(isSubmitting: true, clearError: true));

    // TODO: replace with a real auth API call.
    await Future.delayed(const Duration(milliseconds: 1200));

    emit(state.copyWith(isSubmitting: false, isSuccess: true));
  }

  String? _validate(String email, String password) {
    if (email.trim().isEmpty || password.isEmpty) {
      return 'Please enter your email and password';
    }
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email address';
    }
    return null;
  }
}
