import 'package:flutter/material.dart';

/// A single GlobalKey shared by MaterialApp and anything that needs to
/// push a route from outside the widget tree that has a BuildContext
/// with a Navigator ancestor -- right now, just the chat notification
/// tap handler (see core/services/chat_notification_watcher.dart),
/// since that code runs from a callback with no screen context at all.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
