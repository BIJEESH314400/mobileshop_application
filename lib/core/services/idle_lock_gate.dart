import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/pin/view/pin_unlock_screen.dart';
import '../repositories/pin_repository.dart';
import '../routes/root_navigator_key.dart';
import '../utils/app_logger.dart';
import '../widgets/inactivity_alert_dialog.dart';

/// Mounted once, above MaterialApp, for the whole app's lifetime (same
/// pattern as ChatNotificationWatcher) -- the auto-lock half of Quick
/// PIN. Replaces the old `PinLockGate`, which locked the instant the
/// app was backgrounded at all; this instead locks after [idleTimeout]
/// of real inactivity -- no taps anywhere on screen -- whether that
/// time passed with the app open and untouched, minimized, or a mix of
/// both. Per the "idle 5 minutes -> alert -> re-auth with PIN"
/// requirement (2026-10-07).
///
/// Three moving parts:
/// 1. A root [Listener] wrapping `widget.child` catches every pointer-
///    down anywhere in the app (no per-screen wiring needed) and
///    resets the idle clock. **Known limitation:** this only sees taps
///    that land inside Flutter's own view. The native on-screen
///    keyboard (used while typing in any text field) is a separate OS
///    overlay that Flutter never receives pointer events from -- so
///    someone typing a long note for 5+ straight minutes without
///    touching anything else in the app could still get auto-locked.
///    Flagged as a known trade-off rather than solved here, since
///    properly fixing it means wiring activity tracking into every
///    text field across the app, a much bigger change than this
///    feature's own scope.
/// 2. While resumed, a single-shot [Timer] fires exactly at the idle
///    deadline computed from the last reset -- cancelled and restarted
///    on every tap rather than polled, so it only ever fires once,
///    right on time, rather than waking up every few seconds to check.
/// 3. `_lastActivityAt` is persisted to SharedPreferences (throttled to
///    at most once every 10s during continuous use, plus unconditionally
///    on every `paused`) so a resume after mere backgrounding AND a
///    true cold start after the OS fully killed the process both read
///    the same stored timestamp -- see [wasIdleTooLong], used by
///    SplashBloc/SplashScreen for the latter case.
class IdleLockGate extends StatefulWidget {
  final Widget child;
  const IdleLockGate({super.key, required this.child});

  static const idleTimeout = Duration(minutes: 5);
  static const _prefsKey = 'lastActivityAtMillis';

  /// Read on a true cold start (SplashBloc) -- if the saved timestamp
  /// is already older than [idleTimeout], the idle budget was blown
  /// while this process wasn't even running (backgrounded, then killed
  /// by the OS), so Splash shows the "logged out due to inactivity"
  /// message on the PIN screen it already routes to, instead of the
  /// plain "welcome back". Fails open (returns false) on any storage
  /// hiccup, same reasoning as every other PIN-adjacent check in this
  /// app -- a failed read must never block someone from getting in.
  static Future<bool> wasIdleTooLong() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final millis = prefs.getInt(_prefsKey);
      if (millis == null) return false;
      final lastActivity = DateTime.fromMillisecondsSinceEpoch(millis);
      return DateTime.now().difference(lastActivity) >= idleTimeout;
    } catch (e, st) {
      AppLogger.error('IdleLockGate.wasIdleTooLong', e, st);
      return false;
    }
  }

  @override
  State<IdleLockGate> createState() => _IdleLockGateState();
}

class _IdleLockGateState extends State<IdleLockGate> with WidgetsBindingObserver {
  final _pinRepository = PinRepository();
  StreamSubscription<User?>? _authSub;
  Timer? _idleTimer;

  DateTime _lastActivityAt = DateTime.now();
  DateTime? _lastPersistedAt;

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
      _idleTimer?.cancel();
      return;
    }
    try {
      _hasPinForCurrentUser = await _pinRepository.hasPin(user.uid);
    } catch (e, st) {
      AppLogger.error('IdleLockGate._onAuthChanged', e, st);
      _hasPinForCurrentUser = false;
    }
    // Starts the idle clock the moment we know there's actually a PIN
    // to protect -- initState can't start it directly since this
    // Firestore read hasn't resolved yet at that point.
    if (mounted) _restartIdleTimer();
  }

  /// Fires on every real tap anywhere in the app (see the root
  /// [Listener] in [build]) -- pushes the idle deadline back out.
  void _onUserActivity([PointerDownEvent? _]) {
    _lastActivityAt = DateTime.now();
    // Throttled disk write -- a tap can fire many times a minute
    // during normal use, and losing up to ~10s of accuracy against a
    // 5-minute threshold doesn't matter, so there's no reason to hit
    // SharedPreferences on every single one.
    if (_lastPersistedAt == null || _lastActivityAt.difference(_lastPersistedAt!) > const Duration(seconds: 10)) {
      _lastPersistedAt = _lastActivityAt;
      _persistLastActivity(_lastActivityAt);
    }
    if (!_locked) _restartIdleTimer();
  }

  Future<void> _persistLastActivity(DateTime at) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(IdleLockGate._prefsKey, at.millisecondsSinceEpoch);
    } catch (e, st) {
      // Same low-stakes reasoning as ThemeBloc's own save -- worth
      // logging, not worth interrupting anything over.
      AppLogger.error('IdleLockGate._persistLastActivity', e, st);
    }
  }

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    if (!_hasPinForCurrentUser) return;
    final remaining = IdleLockGate.idleTimeout - DateTime.now().difference(_lastActivityAt);
    _idleTimer = Timer(remaining.isNegative ? Duration.zero : remaining, _onIdleTimedOut);
  }

  void _onIdleTimedOut() {
    if (!mounted || !_hasPinForCurrentUser || _locked) return;
    _locked = true;
    _showInactivityAlert();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Dart timers don't fire while the app is actually backgrounded
      // -- there's nothing for _idleTimer to usefully do while paused,
      // so just stop it. _onResumed below re-derives everything from
      // the persisted timestamp regardless of how long the app was
      // away, including a span this process wasn't even alive for.
      _persistLastActivity(_lastActivityAt);
      _idleTimer?.cancel();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _onResumed();
    }
  }

  Future<void> _onResumed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Re-checked fresh rather than trusting only the last cached value
    // -- same reasoning the old PinLockGate had: setting a PIN mid-
    // session (via Profile) doesn't fire a new auth-state change.
    try {
      _hasPinForCurrentUser = await _pinRepository.hasPin(user.uid);
    } catch (e, st) {
      AppLogger.error('IdleLockGate._onResumed (hasPin)', e, st);
    }
    if (!mounted || !_hasPinForCurrentUser || _unlockScreenShowing) return;
    final idleFor = DateTime.now().difference(_lastActivityAt);
    if (idleFor >= IdleLockGate.idleTimeout) {
      _locked = true;
      _showInactivityAlert();
    } else {
      _restartIdleTimer();
    }
  }

  Future<void> _showInactivityAlert() async {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    await InactivityAlertDialog.show(navigator.context);
    _showUnlockScreen();
  }

  void _showUnlockScreen() {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    _unlockScreenShowing = true;
    navigator
        .push(MaterialPageRoute(
          builder: (_) => PinUnlockScreen(
            inactivityMessage: true,
            onUnlocked: () => rootNavigatorKey.currentState?.pop(),
          ),
        ))
        .then((_) {
      _unlockScreenShowing = false;
      _locked = false;
      _onUserActivity();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onUserActivity,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
