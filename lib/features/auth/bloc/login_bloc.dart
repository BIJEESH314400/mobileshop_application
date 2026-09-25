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

  LoginBloc({FirebaseAuth? auth, PinRepository? pinRepository})
      : _auth = auth ?? FirebaseAuth.instance,
        _pinRepository = pinRepository ?? PinRepository(),
        super(const LoginState()) {
    on<LoginSubmitted>(_onSubmitted);
    on<BranchSelected>(_onBranchSelected);
  }

  /// Three-way result, not a plain bool (2026-09-25, once Quick PIN
  /// became required rather than optional): `true`/`false` are a
  /// confirmed read, `null` means the read itself failed (Firestore
  /// hiccup, rules not published, etc.). That distinction matters now
  /// -- treating a failed read as "confirmed no PIN" would force
  /// someone straight into the mandatory Set-PIN screen at the exact
  /// moment Firestore is unreachable, where the `setPin` write would
  /// likely fail too and strand them with no way forward (mandatory
  /// mode has no back button). `null` is handled by both callers below
  /// as "fail open, skip the PIN step entirely" -- same safe fallback
  /// SplashBloc uses for the same reason.
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

    // Firebase Auth only understands email addresses, but the Login
    // screen only ever asks for a "username" — so we turn that username
    // into a fixed-format email behind the scenes before talking to
    // Firebase. The person never sees or types "@4bmobiles.app"
    // anywhere; as far as they're concerned they just have a username.
    final email = '${event.username.trim()}@4bmobiles.app';

    try {
      final credential =
          await _auth.signInWithEmailAndPassword(email: email, password: event.password);

      // A fresh explicit login is exactly the case Splash can never
      // see (uninstalling the app, or just signing all the way out,
      // wipes the locally-persisted Firebase session, so next time
      // it's this flow that runs, not Splash's cold-start check) --
      // without this, an account that set a Quick PIN earlier would
      // never be asked for it after a full re-login, which is the gap
      // that was reported.
      //
      // Quick PIN is now REQUIRED, not optional (2026-09-25): an
      // account with no PIN yet doesn't just fall through to Dashboard
      // any more, it's sent to set one (needsSetPin) -- see
      // LoginScreen's listener. `clearPin` is also now called on
      // logout (ProfileScreen._logOut), so this is the path that runs
      // again every time someone logs back in after logging out.
      final uid = credential.user?.uid;
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
