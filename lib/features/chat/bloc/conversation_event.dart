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
