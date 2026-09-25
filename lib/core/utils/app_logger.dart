import 'dart:developer' as developer;

/// Thin wrapper around dart:developer's log() so every catch block in
/// the app logs the SAME way, under one name ("4BMobiles") that's easy
/// to filter for in `flutter run`'s console or `adb logcat`.
///
/// Deliberately not a logging package -- dart:developer is built into
/// Flutter, needs no extra setup, and shows up directly in whatever
/// terminal is running `flutter run` (or in `adb logcat` for an
/// installed build) -- exactly what's needed to actually see what a
/// silent failure like "app won't open" or "stuck on a blank screen"
/// was, instead of guessing at it from a description alone.
class AppLogger {
  AppLogger._();

  static void error(String where, Object error, [StackTrace? stackTrace]) {
    developer.log(
      'ERROR in $where: $error',
      name: '4BMobiles',
      error: error,
      stackTrace: stackTrace,
      level: 1000, // SEVERE
    );
  }

  static void info(String where, String message) {
    developer.log(message, name: '4BMobiles', level: 800);
  }
}
