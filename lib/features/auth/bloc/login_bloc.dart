import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/repositories/pin_repository.dart';
import '../../../core/utils/app_logger.dart';
import 'login_event.dart';
import 'login_state.dart';

/// Same logic as the old LoginCubit's `login()` method — but instead of
/// the View calling a method directly, it dispatches a LoginSubmitted
/// Event, and this Bloc's `on<LoginSubmitted>` handler does the work.
/// That indirection is the entire difference between Cubit and Bloc.
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final FirebaseAuth _auth;
  final PinRepository _pinRepository;
  final FirebaseFirestore _db;

  LoginBloc({FirebaseAuth? auth, PinRepository? pinRepository, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _pinRepository = pinRepository ?? PinRepository(),
        _db = firestore ?? FirebaseFirestore.instance,
        super(const LoginState()) {
    on<LoginSubmitted>(_onSubmitted);
    on<BranchSelected>(_onBranchSelected);
  }

  /// True only on a confirmed "yes, this uid's employee record is
  /// disabled" read. Any failure (network blip, rules hiccup) returns
  /// false on purpose -- same fail-open reasoning as `_hasPinSafe`
  /// below, so a connectivity hiccup during sign-in never locks out a
  /// legitimate, still-active employee. Added 2026-10-06 alongside the
  /// employee delete/remove feature -- see EmployeeRepository.setDisabled.
  Future<bool> _isDisabledEmployee(String uid) async {
    try {
      final doc = await _db.collection('employees').doc(uid).get();
      return doc.data()?['disabled'] == true;
    } catch (e, st) {
      AppLogger.error('LoginBloc._isDisabledEmployee', e, st);
      return false;
    }
  }


  Future<bool?> _hasPinSafe(String uid) async {
    try {
      return await _pinRepository.hasPin(uid);
    } catch (e, st) {
      AppLogger.error('LoginBloc._hasPinSafe', e, st);
      return null;
    }
  }

  Future<void> _onSubmitted(LoginSubmitted event, Emitter<LoginState> emit) async {
    final validationError = _validate(event.username, event.password);
    if (validationError != null) {
      emit(state.copyWith(errorMessage: validationError, isSuccess: false));
      return;
    }

    emit(state.copyWith(isSubmitting: true, clearError: true));

    final email = '${event.username.trim()}@4bmobiles.app';

    try {
      final credential =
          await _auth.signInWithEmailAndPassword(email: email, password: event.password);

      final uid = credential.user?.uid;
      if (uid != null && await _isDisabledEmployee(uid)) {
        await _auth.signOut();
        emit(state.copyWith(
          isSubmitting: false,
          errorMessage: 'This account has been removed. Contact the shop owner.',
          isSuccess: false,
        ));
        return;
      }

      final pinStatus = uid == null ? null : await _hasPinSafe(uid);

      emit(state.copyWith(
        isSubmitting: false,
        isSuccess: true,
        needsPin: pinStatus == true,
        needsSetPin: pinStatus == false,
      ));
    } on FirebaseAuthException catch (e, st) {
      AppLogger.error('LoginBloc._onSubmitted (FirebaseAuthException: ${e.code})', e, st);
      emit(state.copyWith(isSubmitting: false, errorMessage: _messageFor(e), isSuccess: false));
    } catch (e, st) {
      AppLogger.error('LoginBloc._onSubmitted', e, st);
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: 'Something went wrong. Please try again.',
        isSuccess: false,
      ));
    }
  }

  Future<void> _onBranchSelected(BranchSelected event, Emitter<LoginState> emit) async {
    // TODO: pass event.branchId to the real API / store it as the
    // active shop context, so every later Firestore query and the
    // Dashboard/Reports views are scoped to this branch.
    final uid = _auth.currentUser?.uid;
    final pinStatus = uid == null ? null : await _hasPinSafe(uid);
    emit(state.copyWith(
      isSuccess: true,
      needsBranchSelection: false,
      needsPin: pinStatus == true,
      needsSetPin: pinStatus == false,
    ));
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
