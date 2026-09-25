import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/repositories/pin_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/app_logger.dart';
import 'pin_keypad.dart';

/// Lets the signed-in account set or replace its own 4-digit PIN. Two
/// steps in one screen (enter, then confirm), same idea as any "set a
/// new PIN/password" flow: typing the same 4 digits twice is the only
/// proof it wasn't a typo, since a PIN this short has no other
/// practical strength check worth doing.
///
/// Deliberately doesn't ask for the OLD PIN first when replacing one --
/// reaching this screen at all already requires being fully signed in
/// via the real Firebase Auth login, which is the actual security
/// boundary; the PIN is just a quick local re-entry gate on top of that
/// (see PinRepository's own doc comment).
///
/// Reached two different ways, distinguished by [onSetupComplete]:
/// - From Profile's "Quick PIN" row (`onSetupComplete: null`) -- an
///   optional, revisitable change, so this screen keeps its back arrow
///   and just pops `true` when a PIN is saved.
/// - Right after a fresh login/cold-start that found no PIN yet for
///   this account (`onSetupComplete` set -- see LoginScreen and
///   SplashScreen) -- Quick PIN is now a REQUIRED part of getting into
///   the account, not an optional extra, so this instance has no way
///   back (no back arrow, `PopScope(canPop: false)` same as
///   PinUnlockScreen) and calls [onSetupComplete] instead of popping
///   once the PIN is saved, so the caller can carry on to Dashboard.
class SetPinScreen extends StatefulWidget {
  final VoidCallback? onSetupComplete;
  const SetPinScreen({super.key, this.onSetupComplete});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  static const _pinLength = 4;

  String _firstEntry = '';
  String _entered = '';
  bool _confirming = false;
  bool _error = false;
  bool _saving = false;

  void _onDigit(String digit) {
    if (_saving || _entered.length >= _pinLength) return;
    setState(() {
      _entered += digit;
      _error = false;
    });
    if (_entered.length == _pinLength) _advance();
  }

  void _onBackspace() {
    if (_saving || _entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _advance() async {
    if (!_confirming) {
      setState(() {
        _firstEntry = _entered;
        _entered = '';
        _confirming = true;
      });
      return;
    }
    if (_entered != _firstEntry) {
      setState(() {
        _error = true;
        _entered = '';
        _confirming = false;
        _firstEntry = '';
      });
      return;
    }
    setState(() => _saving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // can't happen -- this screen requires being signed in to reach
    // Unlike the read-side PIN checks elsewhere (which fail open to "no
    // PIN" since a save that never actually happens is silent-safe by
    // definition), a failed WRITE here must be visible -- without this
    // try/catch, a Firestore error (most likely: the pins/{uid} rule
    // not published to the Firebase Console yet) left _saving stuck
    // true forever with a frozen keypad and no error, so it looked to
    // the person like the PIN saved fine when nothing was ever written.
    try {
      await PinRepository().setPin(user.uid, _entered);
    } catch (e, st) {
      AppLogger.error('SetPinScreen._advance (setPin)', e, st);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = true;
        _entered = '';
        _confirming = false;
        _firstEntry = '';
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text("Couldn't save your PIN — check your connection and try again"),
        ));
      return;
    }
    if (!mounted) return;
    // Mandatory first-time setup (login/cold-start path) has nowhere
    // to "pop" back TO -- this screen replaced the previous one, same
    // as PinUnlockScreen's onUnlocked -- so it hands control back via
    // the callback instead of Navigator.pop.
    if (widget.onSetupComplete != null) {
      widget.onSetupComplete!();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Quick PIN saved')));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final subtitle = _confirming ? 'Confirm your new PIN' : 'Enter a new 4-digit PIN';

    final mandatory = widget.onSetupComplete != null;

    return PopScope(
      // Mandatory setup can't be backed out of -- same reasoning as
      // PinUnlockScreen: there's no real "screen behind this" to go
      // back to yet, since it hasn't finished proving the account has
      // a usable PIN. The optional Profile path keeps normal back
      // behavior (canPop: true).
      canPop: !mandatory,
      child: Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              decoration: BoxDecoration(color: palette.background, border: Border(bottom: BorderSide(color: palette.border))),
              child: Row(
                children: [
                  if (!mandatory)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.pop(context),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_back_rounded, size: 20, color: palette.textPrimary),
                          const SizedBox(width: 14),
                          Text('Quick PIN', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                        ],
                      ),
                    )
                  else
                    Text('Set Up Your Quick PIN', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                ],
              ),
            ),
            // Same LayoutBuilder + SingleChildScrollView +
            // ConstrainedBox(minHeight) fix as PinUnlockScreen
            // (2026-09-24). First attempt wrapped the Column in
            // IntrinsicHeight, but PinKeypad is a GridView internally
            // and GridView's viewport can't answer an intrinsic-height
            // query -- that crashed with "RenderShrinkWrappingViewport
            // does not support returning intrinsic dimensions" plus a
            // cascade of "RenderBox was not laid out" errors once a
            // person actually reached a screen using it. Fixed the same
            // way here: fixed SizedBox gaps instead of Spacer, no
            // IntrinsicHeight, mainAxisAlignment.center on the Column.
            Expanded(
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
                          Text(subtitle, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                          const SizedBox(height: 6),
                          Text(
                            'Used to quickly get back into the app once you\'re already logged in.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5, color: palette.textSecondary, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 26),
                          PinDots(length: _pinLength, filled: _entered.length, error: _error),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 18,
                            child: _error
                                ? const Text("PINs didn't match — try again", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.danger))
                                : null,
                          ),
                          const SizedBox(height: 30),
                          PinKeypad(onDigit: _onDigit, onBackspace: _onBackspace, enabled: !_saving),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
