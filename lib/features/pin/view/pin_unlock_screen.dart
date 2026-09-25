import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/repositories/current_user_repository.dart';
import '../../../core/repositories/pin_repository.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/routes/root_navigator_key.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/app_logger.dart';
import 'pin_keypad.dart';

/// A lock screen for an already-signed-in Firebase session -- shown
/// either right after Splash (cold start, account has a PIN set) or by
/// PinLockGate (the app was resumed from the background). Either way,
/// this screen never itself decides success/failure of the Firebase
/// login -- it only checks a PIN against PinRepository and calls
/// [onUnlocked], leaving what happens next (replace with Dashboard, or
/// just pop back to reveal whatever was on screen before) to the
/// caller, since that differs between the two entry points.
///
/// `canPop: false` below deliberately blocks the Android back
/// gesture/button from dismissing this screen -- same as a real phone
/// lock screen, back should do nothing here, not skip the PIN.
class PinUnlockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const PinUnlockScreen({super.key, required this.onUnlocked});

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  static const _pinLength = 4;
  static const _maxAttemptsBeforeFallback = 5;

  final _pinRepository = PinRepository();
  final _currentUserRepository = CurrentUserRepository();

  String _entered = '';
  String? _displayName;
  bool _checking = false;
  bool _error = false;
  int _failCount = 0;

  @override
  void initState() {
    super.initState();
    _currentUserRepository.loadCurrentUser().then((user) {
      if (mounted) setState(() => _displayName = user.displayName);
    }).catchError((_) {
      // Somehow not really signed in after all (session dropped between
      // Splash's check and this screen building) -- don't get stuck on
      // a PIN screen with nothing to verify against.
      _forceFullLogin();
    });
  }

  void _onDigit(String digit) {
    if (_checking || _entered.length >= _pinLength) return;
    setState(() {
      _entered += digit;
      _error = false;
    });
    if (_entered.length == _pinLength) _verify();
  }

  void _onBackspace() {
    if (_checking || _entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _verify() async {
    setState(() => _checking = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _forceFullLogin();
      return;
    }
    // Same reasoning as SplashBloc/PinLockGate: a Firestore hiccup
    // here must not leave _checking stuck true forever -- that would
    // freeze the keypad with no error and no way to retry, on the one
    // screen standing between a signed-in user and Dashboard. Treated
    // like a wrong PIN (counts toward the 5-strike fallback) rather
    // than silently retrying forever.
    bool ok;
    try {
      ok = await _pinRepository.verifyPin(user.uid, _entered);
    } catch (e, st) {
      AppLogger.error('PinUnlockScreen._verify', e, st);
      ok = false;
    }
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() {
        _failCount++;
        _entered = '';
        _error = true;
        _checking = false;
      });
    }
  }

  Future<void> _forceFullLogin() async {
    // The safety-valve fallback -- too many wrong PINs (or a session
    // that turned out not to be valid) signs all the way out and drops
    // back to the real username+password login, rather than ever
    // locking someone out of their own shop's app with no way back in.
    //
    // Bug fix (2026-09-25): this used to just sign out and stop there
    // -- but tapping "Forgot PIN?" is someone explicitly saying they
    // don't remember the old PIN, and their saved PIN was never
    // cleared, so logging back in just showed the SAME old PIN's
    // unlock screen again (needsPin, not needsSetPin -- see LoginBloc)
    // with no way to actually pick a new one short of a trip to
    // Profile. Same clearPin call ProfileScreen._logOut uses, and the
    // uid has to be read BEFORE signOut() -- currentUser is null the
    // instant it completes.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await _pinRepository.clearPin(uid);
      } catch (e, st) {
        AppLogger.error('PinUnlockScreen._forceFullLogin (clearPin)', e, st);
      }
    }
    await FirebaseAuth.instance.signOut();
    rootNavigatorKey.currentState?.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final greeting = _displayName == null ? 'Welcome back' : 'Welcome back, $_displayName';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: palette.background,
        // LayoutBuilder + SingleChildScrollView + ConstrainedBox(minHeight)
        // -- same pattern LoginScreen uses for "center when it fits,
        // scroll instead of overflowing when it doesn't". The first
        // attempt at this fix wrapped the Column in IntrinsicHeight (to
        // let Spacer/Expanded work inside the scroll view's unbounded
        // height), but PinKeypad is a GridView internally, and
        // GridView's viewport explicitly can't answer the
        // intrinsic-dimension query IntrinsicHeight needs -- that threw
        // "RenderShrinkWrappingViewport does not support returning
        // intrinsic dimensions" followed by a cascade of "RenderBox was
        // not laid out" errors. Fix: no Spacer/Expanded (those are what
        // actually need IntrinsicHeight), just fixed gaps plus
        // mainAxisAlignment.center on the Column -- ConstrainedBox's
        // minHeight alone is enough to center short content and let tall
        // content scroll, with nothing in the tree that needs an
        // intrinsic-size query.
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: const Icon(Icons.lock_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 20),
                      Text(greeting, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: palette.textPrimary)),
                      const SizedBox(height: 6),
                      Text(
                        'Enter your PIN to continue',
                        style: TextStyle(fontSize: 13, color: palette.textSecondary, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 30),
                      PinDots(length: _pinLength, filled: _entered.length, error: _error),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 18,
                        // Shows tries REMAINING, not tries used -- so
                        // someone who mistypes sees a countdown toward
                        // the 5-try "Forgot PIN?" fallback below,
                        // instead of it suddenly showing up unexplained.
                        child: _error
                            ? Text(
                                'Wrong PIN. ${_maxAttemptsBeforeFallback - _failCount} ${_maxAttemptsBeforeFallback - _failCount == 1 ? 'try' : 'tries'} left',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.danger),
                              )
                            : null,
                      ),
                      const SizedBox(height: 30),
                      PinKeypad(onDigit: _onDigit, onBackspace: _onBackspace, enabled: !_checking),
                      const SizedBox(height: 16),
                      if (_failCount >= _maxAttemptsBeforeFallback)
                        TextButton(
                          onPressed: _forceFullLogin,
                          child: const Text(
                            'Forgot PIN? Log in with password instead',
                            style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12.5),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
