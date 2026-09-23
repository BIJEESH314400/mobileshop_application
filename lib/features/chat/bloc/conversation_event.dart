import 'package:equatable/equatable.dart';

sealed class ConversationEvent extends Equatable {
  const ConversationEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the conversation screen opens — starts a live
/// subscription to this conversation's messages, and marks it read for
/// whoever just opened it.
class ConversationSubscriptionRequested extends ConversationEvent {
  const ConversationSubscriptionRequested();
}

class ConversationMessageSent extends ConversationEvent {
  final String text;

  const ConversationMessageSent(this.text);

  @override
  List<Object?> get props => [text];
}

/// Fired once alongside ConversationSubscriptionRequested — starts a
/// second, independent live subscription to this same conversation doc,
/// just to watch the *other* side's typing flag.
class ConversationTypingSubscriptionRequested extends ConversationEvent {
  const ConversationTypingSubscriptionRequested();
}

/// Fired by the View (debounced) whenever this side starts/stops typing.
/// Just a write-through to Firestore so the other side's subscription
/// above picks it up.
class ConversationTypingChanged extends ConversationEvent {
  final bool isTyping;

  const ConversationTypingChanged(this.isTyping);

  @override
  List<Object?> get props => [isTyping];
}
