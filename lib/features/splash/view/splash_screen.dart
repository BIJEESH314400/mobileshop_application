import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/routes/root_navigator_key.dart';
import '../../../core/services/idle_lock_gate.dart';
import '../../pin/view/pin_unlock_screen.dart';
import '../../pin/view/set_pin_screen.dart';
import '../bloc/splash_bloc.dart';
import '../bloc/splash_event.dart';
import '../bloc/splash_state.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // With Cubit this was `SplashCubit()`, which ran its check in the
      // constructor. A Bloc does nothing until it receives an Event, so
      // it's explicitly kicked off here with `..add(const SplashStarted())`.
      create: (_) => SplashBloc()..add(const SplashStarted()),
      child: BlocListener<SplashBloc, AuthStatus>(
        listener: (context, status) {
          // Uses rootNavigatorKey rather than this screen's own
          // `context` for every outcome here -- once a replacement
          // route is pushed, Splash's own context can be disposed
          // before PinUnlockScreen's `onUnlocked` callback below ever
          // runs, and calling Navigator.of() on a disposed context
          // throws. rootNavigatorKey.currentState stays valid for the
          // whole app's lifetime regardless of which screen is on top.
          final navigator = rootNavigatorKey.currentState;
          if (navigator == null) return;
          if (status == AuthStatus.unauthenticated) {
            navigator.pushReplacementNamed(AppRoutes.login);
          } else if (status == AuthStatus.authenticated) {
            navigator.pushReplacementNamed(AppRoutes.dashboard);
          } else if (status == AuthStatus.authenticatedNeedsPin) {
            // A true cold start always asks for the PIN regardless of
            // idle time -- but if the saved activity timestamp shows
            // the 5-minute idle budget was ALSO blown while this
            // process wasn't even alive (backgrounded, then killed by
            // the OS), show the same "logged out due to inactivity"
            // wording IdleLockGate's own live alert uses, rather than
            // a plain "welcome back" that never explained why they're
            // here. See IdleLockGate.wasIdleTooLong.
            IdleLockGate.wasIdleTooLong().then((wasIdle) {
              rootNavigatorKey.currentState?.pushReplacement(MaterialPageRoute(
                builder: (_) => PinUnlockScreen(
                  inactivityMessage: wasIdle,
                  onUnlocked: () => rootNavigatorKey.currentState?.pushReplacementNamed(AppRoutes.dashboard),
                ),
              ));
            });
          } else if (status == AuthStatus.authenticatedNeedsSetPin) {
            // Signed in, but no PIN saved -- only reachable in the
            // normal flow if the app was killed mid-setup (see
            // AuthStatus.authenticatedNeedsSetPin's doc comment).
            // Same mandatory SetPinScreen as LoginScreen uses.
            navigator.pushReplacement(MaterialPageRoute(
              builder: (_) => SetPinScreen(
                onSetupComplete: () => rootNavigatorKey.currentState?.pushReplacementNamed(AppRoutes.dashboard),
              ),
            ));
          }
        },
        child: const _SplashBody(),
      ),
    );
  }
}

// Fixed brand palette for the splash mark itself -- deliberately NOT
// AppColors.accent. The in-app 6-theme picker (Profile > App Theme)
// changes buttons/highlights throughout the app, but this splash is a
// dark "secure vault" brand identity matched from a reference image
// (2026-10-27) -- it stays this exact dark-navy + amber combo
// regardless of which accent theme is selected.
const Color _bgTop = Color(0xFF0C1020);
const Color _bgBottom = Color(0xFF05060B);
const Color _brandAmber = Color(0xFFF0A23D);

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.035)
      ..strokeWidth = 1;
    const spacing = 28.0;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}

/// The plain "4B" mark on its own -- dark fill, fully-drawn amber
/// border, fully-opaque text + icon. No outer ring, no glow, nothing
/// animated. This is deliberately pixel-similar to the app's launcher
/// icon (`android/app/src/main/res/mipmap-*/ic_launcher.png`), which is
/// what the native Android launch screen shows (see
/// `android/app/src/main/res/drawable/launch_background.xml`) for the
/// brief moment before Flutter has even loaded.
///
/// Added 2026-10-28: the owner's client specifically liked that native
/// screen and asked for "a little more time" on it. Flutter can't make
/// the native screen itself last longer (see the "hold" comment on
/// `_SplashBodyState` below), so instead this exact first Flutter frame
/// reproduces it closely and holds it, unanimated, before the fuller
/// reveal (ring, glow, title, etc.) builds in around it -- from the
/// user's perspective it reads as the same screen simply staying up
/// longer, with no hand-off flash in between.
class _StaticMark extends StatelessWidget {
  const _StaticMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF11151F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _brandAmber.withOpacity(0.75), width: 1.3),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '4B',
            style: TextStyle(
              color: _brandAmber,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 3),
          Icon(Icons.smartphone_rounded, color: _brandAmber.withOpacity(0.85), size: 12),
        ],
      ),
    );
  }
}

/// The splash screen's visuals, split out from [SplashScreen] so the
/// animation controllers below have a State to live in -- the bloc
/// wiring above (BlocProvider/BlocListener) is untouched.
///
/// Reworked 2026-10-28 around a "hold" phase (owner's client liked the
/// plain native launch screen and asked for more time on it, see
/// `_StaticMark`'s doc comment above):
///
/// 1. **Hold** (`_holdMs`, ~1.4s) -- the very first Flutter frame shows
///    ONLY the dark background + the plain, fully-formed "4B" mark, no
///    grid, no ring, no glow, nothing moving. Visually continuous with
///    the native screen that was showing right before it, so the
///    hand-off from native to Flutter is invisible and it just reads
///    as "the same screen, staying up a bit longer".
/// 2. **Reveal** (`_introController`, ~2.6s, starts right after the
///    hold ends) -- the grid fades in, a ring + ambient glow appear
///    around the (already fully-visible, untouched) mark, a single
///    light sweep crosses it once, then the title/subtitle/divider/dots
///    build in. The mark itself is never redrawn or faded out at any
///    point -- only things AROUND it animate, so nothing it already
///    showed during the hold ever disappears or "undraws".
///
/// `SplashBloc`'s own minimum-display timer (`splash_bloc.dart`) was
/// extended to match hold + reveal, so the real auth/PIN check -- which
/// usually finishes well before either of those elapse -- never cuts
/// either phase short.
///
/// `_loopController` (1.6s, repeats forever) drives the ambient glow
/// breathing and the three loading dots, both only visible once the
/// reveal phase starts, and both keep going for as long as the screen
/// is up after that.
class _SplashBody extends StatefulWidget {
  const _SplashBody();

  @override
  State<_SplashBody> createState() => _SplashBodyState();
}

class _SplashBodyState extends State<_SplashBody> with TickerProviderStateMixin {
  static const _holdMs = 1400;

  late final AnimationController _introController;
  late final AnimationController _loopController;

  late final Animation<double> _outerOpacity;
  late final Animation<double> _outerScale;
  late final Animation<double> _shine;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleLetterSpacing;
  late final Animation<double> _subtitleOpacity;
  late final Animation<double> _dividerWidth;
  late final Animation<double> _dotsOpacity;

  bool _holding = true;

  @override
  void initState() {
    super.initState();

    // Neither controller runs yet -- both start together once the
    // hold delay below elapses.
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _outerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: const Interval(0.0, 0.25, curve: Curves.easeOut)),
    );
    _outerScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: const Interval(0.0, 0.28, curve: Curves.easeOutCubic)),
    );
    _shine = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: const Interval(0.15, 0.45, curve: Curves.easeInOutCubic)),
    );
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: const Interval(0.35, 0.58, curve: Curves.easeOut)),
    );
    _titleLetterSpacing = Tween<double>(begin: 14.0, end: 5.0).animate(
      CurvedAnimation(parent: _introController, curve: const Interval(0.35, 0.6, curve: Curves.easeOutCubic)),
    );
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: const Interval(0.55, 0.78, curve: Curves.easeOut)),
    );
    _dividerWidth = Tween<double>(begin: 0.0, end: 64.0).animate(
      CurvedAnimation(parent: _introController, curve: const Interval(0.78, 0.95, curve: Curves.easeOut)),
    );
    _dotsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: const Interval(0.88, 1.0, curve: Curves.easeOut)),
    );

    Future.delayed(const Duration(milliseconds: _holdMs), () {
      if (!mounted) return;
      setState(() => _holding = false);
      _introController.forward();
      _loopController.repeat();
    });
  }

  @override
  void dispose() {
    _introController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBottom,
      body: Stack(
        children: [
          // Dark gradient base -- present throughout, hold phase
          // included, so there is nothing to flash in when the hold
          // ends.
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_bgTop, _bgBottom],
                ),
              ),
            ),
          ),
          if (!_holding)
            // Faint tech grid overlay, fades in together with the ring
            // below rather than popping in the instant the hold ends.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _outerOpacity,
                builder: (context, _) => Opacity(
                  opacity: _outerOpacity.value,
                  child: CustomPaint(painter: const _GridPainter()),
                ),
              ),
            ),
          Center(
            child: _holding
                ? const _StaticMark()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: Listenable.merge([_introController, _loopController]),
                        builder: (context, _) {
                          // A gentle breathing ambient glow behind the
                          // mark -- both its size and opacity ride the
                          // same sine wave so it never snaps, just
                          // grows/shrinks smoothly in an endless loop
                          // while the screen is up.
                          final pulse = (math.sin(_loopController.value * 2 * math.pi) + 1) / 2; // 0..1
                          final glowScale = 1.0 + pulse * 0.25;
                          final glowOpacity = 0.06 + pulse * 0.08;

                          // One-time diagonal light sweep across the
                          // already fully-formed mark -- travels from
                          // just off its left edge to just off its
                          // right edge, then is done for good (not
                          // looped -- a repeating shine reads as a
                          // loading gimmick, a single pass reads as a
                          // highlight catching the light).
                          final shineT = _shine.value;
                          final shineDx = -70.0 + shineT * 140.0;

                          return SizedBox(
                            width: 150,
                            height: 150,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Ambient glow + outer ring fade/scale
                                // in together, around the mark.
                                Opacity(
                                  opacity: _outerOpacity.value,
                                  child: Transform.scale(
                                    scale: _outerScale.value,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Transform.scale(
                                          scale: glowScale,
                                          child: Container(
                                            width: 150,
                                            height: 150,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white.withOpacity(glowOpacity),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 112,
                                          height: 112,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0E1320),
                                            borderRadius: BorderRadius.circular(28),
                                            border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.6),
                                            boxShadow: [
                                              BoxShadow(color: Colors.white.withOpacity(0.14), blurRadius: 30, spreadRadius: 1),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // The mark itself -- same widget, same
                                // state, as the hold phase. Never faded
                                // out or redrawn, only the shine passes
                                // over it once.
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: SizedBox(
                                    width: 72,
                                    height: 72,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        const _StaticMark(),
                                        if (shineT > 0.0 && shineT < 1.0)
                                          Transform.translate(
                                            offset: Offset(shineDx, 0),
                                            child: Transform.rotate(
                                              angle: -0.45,
                                              child: Container(
                                                width: 22,
                                                height: 140,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.centerRight,
                                                    colors: [
                                                      Colors.white.withOpacity(0.0),
                                                      Colors.white.withOpacity(0.32),
                                                      Colors.white.withOpacity(0.0),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 26),
                      AnimatedBuilder(
                        animation: _introController,
                        builder: (context, _) {
                          return Opacity(
                            opacity: _titleOpacity.value,
                            child: Text(
                              '4B MOBILES',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: _titleLetterSpacing.value,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      FadeTransition(
                        opacity: _subtitleOpacity,
                        child: Text(
                          'RUN YOUR MOBILE SHOP, SMARTER',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AnimatedBuilder(
                        animation: _dividerWidth,
                        builder: (context, _) {
                          return Container(
                            width: _dividerWidth.value,
                            height: 1.4,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.0),
                                  Colors.white.withOpacity(0.8),
                                  Colors.white.withOpacity(0.0),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                      FadeTransition(
                        opacity: _dotsOpacity,
                        child: _LoadingDots(controller: _loopController),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Three small dots that pulse in a staggered wave instead of a plain
/// spinner -- reads off the same looping controller as the mark's
/// glow, so everything on screen stays in sync and keeps moving for
/// however long the screen is up.
class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (controller.value * 2 * math.pi) - (i * (math.pi / 2));
            final scale = 0.55 + 0.45 * ((math.sin(phase) + 1) / 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _brandAmber.withOpacity(0.85),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
