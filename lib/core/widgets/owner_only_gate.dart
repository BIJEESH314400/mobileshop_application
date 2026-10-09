import 'package:flutter/material.dart';

import '../repositories/current_user_repository.dart';
import '../routes/app_routes.dart';
import '../routes/root_navigator_key.dart';
import '../utils/app_logger.dart';

/// Wraps an owner-only screen so that even someone who reaches its
/// route directly (not just through a hidden Profile menu row) can't
/// actually use it unless they're really signed in as the owner.
///
/// Needed because Staff Management / Add Employee being hidden from an
/// employee's Profile menu was never real access control -- anyone who
/// knew (or guessed) the route name could still open it directly. Add
/// Employee specifically is the dangerous one: it creates a brand new
/// Firebase Auth account, and `CurrentUserRepository` treats "no
/// employees/<uid> document" as "this is the owner" -- so a real
/// employee reaching that screen could create themselves a second,
/// fully-privileged owner account. This gate is what actually closes
/// that door, not just the menu-hiding.
///
/// Deliberately fails CLOSED (blocks access) if the owner/employee
/// check itself fails -- e.g. a network hiccup -- the opposite of the
/// fail-OPEN pattern used everywhere else in this app (PIN checks, the
/// disabled-employee check, etc). Those fail open because the worst
/// case there is a minor inconvenience to an already-legitimate
/// signed-in session. Here, failing open would mean a failed read
/// grants owner-only access by default -- exactly the hole this widget
/// exists to close -- so it fails closed instead. A genuine owner
/// hitting a network hiccup just sees a brief redirect and can try
/// again; that's an acceptable trade-off for a security gate.
class OwnerOnlyGate extends StatefulWidget {
  final Widget child;
  const OwnerOnlyGate({super.key, required this.child});

  @override
  State<OwnerOnlyGate> createState() => _OwnerOnlyGateState();
}

class _OwnerOnlyGateState extends State<OwnerOnlyGate> {
  bool _checking = true;
  bool _allowed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    bool allowed;
    try {
      final user = await CurrentUserRepository().loadCurrentUser();
      allowed = user.isOwner;
    } catch (e, st) {
      AppLogger.error('OwnerOnlyGate._check', e, st);
      allowed = false; // Fail closed -- see class doc comment above.
    }

    if (!mounted) return;

    if (!allowed) {
      // Posted to the next frame, and routed/messaged via
      // rootNavigatorKey rather than this widget's own context --
      // same reasoning Splash/PinUnlockScreen already use elsewhere in
      // this app: by the time this fires, this screen may already be
      // on its way out, and a context tied to it isn't guaranteed to
      // still be valid for a Navigator/ScaffoldMessenger lookup.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        rootNavigatorKey.currentState?.pushNamedAndRemoveUntil(AppRoutes.dashboard, (route) => false);
        final rootContext = rootNavigatorKey.currentContext;
        if (rootContext != null) {
          ScaffoldMessenger.of(rootContext).showSnackBar(
            const SnackBar(content: Text('Owner access only.')),
          );
        }
      });
      return;
    }

    setState(() {
      _checking = false;
      _allowed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking || !_allowed) {
      // Shown only for the brief moment the check is in flight, or
      // between a blocked result and the scheduled redirect firing.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return widget.child;
  }
}
