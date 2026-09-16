import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
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
          if (status == AuthStatus.unauthenticated) {
            Navigator.of(context).pushReplacementNamed(AppRoutes.login);
          } else if (status == AuthStatus.authenticated) {
            Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.accent,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.smartphone_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 22),
                const Text(
                  '4B Mobiles',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Run your mobile shop, smarter.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
