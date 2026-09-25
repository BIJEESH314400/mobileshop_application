import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/routes/app_routes.dart';
import 'core/routes/root_navigator_key.dart';
import 'core/services/chat_notification_watcher.dart';
import 'core/services/pin_lock_gate.dart';
import 'core/theme/app_theme.dart';
import 'features/theme/bloc/theme_bloc.dart';
import 'features/theme/bloc/theme_state.dart';

class MobileShopApp extends StatelessWidget {
  final ThemeMode initialThemeMode;
  const MobileShopApp({super.key, this.initialThemeMode = ThemeMode.light});

  @override
  Widget build(BuildContext context) {
    // ThemeBloc lives above MaterialApp so any screen can read/toggle
    // it later — today only the Profile screen's Dark Mode row does.
    // ChatNotificationWatcher and PinLockGate both sit above MaterialApp
    // so they keep running for the app's whole lifetime, independent of
    // whatever screen is currently on top -- see each one's own doc
    // comment for what it does. PinLockGate is outermost since it needs
    // to intercept every app resume regardless of what else is mounted.
    return PinLockGate(
      child: ChatNotificationWatcher(
        child: BlocProvider(
          create: (_) => ThemeBloc(initialMode: initialThemeMode),
          child: BlocBuilder<ThemeBloc, ThemeState>(
            builder: (context, themeState) {
              return MaterialApp(
                navigatorKey: rootNavigatorKey,
                title: '4B Mobiles',
                debugShowCheckedModeBanner: false,
                theme: buildAppTheme(),
                darkTheme: buildAppDarkTheme(),
                themeMode: themeState.mode,
                initialRoute: AppRoutes.splash,
                routes: AppRoutes.routes,
              );
            },
          ),
        ),
      ),
    );
  }
}
