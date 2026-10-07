import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../features/pin/view/pin_unlock_screen.dart';
import '../repositories/pin_repository.dart';
import '../routes/root_navigator_key.dart';
import '../utils/app_logger.dart';

/// Mounted once, above MaterialApp, for the whole app's lifetime (same
/// pattern as ChatNotificationWatcher). Handles the OTHER half of the
/// Quick PIN feature: SplashBloc/SplashScreen only ever run once, at a
/// true cold start, so they can't catch "the app was just backgrounded
/// and brought back" -- that's this widget's job, via
/// WidgetsBindingObserver.didChangeAppLifecycleState.
///
/// Deliberately starts `_locked = false` and only ever sets it true
/// after actually observing a `paused` transition -- a fresh cold
/// start goes straight to `resumed` with no prior `paused`, so this
/// never double-shows the PIN screen on top of the one Splash already
/// routed to for that case.
class PinLockGate extends StatefulWidget {
  final Widget child;
  const PinLockGate({super.key, required this.child});

  @override
  State<PinLockGate> createState() => _PinLockGateState();
}

class _PinLockGateState extends State<PinLockGate> with WidgetsBindingObserver {
  final _pinRepository = PinRepository();
  StreamSubscription<User?>? _authSub;

  bool _hasPinForCurrentUser = false;
  bool _locked = false;
  bool _unlockScreenShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      _hasPinForCurrentUser = false;
      _locked = false;
      return;
    }
    try {
      _hasPinForCurrentUser = await _pinRepository.hasPin(user.uid);
    } catch (e, st) {
      AppLogger.error('PinLockGate._onAuthChanged', e, st);
      _hasPinForCurrentUser = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Re-checked fresh on every pause rather than trusting only the
        // cache from the last sign-in -- setting a PIN mid-session (via
        // Profile's "Quick PIN" row) doesn't fire a new auth-state
        // change, so that cache alone would still say "no PIN" if the
        // app were backgrounded moments after saving one. A Firestore
        // read here is fire-and-forget, not awaited -- going from
        // paused to resumed always takes at least a human-noticeable
        // moment in practice, which is enough time for this to land
        // well before `resumed` fires.
        _pinRepository.hasPin(user.uid).then((has) {
          _hasPinForCurrentUser = has;
          if (has) _locked = true;
        }).catchError((e, st) {
          // Same reasoning as SplashBloc's try/catch: a failed read
          // here must never throw unhandled -- it would just be a
          // silent zone error, not a stuck screen, but there's no
          // reason to risk it when swallowing it costs nothing.
          AppLogger.error('PinLockGate.didChangeAppLifecycleState (paused hasPin)', e, st);
        });
      }
      return;
    }
    if (state == AppLifecycleState.resumed && _locked && !_unlockScreenShowing) {
      _showUnlockScreen();
    }
  }

  void _showUnlockScreen() {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    _unlockScreenShowing = true;
    navigator
        .push(MaterialPageRoute(
          builder: (_) => PinUnlockScreen(
            onUnlocked: () => rootNavigatorKey.currentState?.pop(),
          ),
        ))
        .then((_) {
      _unlockScreenShowing = false;
      _locked = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
