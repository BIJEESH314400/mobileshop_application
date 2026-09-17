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
    on<BranchSelected>(_onBranchSelected);
  }

  Future<void> _onSubmitted(LoginSubmitted event, Emitter<LoginState> emit) async {
    final validationError = _validate(event.username, event.password);
    if (validationError != null) {
      emit(state.copyWith(errorMessage: validationError, isSuccess: false));
      return;
    }

    emit(state.copyWith(isSubmitting: true, clearError: true));

    // TODO: replace with a real login API call. The response should
    // include something like `hasMultipleBranches` (a bool/bit) plus
    // the list of branch names/ids for this account when it's true:
    //   final result = await authApi.login(event.username, event.password);
    //   if (result.hasMultipleBranches) {
    //     emit(state.copyWith(
    //       isSubmitting: false,
    //       needsBranchSelection: true,
    //       availableBranches: result.branches,
    //     ));
    //     return;
    //   }
    //   emit(state.copyWith(isSubmitting: false, isSuccess: true));
    // Until that real API exists, every login behaves as single-branch
    // (no popup) — this fake delay stands in for the call.
    await Future.delayed(const Duration(milliseconds: 1200));

    emit(state.copyWith(isSubmitting: false, isSuccess: true));
  }

  void _onBranchSelected(BranchSelected event, Emitter<LoginState> emit) {
    // TODO: pass event.branchId to the real API / store it as the
    // active shop context, so every later Firestore query and the
    // Dashboard/Reports views are scoped to this branch.
    emit(state.copyWith(isSuccess: true, needsBranchSelection: false));
  }

  String? _validate(String username, String password) {
    if (username.trim().isEmpty || password.isEmpty) {
      return 'Please enter your username and password';
    }
    return null;
  }
}
