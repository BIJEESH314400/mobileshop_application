import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'features/theme/bloc/theme_bloc.dart';

void main() {
  // Everything (Firebase init, runApp, the whole app) runs inside
  // runZonedGuarded so that literally nothing can fail silently --
  // before this, a crash or hang during startup (before any screen
  // has drawn anything) left no trace anywhere, which is exactly what
  // made "app won't open, stuck on the launch icon" impossible to
  // diagnose from a description alone. Every error now gets logged
  // with dart:developer's log(), visible in `flutter run`'s console
  // or `adb logcat` on an installed build.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Framework-level errors (thrown inside a widget's build method,
    // layout/paint errors, etc.) go through here instead of just
    // printing to the console and otherwise vanishing.
    FlutterError.onError = (FlutterErrorDetails details) {
      developer.log(
        'FlutterError: ${details.exceptionAsString()}',
        name: '4BMobiles',
        error: details.exception,
        stackTrace: details.stack,
        level: 1000, // SEVERE
      );
      FlutterError.presentError(details);
    };

    // Firebase needs the Flutter binding ready before it can talk to
    // platform channels, and initializeApp() must finish before any
    // screen tries to use Auth/Firestore — so both happen here, before
    // runApp(), rather than inside a widget.
    await Firebase.initializeApp();

    // Read the saved light/dark preference before the first frame,
    // same reasoning as Firebase above -- doing it here instead of
    // inside ThemeBloc's own async startup avoids a flash of light
    // mode on every launch while a dark-mode preference loads.
    final initialThemeMode = await ThemeBloc.loadSavedMode();

    runApp(MobileShopApp(initialThemeMode: initialThemeMode));
  }, (error, stackTrace) {
    // Catches everything else -- anything thrown outside the Flutter
    // framework's own error handling (an uncaught Future error, or
    // anything thrown in the async block above, including a failed
    // Firebase.initializeApp()).
    developer.log(
      'Uncaught error: $error',
      name: '4BMobiles',
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  });
}
