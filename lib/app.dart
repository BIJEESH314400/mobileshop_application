import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/routes/app_routes.dart';
import 'core/routes/root_navigator_key.dart';
import 'core/services/chat_notification_watcher.dart';
import 'core/theme/app_theme.dart';
import 'features/theme/bloc/theme_bloc.dart';
import 'features/theme/bloc/theme_state.dart';

class MobileShopApp extends StatelessWidget {
  const MobileShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ThemeBloc lives above MaterialApp so any screen can read/toggle
    // it later — today only the Profile screen's Dark Mode row does.
    // ChatNotificationWatcher sits above MaterialApp so it keeps running
    // for the app's whole lifetime, independent of whatever screen is
    // currently on top -- see its own doc comment for what it does.
    return ChatNotificationWatcher(
      child: BlocProvider(
        create: (_) => ThemeBloc(),
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
    );
  }
}
