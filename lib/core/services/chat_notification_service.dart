import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around flutter_local_notifications -- shows a system
/// notification for an incoming chat message and, on tap, hands the
/// tapped conversationId back via [init]'s onTap callback.
///
/// This is the "free" notification path (discussed with the user and
/// deliberately chosen over the paid route, 2026-09-23): it only fires
/// while this Flutter app process is alive (foreground or
/// backgrounded, not fully closed/swiped away) -- there's no server
/// pushing anything here, it's purely the app's own live Firestore
/// listener (ChatNotificationWatcher) deciding to show one. Real
/// background/closed-app push needs Firebase Cloud Messaging plus a
/// Cloud Function, which needs the paid Blaze plan -- see the app
/// status doc's Push Notifications section for the full discussion.
class ChatNotificationService {
  ChatNotificationService._();
  static final ChatNotificationService instance = ChatNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  void Function(String conversationId)? _onTap;
  bool _initialized = false;

  Future<void> init({required void Function(String conversationId) onTap}) async {
    // Keep the latest callback even on a repeat call (e.g. a widget
    // rebuild) -- only the underlying plugin setup should run once.
    _onTap = onTap;
    if (_initialized) return;
    _initialized = true;

    // @mipmap/ic_launcher (the app's own launcher icon) as the small
    // icon -- not the Material "monochrome icon" ideal, but it's what
    // flutter_local_notifications' own docs use by default, needs no
    // extra icon asset, and works fine for a small internal tool.
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final conversationId = response.payload;
        if (conversationId != null && conversationId.isNotEmpty) {
          _onTap?.call(conversationId);
        }
      },
    );

    // Android 13+ requires this to be asked explicitly at runtime --
    // on older Android versions the plugin grants it automatically and
    // this call is a harmless no-op.
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> show({required String title, required String body, required String conversationId}) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat messages',
      channelDescription: 'New owner/employee chat messages',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    // One stable id per conversation, so a second message from the
    // same person updates/replaces that one notification instead of
    // stacking a new banner every time -- same idea as most chat apps.
    final id = conversationId.hashCode & 0x7fffffff;
    await _plugin.show(id, title, body, details, payload: conversationId);
  }
}
