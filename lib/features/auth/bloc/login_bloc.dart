import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'login_event.dart';
import 'login_state.dart';

/// Same logic as the old LoginCubit's `login()` method — but instead of
/// the View calling a method directly, it dispatches a LoginSubmitted
/// Event, and this Bloc's `on<LoginSubmitted>` handler does the work.
/// That indirection is the entire difference between Cubit and Bloc.
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final FirebaseAuth _auth;

  LoginBloc({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance,
        super(const LoginState()) {
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

    // Firebase Auth only understands email addresses, but the Login
    // screen only ever asks for a "username" — so we turn that username
    // into a fixed-format email behind the scenes before talking to
    // Firebase. The person never sees or types "@4bmobiles.app"
    // anywhere; as far as they're concerned they just have a username.
    final email = '${event.username.trim()}@4bmobiles.app';

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: event.password);

      emit(state.copyWith(isSubmitting: false, isSuccess: true));
    } on FirebaseAuthException catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: _messageFor(e), isSuccess: false));
    } catch (_) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: 'Something went wrong. Please try again.',
        isSuccess: false,
      ));
    }
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

  /// Turns Firebase's error codes into messages a shop owner will
  /// actually understand, rather than raw Firebase jargon.
  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect username or password';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again';
      case 'network-request-failed':
        return 'No internet connection. Please check your network';
      default:
        return 'Sign in failed. Please try again';
    }
  }
}
