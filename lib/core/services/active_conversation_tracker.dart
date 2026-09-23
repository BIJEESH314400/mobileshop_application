/// Tracks which conversation (if any) is currently open on screen, so
/// ChatNotificationWatcher can skip showing a notification for a
/// message the person is already looking at live -- no point popping
/// a system notification over a chat they have open in front of them.
///
/// Deliberately a plain static, not a Bloc/stream -- this is a single
/// piece of "what screen is visible right now" state read by one
/// consumer, not something any UI builds off of.
class ActiveConversationTracker {
  ActiveConversationTracker._();

  static String? openConversationId;
}
