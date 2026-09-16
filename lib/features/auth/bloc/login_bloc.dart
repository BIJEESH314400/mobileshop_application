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
    final validationError = _validate(event.mobile, event.shopId, event.password);
    if (validationError != null) {
      emit(state.copyWith(errorMessage: validationError, isSuccess: false));
      return;
    }

    emit(state.copyWith(isSubmitting: true, clearError: true));

    // TODO: replace with a real Firebase Auth call. Firebase Auth's
    // email/password provider needs an email-shaped identifier, so
    // when this is wired up, build a synthetic one from these two
    // fields instead of asking the user for a real email address,
    // e.g.:
    //   final syntheticEmail = '${event.mobile}@${event.shopId}.4bmobiles.app';
    //   await FirebaseAuth.instance.signInWithEmailAndPassword(
    //     email: syntheticEmail,
    //     password: event.password,
    //   );
    await Future.delayed(const Duration(milliseconds: 1200));

    emit(state.copyWith(isSubmitting: false, isSuccess: true));
  }

  String? _validate(String mobile, String shopId, String password) {
    final mobileTrimmed = mobile.trim();
    final shopIdTrimmed = shopId.trim();
    if (mobileTrimmed.isEmpty || shopIdTrimmed.isEmpty || password.isEmpty) {
      return 'Please enter your mobile number, shop ID and password';
    }
    if (!RegExp(r'^[0-9]{10}$').hasMatch(mobileTrimmed)) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }
}
