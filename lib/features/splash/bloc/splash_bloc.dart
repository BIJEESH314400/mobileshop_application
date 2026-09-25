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

  SplashBloc({PinRepository? pinRepository})
      : _pinRepository = pinRepository ?? PinRepository(),
        super(AuthStatus.checking) {
    on<SplashStarted>(_onStarted);
  }

  Future<void> _onStarted(SplashStarted event, Emitter<AuthStatus> emit) async {
    // Firebase Auth already persists the signed-in session on-device by
    // itself (that's the whole point of the SDK) -- `currentUser` being
    // non-null here IS "is someone still logged in", no separate stored
    // token/session check needed. Before this fix, this always emitted
    // `unauthenticated` regardless -- meaning every single app launch
    // forced a fresh username+password login even for someone who'd
    // never signed out, which is the "burden" the shop owner flagged.
    // The short delay below is only so the splash branding is visible
    // for a beat -- it's not part of the check itself.
    await Future.delayed(const Duration(milliseconds: 700));
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
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
    try {
      final hasPin = await _pinRepository.hasPin(user.uid);
      emit(hasPin ? AuthStatus.authenticatedNeedsPin : AuthStatus.authenticatedNeedsSetPin);
    } catch (e, st) {
      AppLogger.error('SplashBloc._onStarted (hasPin)', e, st);
      emit(AuthStatus.authenticated);
    }
  }
}
