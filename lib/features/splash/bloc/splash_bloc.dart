import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/repositories/pin_repository.dart';
import '../../../core/utils/app_logger.dart';
import 'splash_event.dart';
import 'splash_state.dart';

/// Same job as the old SplashCubit, now expressed as Bloc:
/// an Event comes in -> `on<Event>` handler runs -> `emit()`s a new State.
class SplashBloc extends Bloc<SplashEvent, AuthStatus> {
  final PinRepository _pinRepository;
  final FirebaseFirestore _db;

  SplashBloc({PinRepository? pinRepository, FirebaseFirestore? firestore})
      : _pinRepository = pinRepository ?? PinRepository(),
        _db = firestore ?? FirebaseFirestore.instance,
        super(AuthStatus.checking) {
    on<SplashStarted>(_onStarted);
  }

  /// Same fail-open-on-hiccup reasoning as the PIN check below -- a
  /// confirmed "disabled" blocks the resume, but a network blip reading
  /// it does not strand a legitimate, still-active employee on the
  /// splash screen. Added 2026-10-06 alongside the employee
  /// delete/remove feature -- see EmployeeRepository.setDisabled.
  Future<bool> _isDisabledEmployee(String uid) async {
    try {
      final doc = await _db.collection('employees').doc(uid).get();
      return doc.data()?['disabled'] == true;
    } catch (e, st) {
      AppLogger.error('SplashBloc._isDisabledEmployee', e, st);
      return false;
    }
  }

  Future<void> _onStarted(SplashStarted event, Emitter<AuthStatus> emit) async {
    // Minimum time Splash stays on screen, so its animation
    // (lib/features/splash/view/splash_screen.dart -- about 2.6s to
    // fully play out, plus a short settled beat after) always gets to
    // finish before navigating away. Bumped 700ms -> 3000ms, then -> 4200ms on 2026-10-28: first when
    // the splash animation itself was made longer and more elaborate,
    // then again to cover the new ~1.4s "hold" phase (plain static
    // mark, matching the native pre-Flutter launch screen) plus the
    // ~2.6s reveal that follows it, plus a short settled buffer.
    //
    // Started here, BEFORE the real checks below, but only awaited
    // AFTER them -- so this timer and the real Firebase Auth/Firestore
    // work happen concurrently, not back to back. Total wait is
    // whichever of the two takes longer, not the sum of both: a slow
    // network does not get a full extra 3 seconds piled on top of it,
    // and a fast, already-cached check does not cut the animation
    // short.
    final minDisplay = Future.delayed(const Duration(milliseconds: 4200));

    // Firebase Auth already persists the signed-in session on-device by
    // itself (that's the whole point of the SDK) -- `currentUser` being
    // non-null here IS "is someone still logged in", no separate stored
    // token/session check needed.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await minDisplay;
      emit(AuthStatus.unauthenticated);
      return;
    }
    // A previously-signed-in employee who was removed since their last
    // session must not get a free pass back in just because their
    // device still has a live Firebase Auth session -- same enforcement
    // LoginBloc applies to a fresh sign-in, applied here too since
    // Splash's auto-login otherwise skips Login entirely.
    if (await _isDisabledEmployee(user.uid)) {
      await FirebaseAuth.instance.signOut();
      await minDisplay;
      emit(AuthStatus.unauthenticated);
      return;
    }
    // Signed in -- but if this account also set a Quick PIN, route
    // through PinUnlockScreen instead of straight to Dashboard (see
    // AuthStatus.authenticatedNeedsPin's doc comment).
    //
    // This Firestore read is wrapped in try/catch on purpose: without
    // it, any hiccup here (rules not published yet, a brief network
    // blip, anything) throws inside this handler, no emit() ever runs,
    // and the state sits at AuthStatus.checking forever -- which looks
    // to the user like the app is frozen on the splash spinner with no
    // way forward. Firebase Auth already confirmed this is a real
    // signed-in session, so if we can't reach the PIN check, the safe
    // fallback is to let them straight in unlocked rather than strand
    // them -- the PIN is a soft re-gate on top of real auth, not a
    // replacement for it, so failing open here isn't a security hole.
    // Three-way outcome, not two (2026-09-25, once Quick PIN became
    // required rather than optional): a definite "yes" or "no" from
    // Firestore decides between unlocking the existing PIN and setting
    // a required new one, but a FAILED read (Firestore hiccup, rules
    // not published, etc.) must still fail open straight to Dashboard,
    // same as the original reasoning below -- if it instead demanded a
    // new PIN be set, that `setPin` write would likely fail for the
    // exact same reason the read just did, stranding someone on the
    // Set-PIN screen with no way forward. Only a confirmed "no PIN
    // exists" should ever require setting one.
    AuthStatus result;
    try {
      final hasPin = await _pinRepository.hasPin(user.uid);
      result = hasPin ? AuthStatus.authenticatedNeedsPin : AuthStatus.authenticatedNeedsSetPin;
    } catch (e, st) {
      AppLogger.error('SplashBloc._onStarted (hasPin)', e, st);
      result = AuthStatus.authenticated;
    }
    await minDisplay;
    emit(result);
  }
}
