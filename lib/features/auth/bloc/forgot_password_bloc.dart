import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/repositories/username_lookup_repository.dart';
import 'forgot_password_event.dart';
import 'forgot_password_state.dart';

class ForgotPasswordBloc extends Bloc<ForgotPasswordEvent, ForgotPasswordState> {
  final FirebaseAuth _auth;
  final UsernameLookupRepository _usernames;

  ForgotPasswordBloc({FirebaseAuth? auth, UsernameLookupRepository? usernames})
      : _auth = auth ?? FirebaseAuth.instance,
        _usernames = usernames ?? UsernameLookupRepository(),
        super(const ForgotPasswordState()) {
    on<ForgotPasswordSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(ForgotPasswordSubmitted event, Emitter<ForgotPasswordState> emit) async {
    final username = event.username.trim();
    if (username.isEmpty) {
      emit(state.copyWith(errorMessage: 'Enter your username first', isSuccess: false));
      return;
    }

    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      // Same username → real-email lookup Login uses — the reset email
      // has to go to whatever address Firebase Auth actually has on
      // file for this account, not a made-up one.
      final email = await _usernames.emailForUsername(username);
      if (email == null) {
        emit(state.copyWith(
          isSubmitting: false,
          errorMessage: 'No account found for that username',
          isSuccess: false,
        ));
        return;
      }

      await _auth.sendPasswordResetEmail(email: email);
      emit(state.copyWith(isSubmitting: false, isSuccess: true));
    } on FirebaseAuthException catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: _messageFor(e), isSuccess: false));
    } catch (_) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: 'Could not send reset link. Please check your connection and try again.',
        isSuccess: false,
      ));
    }
  }

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found for that username';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again';
      case 'network-request-failed':
        return 'No internet connection. Please check your network';
      default:
        return 'Could not send reset link. Please try again';
    }
  }
}
